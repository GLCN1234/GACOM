-- Admins could approve/reject products (UPDATE) but were never actually
-- granted permission to delete one — a genuine gap, not present at all
-- until now, which is exactly why every delete attempt was rejected.
alter table products enable row level security;
drop policy if exists "admins delete any product" on products;
create policy "admins delete any product" on products for delete
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('admin', 'super_admin')));
