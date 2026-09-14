-- Sai Mate v2: atomic multi-item sales and purchases.
-- Run once in Supabase SQL Editor after schema.sql and transactions.sql.

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
    insert into sale_items(sale_id,product_id,quantity,unit_price)
      values(sale_id,product_row.id,(item->>'quantity')::numeric,product_row.sale_price);
    update products set stock_quantity=stock_quantity-(item->>'quantity')::numeric,updated_at=now()
      where id=product_row.id;
    insert into stock_movements(shop_id,product_id,movement_type,quantity,reference_id,created_by)
      values(p_shop_id,product_row.id,'sale',-(item->>'quantity')::numeric,sale_id,auth.uid());
  end loop;
  if p_on_credit then insert into debts(shop_id,customer_id,sale_id,amount)
    values(p_shop_id,p_customer_id,sale_id,final_total); end if;
  return sale_id;
end; $$;

create or replace function public.create_purchase_cart(
  p_shop_id uuid, p_items jsonb, p_supplier_id uuid default null,
  p_request_id uuid default gen_random_uuid()
) returns uuid language plpgsql security definer set search_path=public as $$
declare item jsonb; product_row public.products; purchase_id uuid := p_request_id; total_value numeric := 0;
begin
  if not public.is_shop_member(p_shop_id) then raise exception 'Not authorized'; end if;
  if jsonb_array_length(p_items)=0 then raise exception 'Cart is empty'; end if;
  if exists(select 1 from purchases where id=purchase_id and shop_id=p_shop_id) then return purchase_id; end if;
  for item in select * from jsonb_array_elements(p_items) loop
    select * into product_row from products where id=(item->>'product_id')::uuid and shop_id=p_shop_id for update;
    if product_row.id is null or (item->>'quantity')::numeric<=0 then raise exception 'Invalid purchase item'; end if;
    total_value := total_value + coalesce((item->>'unit_cost')::numeric,product_row.cost_price)*(item->>'quantity')::numeric;
  end loop;
  insert into purchases(id,shop_id,supplier_id,total,created_by)
    values(purchase_id,p_shop_id,p_supplier_id,total_value,auth.uid());
  for item in select * from jsonb_array_elements(p_items) loop
    select * into product_row from products where id=(item->>'product_id')::uuid for update;
    insert into purchase_items(purchase_id,product_id,quantity,unit_cost)
      values(purchase_id,product_row.id,(item->>'quantity')::numeric,
        coalesce((item->>'unit_cost')::numeric,product_row.cost_price));
    update products set stock_quantity=stock_quantity+(item->>'quantity')::numeric,
      cost_price=coalesce((item->>'unit_cost')::numeric,cost_price),updated_at=now() where id=product_row.id;
    insert into stock_movements(shop_id,product_id,movement_type,quantity,reference_id,created_by)
      values(p_shop_id,product_row.id,'purchase',(item->>'quantity')::numeric,purchase_id,auth.uid());
  end loop;
  return purchase_id;
end; $$;

grant execute on function public.create_sale_cart(uuid,jsonb,uuid,boolean,numeric,text,uuid) to authenticated;
grant execute on function public.create_purchase_cart(uuid,jsonb,uuid,uuid) to authenticated;
