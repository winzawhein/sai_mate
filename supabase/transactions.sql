drop function if exists public.create_sale(uuid,uuid,numeric,uuid,boolean);
create or replace function public.create_sale(p_shop_id uuid,p_product_id uuid,p_quantity numeric,p_customer_id uuid default null,p_on_credit boolean default false,p_request_id uuid default gen_random_uuid()) returns uuid language plpgsql security definer set search_path=public as $$
declare p public.products; sale_id uuid; sale_total numeric;
begin
  if not public.is_shop_member(p_shop_id) then raise exception 'Not authorized'; end if;
  if exists(select 1 from sales where id=p_request_id and shop_id=p_shop_id) then return p_request_id; end if;
  select * into p from products where id=p_product_id and shop_id=p_shop_id for update;
  if p.id is null or p_quantity<=0 or p.stock_quantity<p_quantity then raise exception 'Insufficient stock'; end if;
  sale_total:=p.sale_price*p_quantity;
  insert into sales(id,shop_id,customer_id,total,paid,created_by) values(p_request_id,p_shop_id,p_customer_id,sale_total,case when p_on_credit then 0 else sale_total end,auth.uid()) returning id into sale_id;
  insert into sale_items(sale_id,product_id,quantity,unit_price) values(sale_id,p_product_id,p_quantity,p.sale_price);
  update products set stock_quantity=stock_quantity-p_quantity,updated_at=now() where id=p_product_id;
  insert into stock_movements(shop_id,product_id,movement_type,quantity,reference_id,created_by) values(p_shop_id,p_product_id,'sale',-p_quantity,sale_id,auth.uid());
  if p_on_credit then if p_customer_id is null then raise exception 'Customer required'; end if; insert into debts(shop_id,customer_id,sale_id,amount) values(p_shop_id,p_customer_id,sale_id,sale_total); end if;
  return sale_id;
end;$$;

create or replace function public.create_purchase(p_shop_id uuid,p_product_id uuid,p_quantity numeric) returns uuid language plpgsql security definer set search_path=public as $$
declare p public.products; purchase_id uuid; purchase_total numeric;
begin
  if not public.is_shop_member(p_shop_id) then raise exception 'Not authorized'; end if;
  select * into p from products where id=p_product_id and shop_id=p_shop_id for update;
  if p.id is null or p_quantity<=0 then raise exception 'Invalid purchase'; end if;
  purchase_total:=p.cost_price*p_quantity;
  insert into purchases(shop_id,total,created_by) values(p_shop_id,purchase_total,auth.uid()) returning id into purchase_id;
  insert into purchase_items(purchase_id,product_id,quantity,unit_cost) values(purchase_id,p_product_id,p_quantity,p.cost_price);
  update products set stock_quantity=stock_quantity+p_quantity,updated_at=now() where id=p_product_id;
  insert into stock_movements(shop_id,product_id,movement_type,quantity,reference_id,created_by) values(p_shop_id,p_product_id,'purchase',p_quantity,purchase_id,auth.uid());
  return purchase_id;
end;$$;

create or replace function public.collect_debt_payment(p_shop_id uuid,p_debt_id uuid,p_amount numeric) returns void language plpgsql security definer set search_path=public as $$
declare d public.debts;
begin
  if not public.is_shop_member(p_shop_id) then raise exception 'Not authorized'; end if;
  select * into d from debts where id=p_debt_id and shop_id=p_shop_id for update;
  if d.id is null or p_amount<=0 or d.paid+p_amount>d.amount then raise exception 'Invalid payment'; end if;
  insert into debt_payments(shop_id,debt_id,amount,created_by) values(p_shop_id,p_debt_id,p_amount,auth.uid());
  update debts set paid=paid+p_amount where id=p_debt_id;
end;$$;

alter table sale_items enable row level security; alter table purchase_items enable row level security;
drop policy if exists sale_items_members on sale_items;
drop policy if exists purchase_items_members on purchase_items;
create policy sale_items_members on sale_items for select using(exists(select 1 from sales s where s.id=sale_id and public.is_shop_member(s.shop_id)));
create policy purchase_items_members on purchase_items for select using(exists(select 1 from purchases p where p.id=purchase_id and public.is_shop_member(p.shop_id)));
