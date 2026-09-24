-- Sai Mate v4: preserve cost at sale time for accurate gross-profit reports.
-- Run once after upgrade_v3.sql in the Supabase SQL Editor.

alter table public.sale_items
  add column if not exists cost_basis numeric(14,2);

update public.sale_items si
set cost_basis = p.cost_price
from public.products p
where si.product_id = p.id and si.cost_basis is null;

alter table public.sale_items
  alter column cost_basis set default 0;

create or replace function public.create_sale_cart(
  p_shop_id uuid, p_items jsonb, p_customer_id uuid default null,
  p_on_credit boolean default false, p_discount numeric default 0,
  p_payment_method text default 'cash', p_request_id uuid default gen_random_uuid()
) returns uuid language plpgsql security definer set search_path=public as $$
declare item jsonb; product_row public.products; sale_id uuid := p_request_id;
  subtotal numeric := 0; final_total numeric;
begin
  if not public.is_shop_member(p_shop_id) then raise exception 'Not authorized'; end if;
  if jsonb_array_length(p_items)=0 then raise exception 'Cart is empty'; end if;
  if exists(select 1 from sales where id=sale_id and shop_id=p_shop_id) then return sale_id; end if;
  for item in select * from jsonb_array_elements(p_items) loop
    select * into product_row from products
      where id=(item->>'product_id')::uuid and shop_id=p_shop_id and deleted_at is null for update;
    if product_row.id is null or (item->>'quantity')::numeric<=0
       or product_row.stock_quantity<(item->>'quantity')::numeric then
      raise exception 'Insufficient stock: %', coalesce(product_row.name,'product');
    end if;
    subtotal := subtotal + product_row.sale_price*(item->>'quantity')::numeric;
  end loop;
  final_total := greatest(0, subtotal-greatest(0,p_discount));
  if p_on_credit and p_customer_id is null then raise exception 'Customer required'; end if;
  insert into sales(id,shop_id,customer_id,total,paid,payment_method,created_by)
    values(sale_id,p_shop_id,p_customer_id,final_total,
      case when p_on_credit then 0 else final_total end,p_payment_method,auth.uid());
  for item in select * from jsonb_array_elements(p_items) loop
    select * into product_row from products where id=(item->>'product_id')::uuid for update;
    insert into sale_items(sale_id,product_id,quantity,unit_price,cost_basis)
      values(sale_id,product_row.id,(item->>'quantity')::numeric,
        product_row.sale_price,product_row.cost_price);
    update products set stock_quantity=stock_quantity-(item->>'quantity')::numeric,updated_at=now()
      where id=product_row.id;
    insert into stock_movements(shop_id,product_id,movement_type,quantity,reference_id,created_by)
      values(p_shop_id,product_row.id,'sale',-(item->>'quantity')::numeric,sale_id,auth.uid());
  end loop;
  if p_on_credit then insert into debts(shop_id,customer_id,sale_id,amount)
    values(p_shop_id,p_customer_id,sale_id,final_total); end if;
  return sale_id;
end; $$;

grant execute on function public.create_sale_cart(uuid,jsonb,uuid,boolean,numeric,text,uuid)
  to authenticated;
