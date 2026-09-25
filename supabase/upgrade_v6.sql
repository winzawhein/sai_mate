-- Sai Mate v6: debt notes for follow-up workflows.
-- due_date already exists in the original schema.

alter table public.debts
  add column if not exists note text;

create index if not exists debts_due_idx
  on public.debts(shop_id, due_date)
  where paid < amount;
