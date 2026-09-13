-- 1. Staff permission separation — distinct from the coarse user/admin/
--    super_admin role, so a specific person can be granted "add products"
--    without also getting "manage orders", or vice versa.
create table if not exists store_staff_roles (
  user_id uuid primary key references auth.users(id) on delete cascade,
  can_add_products boolean not null default false,
  can_manage_orders boolean not null default false,
  created_at timestamptz not null default now()
);
alter table store_staff_roles enable row level security;
drop policy if exists "store staff manage own row read" on store_staff_roles;
create policy "store staff manage own row read" on store_staff_roles for select using (true);
drop policy if exists "admins manage store staff roles" on store_staff_roles;
create policy "admins manage store staff roles" on store_staff_roles for all
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true))
  with check (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));

-- 2. Orders table — the checkout flow already inserts into this (see
-- cart_screen.dart), wrapped in a try/catch for exactly this case where
-- it doesn't exist yet in a given environment.
create table if not exists orders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id),
  reference text unique not null,
  status text not null default 'pending',
  subtotal numeric not null default 0,
  delivery_fee numeric not null default 0,
  total numeric not null default 0,
  delivery_state text,
  delivery_days integer,
  items jsonb not null default '[]'::jsonb,
  created_at timestamptz not null default now()
);
alter table orders enable row level security;
drop policy if exists "users view own orders" on orders;
create policy "users view own orders" on orders for select using (auth.uid() = user_id);
drop policy if exists "users create own orders" on orders;
create policy "users create own orders" on orders for insert with check (auth.uid() = user_id);

-- 3. AI-scouting fields on products — kept separate from the existing
-- `is_active` (which is the seller's own visibility toggle) so an
-- AI-sourced product can sit in a review queue without touching that.
alter table products add column if not exists is_ai_sourced boolean not null default false;
alter table products add column if not exists source_url text;
alter table products add column if not exists source_price numeric;
alter table products add column if not exists review_status text not null default 'approved'; -- 'approved' | 'pending_review' | 'rejected'
alter table products add column if not exists delivery_estimate text;
-- AI-sourced products have no human seller — this must be nullable for that.
alter table products alter column seller_id drop not null;
-- Admins need to update review_status on products they didn't list
-- themselves (AI-sourced ones have no seller_id at all). This is an
-- ADDITIONAL policy — Postgres OR's policies together for the same
-- operation, so this only widens access, it can't remove whatever
-- update permission already exists for sellers on their own listings.
alter table products enable row level security;
drop policy if exists "admins update any product" on products;
create policy "admins update any product" on products for update
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true))
  with check (exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true));

-- Storefront queries should filter: is_active = true and review_status = 'approved'

-- Lets a caller resolve an email to a user id for staff-role assignment,
-- without exposing the auth.users table directly to the client. Runs as
-- the function owner (security definer) specifically so admins can look
-- up a colleague's id by email from the app.
create or replace function get_user_id_by_email(p_email text)
returns uuid
language sql
security definer
set search_path = public, auth
as $$
  select u.id from auth.users u
  where u.email = p_email
    and exists (select 1 from profiles p where p.id = auth.uid() and p.is_admin = true)
  limit 1;
$$;

-- AI product scout runs every 3 days — proposes a handful of candidates
-- for review each time, rather than daily, to keep the review queue
-- manageable rather than flooding it.
-- Replace ANON_KEY_HERE with your project's anon public key before running.
select cron.schedule(
  'gacom-ai-product-scout',
  '0 8 */3 * *', -- 08:00 UTC every 3rd day
  $$
  select net.http_post(
    url := 'https://rxccipqvyrcfpsadgpzp.supabase.co/functions/v1/ai-product-scout',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ANON_KEY_HERE'),
    body := '{}'::jsonb
  );
  $$
);
