-- Sai Mate v5: operating expenses for net-profit reporting.
-- Run once after upgrade_v4.sql in the Supabase SQL Editor.

create table if not exists public.expenses(
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  title text not null,
  category text not null default 'General',
  note text,
  amount numeric(14,2) not null check(amount > 0),
  created_by uuid references public.profiles(id),
  created_at timestamptz not null default now()
);

alter table public.expenses enable row level security;

do $$
begin
  if not exists (
    select 1
    from pg_policies
    where schemaname = 'public'
      and tablename = 'expenses'
      and policyname = 'expenses_members'
  ) then
    create policy expenses_members on public.expenses for all
      using(public.is_shop_member(shop_id))
      with check(public.is_shop_member(shop_id));
  end if;
end
$$;

create index if not exists expenses_shop_created_idx
  on public.expenses(shop_id, created_at desc);
