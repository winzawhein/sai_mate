-- Run this once after schema.sql. It creates a profile, shop and owner membership
-- whenever a user signs up through Supabase Auth.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
declare new_shop_id uuid;
begin
  insert into public.profiles(id, full_name, phone)
  values(new.id, coalesce(new.raw_user_meta_data->>'full_name','Shop Owner'), new.phone)
  on conflict(id) do nothing;

  insert into public.shops(name, owner_id)
  values(coalesce(new.raw_user_meta_data->>'shop_name','My Shop'), new.id)
  returning id into new_shop_id;

  insert into public.shop_members(shop_id,user_id,role)
  values(new_shop_id,new.id,'owner');
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

insert into storage.buckets(id,name,public)
values('product-images','product-images',false)
on conflict(id) do nothing;

create policy product_images_read on storage.objects for select
using(bucket_id='product-images' and public.is_shop_member(((storage.foldername(name))[1])::uuid));
create policy product_images_insert on storage.objects for insert
with check(bucket_id='product-images' and public.is_shop_member(((storage.foldername(name))[1])::uuid));
create policy product_images_update on storage.objects for update
using(bucket_id='product-images' and public.is_shop_member(((storage.foldername(name))[1])::uuid));
create policy product_images_delete on storage.objects for delete
using(bucket_id='product-images' and public.is_shop_member(((storage.foldername(name))[1])::uuid));
