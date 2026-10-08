-- Apple In-App Purchase support (iOS app only).
-- Web and Android keep using Paystack. iOS purchases are confirmed by the
-- apple-verify edge function, which asks Apple directly and then calls
-- apple_apply_transaction() below with the service role.

create table if not exists public.apple_products (
  product_id    text primary key,
  kind          text not null check (kind in ('topup', 'subscription')),
  label         text not null,
  credit_naira  numeric(12,2),     -- wallet credit for a topup
  premium_days  integer,           -- days of premium for a subscription period
  is_active     boolean not null default true
);
alter table public.apple_products enable row level security;
drop policy if exists "anyone reads apple products" on public.apple_products;
create policy "anyone reads apple products" on public.apple_products for select using (true);

insert into public.apple_products (product_id, kind, label, credit_naira, premium_days) values
  ('com.mobtechsynergies.gacom.premium_monthly', 'subscription', 'GACOM Premium (monthly)', null, 31),
  ('com.mobtechsynergies.gacom.topup_1000',  'topup', 'N1,000 wallet credit',  1000,  null),
  ('com.mobtechsynergies.gacom.topup_2500',  'topup', 'N2,500 wallet credit',  2500,  null),
  ('com.mobtechsynergies.gacom.topup_5000',  'topup', 'N5,000 wallet credit',  5000,  null),
  ('com.mobtechsynergies.gacom.topup_10000', 'topup', 'N10,000 wallet credit', 10000, null)
on conflict (product_id) do nothing;

-- Every Apple transaction we have honoured. transaction_id is unique, so the
-- same purchase can never credit twice.
create table if not exists public.apple_transactions (
  transaction_id          text primary key,
  original_transaction_id text,
  user_id                 uuid not null,
  product_id              text not null,
  environment             text,
  credited_naira          numeric(12,2),
  expires_at              timestamptz,
  created_at              timestamptz not null default now()
);
create index if not exists apple_transactions_user_idx on public.apple_transactions (user_id);
create index if not exists apple_transactions_orig_idx on public.apple_transactions (original_transaction_id);
alter table public.apple_transactions enable row level security;
-- No policies: only the service role (edge function) touches this table.

create or replace function public.apple_apply_transaction(
  p_user uuid,
  p_transaction_id text,
  p_original_transaction_id text,
  p_product_id text,
  p_environment text,
  p_expires_at timestamptz
) returns jsonb
language plpgsql security definer set search_path = public as $$
declare
  prod public.apple_products;
  prior public.apple_transactions;
  owner_of_original uuid;
  bal_before numeric;
  bal_after numeric;
  new_expiry timestamptz;
begin
  select * into prod from public.apple_products where product_id = p_product_id and is_active;
  if not found then
    return jsonb_build_object('success', false, 'error', 'Unknown product');
  end if;

  select * into prior from public.apple_transactions where transaction_id = p_transaction_id;
  if found and prior.user_id <> p_user then
    return jsonb_build_object('success', false, 'error', 'This purchase belongs to another account');
  end if;

  if prod.kind = 'topup' then
    if found then
      select wallet_balance into bal_after from public.profiles where id = p_user;
      return jsonb_build_object('success', true, 'kind', 'topup', 'already', true, 'balance', bal_after);
    end if;
    insert into public.apple_transactions (transaction_id, original_transaction_id, user_id, product_id, environment, credited_naira)
      values (p_transaction_id, p_original_transaction_id, p_user, p_product_id, p_environment, prod.credit_naira);
    select wallet_balance into bal_before from public.profiles where id = p_user for update;
    bal_after := coalesce(bal_before, 0) + prod.credit_naira;
    update public.profiles set wallet_balance = bal_after where id = p_user;
    insert into public.wallet_transactions (user_id, type, amount, balance_before, balance_after, status, reference, description)
      values (p_user, 'deposit', prod.credit_naira, coalesce(bal_before, 0), bal_after, 'success',
              'APPLE_' || p_transaction_id, 'Apple In-App Purchase: ' || prod.label);
    return jsonb_build_object('success', true, 'kind', 'topup', 'credited', prod.credit_naira, 'balance', bal_after);
  end if;

  -- subscription
  if p_expires_at is null or p_expires_at <= now() then
    return jsonb_build_object('success', false, 'error', 'This subscription has expired');
  end if;
  -- one Apple subscription cannot be shared across several GACOM accounts
  select user_id into owner_of_original from public.apple_transactions
    where original_transaction_id = p_original_transaction_id limit 1;
  if owner_of_original is not null and owner_of_original <> p_user then
    return jsonb_build_object('success', false, 'error', 'This subscription is linked to another account');
  end if;
  if not found then
    insert into public.apple_transactions (transaction_id, original_transaction_id, user_id, product_id, environment, expires_at)
      values (p_transaction_id, p_original_transaction_id, p_user, p_product_id, p_environment, p_expires_at);
  end if;

  select greatest(coalesce(max(expires_at), p_expires_at), p_expires_at) into new_expiry
    from public.edu_subscriptions where user_id = p_user and status = 'active';
  new_expiry := coalesce(new_expiry, p_expires_at);

  update public.edu_subscriptions
     set expires_at = new_expiry, plan = 'apple_monthly', payment_channel = 'apple',
         auto_renew = false, authorization_code = null, renewal_failed_count = 0
   where user_id = p_user and status = 'active';
  if not found then
    insert into public.edu_subscriptions (user_id, status, plan, amount, reference, expires_at, payment_channel, auto_renew)
      values (p_user, 'active', 'apple_monthly', 0, 'APPLE_' || coalesce(p_original_transaction_id, p_transaction_id), new_expiry, 'apple', false);
  end if;
  return jsonb_build_object('success', true, 'kind', 'subscription', 'expires_at', new_expiry);
end;
$$;
revoke all on function public.apple_apply_transaction(uuid, text, text, text, text, timestamptz) from public, anon, authenticated;
grant execute on function public.apple_apply_transaction(uuid, text, text, text, text, timestamptz) to service_role;

notify pgrst, 'reload schema';
