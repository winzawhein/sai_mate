-- Sai Mate v3: safe item returns. Run after upgrade_v2.sql.
create or replace function public.return_sale_item(p_shop_id uuid,p_sale_id uuid,p_product_id uuid,p_quantity numeric)
returns void language plpgsql security definer set search_path=public as $$
declare line public.sale_items; sale_row public.sales; refund numeric; debt_row public.debts;
begin
  if not public.is_shop_member(p_shop_id) then raise exception 'Not authorized'; end if;
  select * into sale_row from sales where id=p_sale_id and shop_id=p_shop_id for update;
  select * into line from sale_items where sale_id=p_sale_id and product_id=p_product_id for update;
  if line.id is null or p_quantity<=0 or p_quantity>line.quantity then raise exception 'Invalid return quantity'; end if;
  refund:=line.unit_price*p_quantity;
  select * into debt_row from debts where sale_id=p_sale_id for update;
  if debt_row.id is not null and debt_row.amount-refund<debt_row.paid then raise exception 'Return exceeds unpaid debt'; end if;
  if p_quantity=line.quantity then delete from sale_items where id=line.id;
  else update sale_items set quantity=quantity-p_quantity where id=line.id; end if;
  update sales set total=greatest(0,total-refund),paid=greatest(0,paid-refund) where id=p_sale_id;
  if debt_row.id is not null then update debts set amount=amount-refund where id=debt_row.id; end if;
  update products set stock_quantity=stock_quantity+p_quantity,updated_at=now() where id=p_product_id;
  insert into stock_movements(shop_id,product_id,movement_type,quantity,reference_id,created_by)
    values(p_shop_id,p_product_id,'return',p_quantity,p_sale_id,auth.uid());
end; $$;
grant execute on function public.return_sale_item(uuid,uuid,uuid,numeric) to authenticated;
