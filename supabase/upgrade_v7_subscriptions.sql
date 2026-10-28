-- Run after schema.sql and existing upgrades. No existing shop data is changed.
begin;
create table if not exists public.billing_reviewers (
  user_id uuid primary key references auth.users(id) on delete cascade
);
alter table public.billing_reviewers enable row level security;
create or replace function public.is_billing_reviewer() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists(select 1 from public.billing_reviewers where user_id = auth.uid());
$$;
revoke all on function public.is_billing_reviewer() from public, anon;
grant execute on function public.is_billing_reviewer() to authenticated;

create table if not exists public.subscription_plans (
  id uuid primary key default gen_random_uuid(),
  name text not null check(length(trim(name)) between 1 and 80),
  description text not null default '',
  price integer not null check(price > 0),
  duration_days integer not null check(duration_days between 1 and 1095),
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.subscription_payment_methods (
  id uuid primary key default gen_random_uuid(),
  name text not null check(length(trim(name)) between 1 and 80),
  account_name text not null check(length(trim(account_name)) between 1 and 120),
  account_number text not null check(length(trim(account_number)) between 1 and 120),
  instructions text not null default '',
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table if not exists public.shop_subscriptions (
  shop_id uuid primary key references public.shops(id) on delete cascade,
  plan_name text not null,
  expires_at timestamptz not null,
  updated_at timestamptz not null default now()
);
create table if not exists public.subscription_payments (
  id uuid primary key,
  shop_id uuid not null references public.shops(id),
  submitted_by uuid not null references auth.users(id),
  plan_id uuid not null references public.subscription_plans(id),
  method_id uuid not null references public.subscription_payment_methods(id),
  plan_name text not null,
  amount integer not null check(amount > 0),
  duration_days integer not null,
  method_name text not null,
  account_name text not null,
  account_number text not null,
  transaction_reference text not null check(length(transaction_reference) between 4 and 100),
  paid_at timestamptz not null,
  slip_path text not null unique,
  status text not null default 'pending' check(status in ('pending','approved','rejected')),
  review_note text,
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  check ((status = 'pending' and reviewed_by is null and reviewed_at is null)
    or (status <> 'pending' and reviewed_by is not null and reviewed_at is not null))
);
create unique index if not exists subscription_one_pending_per_shop
  on public.subscription_payments(shop_id) where status = 'pending';
create unique index if not exists subscription_unique_transfer
  on public.subscription_payments(method_id, lower(transaction_reference)) where status <> 'rejected';
create index if not exists subscription_payments_history on public.subscription_payments(shop_id,created_at desc);
create index if not exists subscription_review_queue on public.subscription_payments(created_at) where status='pending';

alter table public.subscription_plans enable row level security;
alter table public.subscription_payment_methods enable row level security;
alter table public.shop_subscriptions enable row level security;
alter table public.subscription_payments enable row level security;
-- Re-runnable policy creation without dropping existing objects.
do $$ begin
  if not exists(select 1 from pg_policies where schemaname='public' and policyname='subscription_plan_read') then
    create policy subscription_plan_read on public.subscription_plans for select to authenticated using(active or public.is_billing_reviewer());
    create policy subscription_plan_admin on public.subscription_plans for all to authenticated using(public.is_billing_reviewer()) with check(public.is_billing_reviewer());
    create policy subscription_method_read on public.subscription_payment_methods for select to authenticated using(active or public.is_billing_reviewer());
    create policy subscription_method_admin on public.subscription_payment_methods for all to authenticated using(public.is_billing_reviewer()) with check(public.is_billing_reviewer());
    create policy subscription_read on public.shop_subscriptions for select to authenticated using(public.is_shop_member(shop_id) or public.is_billing_reviewer());
    create policy subscription_payment_read on public.subscription_payments for select to authenticated using(public.is_shop_member(shop_id) or public.is_billing_reviewer());
  end if;
end $$;
revoke all on public.billing_reviewers, public.subscription_plans, public.subscription_payment_methods, public.shop_subscriptions, public.subscription_payments from anon, authenticated;
grant select, insert, update on public.subscription_plans, public.subscription_payment_methods to authenticated;
grant select on public.shop_subscriptions, public.subscription_payments to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('subscription-slips','subscription-slips',false,5242880,array['image/jpeg','image/png'])
on conflict(id) do update set public=false,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png'];
do $$ begin
  if not exists(select 1 from pg_policies where schemaname='storage' and policyname='subscription_slip_insert') then
    create policy subscription_slip_insert on storage.objects for insert to authenticated with check(
      bucket_id='subscription-slips' and (storage.foldername(name))[1]=auth.uid()::text
      and lower(storage.extension(name)) in ('jpg','png')
      and exists(select 1 from public.shops where owner_id=auth.uid())
    );
    create policy subscription_slip_read on storage.objects for select to authenticated using(
      bucket_id='subscription-slips' and ((storage.foldername(name))[1]=auth.uid()::text or public.is_billing_reviewer())
    );
  end if;
end $$;

create or replace function public.submit_subscription_payment(
  p_id uuid, p_shop_id uuid, p_plan_id uuid, p_method_id uuid,
  p_reference text, p_paid_at timestamptz, p_slip_path text,
  p_expected_price integer, p_expected_days integer, p_expected_account text
) returns uuid language plpgsql security definer set search_path='' as $$
declare
  v_plan public.subscription_plans%rowtype;
  v_method public.subscription_payment_methods%rowtype;
  v_existing public.subscription_payments%rowtype;
begin
  if auth.uid() is null then raise exception 'Please sign in'; end if;
  -- Serializes submissions and reviews for the same shop.
  perform 1 from public.shops where id=p_shop_id and owner_id=auth.uid() for update;
  if not found then raise exception 'Only the shop owner can subscribe'; end if;
  select * into v_existing from public.subscription_payments where id=p_id;
  if found then
    if v_existing.submitted_by=auth.uid() and v_existing.shop_id=p_shop_id then return p_id; end if;
    raise exception 'Invalid request ID';
  end if;
  select * into v_plan from public.subscription_plans where id=p_plan_id and active for share;
  if not found then raise exception 'Plan is unavailable. Refresh and try again'; end if;
  select * into v_method from public.subscription_payment_methods where id=p_method_id and active for share;
  if not found then raise exception 'Payment method is unavailable'; end if;
  if p_expected_price is distinct from v_plan.price or p_expected_days is distinct from v_plan.duration_days or p_expected_account is distinct from v_method.account_number then raise exception 'Payment details changed. Contact support before sending another payment'; end if;
  if p_reference is null or length(trim(p_reference)) not between 4 and 100 then raise exception 'Enter a valid transfer reference'; end if;
  if p_paid_at is null or p_paid_at>now()+interval '10 minutes' or p_paid_at<now()-interval '90 days' then raise exception 'Enter a payment date within the last 90 days'; end if;
  if p_slip_path is null or p_slip_path not in (auth.uid()::text||'/'||p_id::text||'.jpg',auth.uid()::text||'/'||p_id::text||'.png') then raise exception 'Invalid slip path'; end if;
  perform 1 from storage.objects where bucket_id='subscription-slips' and name=p_slip_path;
  if not found then raise exception 'Upload a payment slip first'; end if;
  if exists(select 1 from public.subscription_payments where shop_id=p_shop_id and status='pending') then raise exception 'A payment is already awaiting review'; end if;
  insert into public.subscription_payments(id,shop_id,submitted_by,plan_id,method_id,plan_name,amount,duration_days,method_name,account_name,account_number,transaction_reference,paid_at,slip_path)
  values(p_id,p_shop_id,auth.uid(),v_plan.id,v_method.id,v_plan.name,v_plan.price,v_plan.duration_days,v_method.name,v_method.account_name,v_method.account_number,trim(p_reference),p_paid_at,p_slip_path);
  return p_id;
end $$;

create or replace function public.review_subscription_payment(p_id uuid,p_approve boolean,p_note text default '')
returns void language plpgsql security definer set search_path='' as $$
declare v_payment public.subscription_payments%rowtype; v_shop_id uuid;
begin
  if not public.is_billing_reviewer() then raise exception 'Reviewer access required'; end if;
  if p_approve is null then raise exception 'Choose a review decision'; end if;
  select shop_id into v_shop_id from public.subscription_payments where id=p_id;
  if not found then raise exception 'Payment not found'; end if;
  perform 1 from public.shops where id=v_shop_id for update;
  select * into v_payment from public.subscription_payments where id=p_id for update;
  if v_payment.status<>'pending' then raise exception 'This payment was already reviewed'; end if;
  if not p_approve and length(trim(coalesce(p_note,'')))=0 then raise exception 'Enter a rejection reason'; end if;
  if length(coalesce(p_note,''))>500 then raise exception 'Review note is too long'; end if;
  if p_approve then
    insert into public.shop_subscriptions(shop_id,plan_name,expires_at)
    values(v_payment.shop_id,v_payment.plan_name,now()+make_interval(days=>v_payment.duration_days))
    on conflict(shop_id) do update set plan_name=excluded.plan_name,
      expires_at=greatest(public.shop_subscriptions.expires_at,now())+make_interval(days=>v_payment.duration_days),updated_at=now();
  end if;
  update public.subscription_payments set status=case when p_approve then 'approved' else 'rejected' end,
    review_note=nullif(trim(p_note),''),reviewed_by=auth.uid(),reviewed_at=now() where id=p_id;
end $$;
revoke all on function public.submit_subscription_payment(uuid,uuid,uuid,uuid,text,timestamptz,text,integer,integer,text) from public, anon;
revoke all on function public.review_subscription_payment(uuid,boolean,text) from public, anon;
grant execute on function public.submit_subscription_payment(uuid,uuid,uuid,uuid,text,timestamptz,text,integer,integer,text) to authenticated;
grant execute on function public.review_subscription_payment(uuid,boolean,text) to authenticated;
commit;
