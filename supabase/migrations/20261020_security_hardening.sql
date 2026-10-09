-- =============================================================================
-- 20261020  SECURITY HARDENING  (applies last; fully idempotent)
--
-- Findings and rationale: docs/SECURITY_AUDIT.md (ids SEC-xx referenced below).
-- Design rules:
--   * RLS decides ROWS, column privileges + guard triggers decide COLUMNS.
--   * "Client" = current_user in (anon, authenticated). Guard triggers are
--     SECURITY INVOKER, so they bind direct client DML but never server code
--     (SECURITY DEFINER RPCs, service_role, edge functions).
--   * Money / XP / prizes are only ever changed by SECURITY DEFINER code that
--     derives the actor from auth.uid(), never from a parameter.
--   * Internal helpers are executable only by service_role / definer callers.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 0. Shared helpers
-- -----------------------------------------------------------------------------
create table if not exists public.sec_rate_hits (
  rk text not null,
  at timestamptz not null default clock_timestamp()
);
create index if not exists sec_rate_hits_idx on public.sec_rate_hits (rk, at desc);
alter table public.sec_rate_hits enable row level security;
revoke all on public.sec_rate_hits from public, anon, authenticated;

create or replace function public.sec_client()
returns boolean language sql stable set search_path = pg_catalog as
$$ select current_user in ('anon', 'authenticated') $$;

create or replace function public.sec_is_admin()
returns boolean language sql stable security definer set search_path = public, pg_temp as
$$ select exists (select 1 from public.profiles p where p.id = auth.uid() and p.role::text in ('admin', 'super_admin')) $$;

create or replace function public.sec_is_super()
returns boolean language sql stable security definer set search_path = public, pg_temp as
$$ select exists (select 1 from public.profiles p where p.id = auth.uid() and p.role::text = 'super_admin') $$;

-- Sliding-window limiter keyed by caller. For SECURITY DEFINER RPC bodies only.
create or replace function public.sec_rl(p_key text, p_max integer, p_secs integer)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare k text := coalesce(auth.uid()::text, 'anon') || ':' || left(p_key, 80); n integer;
begin
  perform pg_advisory_xact_lock(hashtextextended('rl:' || k, 0));
  select count(*) into n from public.sec_rate_hits h
   where h.rk = k and h.at > clock_timestamp() - make_interval(secs => p_secs);
  if n >= p_max then
    raise exception 'Too many requests. Please slow down and try again shortly.' using errcode = '54000';
  end if;
  insert into public.sec_rate_hits (rk) values (k);
  if random() < 0.02 then delete from public.sec_rate_hits where at < now() - interval '1 day'; end if;
end $$;

-- Trigger-only wrappers (executable by clients, but refuse to run outside a trigger).
create or replace function public.sec_i_rl(p_key text, p_max integer, p_secs integer)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if pg_trigger_depth() = 0 then raise exception 'not allowed' using errcode = '42501'; end if;
  if p_max > 2000 or p_secs > 86400 then raise exception 'not allowed' using errcode = '42501'; end if;
  perform public.sec_rl(p_key, p_max, p_secs);
end $$;

create or replace function public.sec_i_note(p_kind text, p_details jsonb)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if pg_trigger_depth() = 0 then raise exception 'not allowed' using errcode = '42501'; end if;
  if to_regprocedure('public.security_log(text,text,uuid,uuid,jsonb,text,text,text)') is not null then
    perform public.security_log(p_kind, 'high', auth.uid(), null, coalesce(p_details, '{}'::jsonb), 'guard', null, null);
  end if;
exception when others then null;
end $$;

-- Patch helper: inject a statement at the top of an existing function body.
create or replace function public.sec_patch_fn(p_fn text, p_snippet text)
returns integer language plpgsql security definer set search_path = public, pg_temp as $$
declare r record; def text; n integer := 0;
begin
  for r in select p.oid from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_fn and p.prokind = 'f' loop
    def := pg_get_functiondef(r.oid);
    if position('/*sec:' || md5(p_snippet) || '*/' in def) = 0 and def ~ E'\nbegin\n' then
      def := regexp_replace(def, E'\nbegin\n', E'\nbegin\n  /*sec:' || md5(p_snippet) || '*/ ' || p_snippet || E'\n');
      execute def;
      n := n + 1;
    end if;
  end loop;
  return n;
end $$;
revoke all on function public.sec_patch_fn(text, text) from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- 1. SECURITY DEFINER functions: pin search_path (pg_temp last)  [SEC-14]
-- -----------------------------------------------------------------------------
do $$
declare r record; cur text;
begin
  for r in
    select p.oid::regprocedure as sig,
           (select substring(c from 'search_path=(.*)$') from unnest(coalesce(p.proconfig, '{}')) c
             where c like 'search_path=%' limit 1) as sp
    from pg_proc p
    where p.pronamespace = 'public'::regnamespace and p.prosecdef and p.prokind = 'f'
      and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e')
  loop
    if r.sp is null then
      execute format('alter function %s set search_path = public, pg_temp', r.sig);
    elsif r.sp not like '%pg_temp%' then
      execute format('alter function %s set search_path = %s, pg_temp', r.sig, r.sp);
    end if;
  end loop;
end $$;

do $$ begin
  execute format('revoke temporary on database %I from public, anon, authenticated', current_database());
exception when others then raise notice 'temp revoke skipped: %', sqlerrm;
end $$;

-- -----------------------------------------------------------------------------
-- 2. profiles: no self-service privilege / wallet / verification escalation  [SEC-01]
-- -----------------------------------------------------------------------------
-- The app-sec agent's separate guards (20261020_profile_and_wallet_guards.sql, now a no-op) were folded
-- into this file. Drop them if an earlier version was ever applied, so there is exactly one guard each.
drop trigger if exists trg_guard_profile_protected_columns on public.profiles;
drop trigger if exists trg_guard_participant_payment_status on public.competition_participants;
drop function if exists public.guard_profile_protected_columns();
drop function if exists public.guard_participant_payment_status();
drop function if exists public.is_caller_admin();

create or replace function public.sec_profiles_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not public.sec_client() then return new; end if;     -- server paths (RPCs, service_role)
  if tg_op = 'INSERT' then
    perform public.sec_i_note('profile_insert_blocked', jsonb_build_object('id', new.id));
    raise exception 'permission denied: profiles are created by the system' using errcode = '42501';
  end if;
  -- Wallet columns are owned by the server. Older app builds still write them after a
  -- paid competition entry (the debit now happens in join_paid_competition), so keep the old
  -- value instead of failing; they can never be raised or lowered by a client.
  new.wallet_balance := old.wallet_balance;
  new.wallet_locked_balance := old.wallet_locked_balance;

  if new.id is distinct from old.id
     or new.role is distinct from old.role
     or new.is_admin is distinct from old.is_admin
     or new.is_banned is distinct from old.is_banned
     or new.ban_reason is distinct from old.ban_reason
     or new.verification_id_url is distinct from old.verification_id_url
     or new.total_winnings is distinct from old.total_winnings
     or new.competitions_won is distinct from old.competitions_won
     or new.competitions_entered is distinct from old.competitions_entered
     or new.followers_count is distinct from old.followers_count
     or new.following_count is distinct from old.following_count
     or new.posts_count is distinct from old.posts_count
     or new.newsletter_last_sent_issue_id is distinct from old.newsletter_last_sent_issue_id
  then
    perform public.sec_i_note('profile_escalation_attempt',
      jsonb_build_object('old_role', old.role::text, 'new_role', new.role::text,
                         'is_admin', new.is_admin, 'wallet', new.wallet_balance));
    raise exception 'permission denied: protected profile column' using errcode = '42501';
  end if;
  -- A user may only ask for verification; approval is an admin action.
  if new.verification_status is distinct from old.verification_status then
    if not (new.verification_status::text = 'pending' and old.verification_status::text in ('unverified', 'rejected')) then
      raise exception 'permission denied: verification is reviewed by an admin' using errcode = '42501';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists aa_profiles_sec_guard on public.profiles;
create trigger aa_profiles_sec_guard before insert or update on public.profiles
  for each row execute function public.sec_profiles_guard();

-- Column privileges as a second layer (guard trigger stays authoritative).
revoke insert, update, delete, truncate, references, trigger on public.profiles from anon, authenticated;
grant update (username, display_name, bio, avatar_url, banner_url, gamer_tag, favorite_games, location,
              website, twitter_handle, discord_handle, is_online, last_seen, is_private, country,
              newsletter_subscribed, updated_at, verification_status,
              wallet_balance, wallet_locked_balance)
  on public.profiles to authenticated;

-- Anonymous visitors see only the public card, never wallet / KYC / ban data.  [SEC-02]
do $$
declare cols text;
begin
  select string_agg(quote_ident(column_name), ', ' order by ordinal_position) into cols
  from information_schema.columns
  where table_schema = 'public' and table_name = 'profiles'
    and column_name not in ('wallet_balance', 'wallet_locked_balance', 'total_winnings', 'verification_id_url',
                            'ban_reason', 'is_admin', 'newsletter_subscribed', 'newsletter_last_sent_issue_id',
                            'last_seen', 'is_banned');
  execute 'revoke select on public.profiles from anon';
  execute format('grant select (%s) on public.profiles to anon', cols);
end $$;

-- Own wallet in one call, so the client can stop selecting wallet columns from profiles.
create or replace function public.my_wallet()
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object('wallet_balance', p.wallet_balance, 'wallet_locked_balance', p.wallet_locked_balance,
                            'total_winnings', p.total_winnings)
  from public.profiles p where p.id = auth.uid()
$$;

-- Staff actions on other users go through audited RPCs, not direct UPDATEs.
create or replace function public.admin_set_user_role(p_user uuid, p_role text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare cur text;
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  if not exists (select 1 from pg_enum e where e.enumtypid = 'public.user_role'::regtype and e.enumlabel = p_role) then raise exception 'Unknown role'; end if;
  select role::text into cur from public.profiles where id = p_user for update;
  if not found then raise exception 'User not found'; end if;
  if (p_role in ('admin', 'super_admin') or cur in ('admin', 'super_admin')) and not public.sec_is_super() then
    raise exception 'Only a super admin can change admin roles' using errcode = '42501';
  end if;
  if p_user = auth.uid() then raise exception 'You cannot change your own role'; end if;
  update public.profiles set role = p_role::user_role where id = p_user;
  perform public.security_log('role_changed', 'high', auth.uid(), p_user,
    jsonb_build_object('from', cur, 'to', p_role), 'admin_set_user_role', null, null);
  return jsonb_build_object('success', true);
end $$;

create or replace function public.admin_set_user_ban(p_user uuid, p_banned boolean, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  if p_user = auth.uid() then raise exception 'You cannot ban yourself'; end if;
  if exists (select 1 from public.profiles where id = p_user and role::text in ('admin', 'super_admin')) and not public.sec_is_super() then
    raise exception 'Only a super admin can ban an admin' using errcode = '42501';
  end if;
  update public.profiles set is_banned = p_banned, ban_reason = case when p_banned then left(coalesce(p_reason, 'Admin ban'), 300) else null end
   where id = p_user;
  perform public.security_log('user_ban_changed', 'medium', auth.uid(), p_user,
    jsonb_build_object('banned', p_banned), 'admin_set_user_ban', null, null);
  return jsonb_build_object('success', true);
end $$;

create or replace function public.admin_set_verification(p_user uuid, p_status text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  if p_status not in ('unverified', 'pending', 'verified', 'rejected') then raise exception 'Unknown status'; end if;
  update public.profiles set verification_status = p_status::verification_status where id = p_user;
  perform public.security_log('verification_changed', 'medium', auth.uid(), p_user,
    jsonb_build_object('status', p_status), 'admin_set_verification', null, null);
  return jsonb_build_object('success', true);
end $$;

-- New accounts: never fail sign-up on a username clash, never trust metadata beyond two text fields.
create or replace function public.handle_new_user()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare uname text := left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'username'), ''), 'user_' || substr(new.id::text, 1, 8)), 40);
begin
  begin
    insert into public.profiles (id, username, display_name)
    values (new.id, uname, left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), 'Gamer'), 60));
  exception when unique_violation then
    insert into public.profiles (id, username, display_name)
    values (new.id, 'user_' || substr(replace(new.id::text, '-', ''), 1, 12), left(coalesce(nullif(btrim(new.raw_user_meta_data ->> 'display_name'), ''), 'Gamer'), 60));
  end;
  return new;
end $$;

-- -----------------------------------------------------------------------------
-- 3. Wallet and money tables  [SEC-03 .. SEC-07]
-- -----------------------------------------------------------------------------
-- 3a. Clients can no longer write ledger rows. (Older builds still try after a paid entry;
--     the insert is silently dropped because the server now writes the real row.)
drop policy if exists "gacom_wallet_insert" on public.wallet_transactions;
create or replace function public.sec_wtx_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if public.sec_client() then return null; end if;
  return new;
end $$;
drop trigger if exists aa_wtx_sec_guard on public.wallet_transactions;
create trigger aa_wtx_sec_guard before insert on public.wallet_transactions
  for each row execute function public.sec_wtx_guard();
revoke update, delete on public.wallet_transactions from anon, authenticated;
-- (wallet_transactions.reference is already UNIQUE, which also makes ledger credits idempotent)

-- 3b. Paid competition entry. ONE path: join_paid_competition() debits, records the ledger row
--     (idempotent reference) and inserts the participant in a single transaction. A direct client
--     insert into a paid competition is refused (never debits, so a double debit is impossible);
--     free competitions are still joined by plain insert.
create or replace function public.sec_i_enter(p_comp uuid, p_user uuid)
returns text language plpgsql security definer set search_path = public, pg_temp as $$
declare c record; fee numeric;
begin
  if pg_trigger_depth() = 0 or p_user is distinct from auth.uid() then
    raise exception 'not allowed' using errcode = '42501';
  end if;
  select * into c from public.competitions where id = p_comp;
  if not found then raise exception 'Competition not found'; end if;
  if exists (select 1 from public.competition_participants x where x.competition_id = p_comp and x.user_id = p_user) then
    raise exception 'You have already joined this competition' using errcode = '23505';
  end if;
  if c.status::text in ('ended', 'cancelled') then raise exception 'Registration is closed'; end if;
  if c.max_participants is not null and c.current_participants >= c.max_participants then
    raise exception 'This competition is full';
  end if;
  fee := coalesce(c.entry_fee, 0);
  if c.competition_type::text <> 'paid' or fee <= 0 then return 'free'; end if;
  raise exception 'Paid entry must go through join_paid_competition' using errcode = '42501';
end $$;

create or replace function public.join_paid_competition(p_competition_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid(); c record; fee numeric; bal numeric; ok integer; tag text; ref text;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in again'); end if;
  perform pg_advisory_xact_lock(hashtextextended('gacom:wallet:' || uid::text, 0));
  perform public.sec_rl('wallet_op', 30, 60);
  select * into c from public.competitions where id = p_competition_id;
  if not found then return jsonb_build_object('success', false, 'error', 'Competition not found'); end if;
  fee := coalesce(c.entry_fee, 0);
  if c.competition_type::text <> 'paid' or fee <= 0 then
    return jsonb_build_object('success', false, 'error', 'This is not a paid competition');
  end if;
  if exists (select 1 from public.competition_participants where competition_id = p_competition_id and user_id = uid) then
    return jsonb_build_object('success', false, 'error', 'You have already joined');
  end if;
  if c.status::text in ('ended', 'cancelled') then
    return jsonb_build_object('success', false, 'error', 'Registration is closed');
  end if;
  if c.max_participants is not null and coalesce(c.current_participants, 0) >= c.max_participants then
    return jsonb_build_object('success', false, 'error', 'This competition is full');
  end if;

  select wallet_balance into bal from public.profiles where id = uid for update;
  update public.profiles
     set wallet_balance = wallet_balance - fee, wallet_locked_balance = coalesce(wallet_locked_balance, 0) + fee
   where id = uid and wallet_balance >= fee;
  get diagnostics ok = row_count;
  if ok = 0 then
    return jsonb_build_object('success', false, 'error', 'Insufficient wallet balance. Please fund your wallet.');
  end if;

  select raw_user_meta_data ->> 'gamer_tag' into tag from auth.users where id = uid;
  insert into public.competition_participants (competition_id, user_id, payment_status, gamer_tag_used)
  values (p_competition_id, uid, 'paid', tag);

  ref := 'ENTRY_' || p_competition_id::text || '_' || uid::text;
  if exists (select 1 from public.wallet_transactions where reference = ref) then   -- re-entry after removal
    ref := ref || '_' || floor(extract(epoch from clock_timestamp()) * 1000)::bigint::text;
  end if;
  insert into public.wallet_transactions (user_id, type, amount, balance_before, balance_after, status, description, reference)
  values (uid, 'competition_entry', fee, bal, bal - fee, 'success', 'Entry fee: ' || left(coalesce(c.title, 'competition'), 80), ref);
  return jsonb_build_object('success', true);
end $$;

create or replace function public.sec_participants_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not public.sec_client() then return new; end if;
  if new.user_id is distinct from auth.uid() then raise exception 'permission denied' using errcode = '42501'; end if;
  new.payment_status := public.sec_i_enter(new.competition_id, new.user_id);
  new.rank := null; new.score := null; new.checked_in := false; new.transaction_id := null;
  return new;
end $$;
drop trigger if exists aa_participants_sec_guard on public.competition_participants;
create trigger aa_participants_sec_guard before insert on public.competition_participants
  for each row execute function public.sec_participants_guard();

-- 3c. Withdrawals: cannot exceed balance, cannot self-approve.
drop policy if exists "users_own_withdrawals" on public.withdrawal_requests;
drop policy if exists "wd select" on public.withdrawal_requests;
drop policy if exists "wd insert own" on public.withdrawal_requests;
drop policy if exists "wd update staff" on public.withdrawal_requests;
create policy "wd select" on public.withdrawal_requests for select to authenticated
  using (user_id = auth.uid() or public.sec_is_admin()
         or exists (select 1 from public.exco_assignments x where x.exco_id = auth.uid() and x.exco_role = 'finance_team'));
create policy "wd insert own" on public.withdrawal_requests for insert to authenticated
  with check (user_id = auth.uid());
create policy "wd update staff" on public.withdrawal_requests for update to authenticated
  using (public.sec_is_admin()
         or exists (select 1 from public.exco_assignments x where x.exco_id = auth.uid() and x.exco_role = 'finance_team'))
  with check (public.sec_is_admin()
         or exists (select 1 from public.exco_assignments x where x.exco_id = auth.uid() and x.exco_role = 'finance_team'));
revoke delete on public.withdrawal_requests from anon, authenticated;

create or replace function public.sec_withdrawal_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
declare bal numeric; pending numeric;
begin
  if not public.sec_client() then return new; end if;
  if tg_op = 'INSERT' then
    perform public.sec_i_rl('withdraw', 5, 3600);
    perform pg_advisory_xact_lock(hashtextextended('gacom:wd:' || new.user_id::text, 0));
    if new.amount is null or new.amount <= 0 then raise exception 'Invalid amount'; end if;
    select wallet_balance into bal from public.profiles where id = auth.uid();
    select coalesce(sum(amount), 0) into pending from public.withdrawal_requests where user_id = auth.uid() and status = 'pending';
    if new.amount > coalesce(bal, 0) - pending then raise exception 'Insufficient wallet balance'; end if;
    new.status := 'pending'; new.processed_by := null;
  else
    -- staff only reach here (RLS); they may change status/processed_by, never the money or owner
    new.amount := old.amount; new.user_id := old.user_id;
    new.account_number := old.account_number; new.bank_name := old.bank_name;
  end if;
  return new;
end $$;
drop trigger if exists aa_wd_sec_guard on public.withdrawal_requests;
create trigger aa_wd_sec_guard before insert or update on public.withdrawal_requests
  for each row execute function public.sec_withdrawal_guard();

-- 3d. Orders: server decides status and prices.
create or replace function public.sec_orders_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
declare n jsonb; it jsonb; items jsonb := '[]'::jsonb; sub numeric := 0; p numeric; q integer; fee numeric; k text;
begin
  if not public.sec_client() then return new; end if;
  if tg_op <> 'INSERT' then raise exception 'permission denied' using errcode = '42501'; end if;
  perform public.sec_i_rl('order_create', 20, 3600);
  n := to_jsonb(new);
  n := jsonb_set(n, '{status}', '"pending"');
  foreach k in array array['payment_reference', 'paystack_reference', 'tracking_number'] loop
    if n ? k then n := jsonb_set(n, array[k], 'null'::jsonb); end if;
  end loop;
  if n ? 'items' and jsonb_typeof(n -> 'items') = 'array' then
    for it in select * from jsonb_array_elements(n -> 'items') loop
      q := greatest(1, least(coalesce((it ->> 'quantity')::integer, 1), 100));
      select pr.price into p from public.products pr where pr.id = (it ->> 'product_id')::uuid and pr.is_active;
      if p is null then raise exception 'A product in your cart is no longer available'; end if;
      sub := sub + p * q;
      items := items || (it || jsonb_build_object('quantity', q, 'unit_price', p, 'total_price', p * q));
    end loop;
    n := jsonb_set(n, '{items}', items);
    fee := greatest(0, least(coalesce((n ->> 'delivery_fee')::numeric, 0), 50000));
    if n ? 'delivery_fee' then n := jsonb_set(n, '{delivery_fee}', to_jsonb(fee)); end if;
    if n ? 'subtotal' then n := jsonb_set(n, '{subtotal}', to_jsonb(sub)); end if;
    if n ? 'total' then n := jsonb_set(n, '{total}', to_jsonb(sub + fee)); end if;
    if n ? 'total_amount' then n := jsonb_set(n, '{total_amount}', to_jsonb(sub + fee)); end if;
  end if;
  new := jsonb_populate_record(new, n);
  return new;
end $$;
drop trigger if exists aa_orders_sec_guard on public.orders;
create trigger aa_orders_sec_guard before insert or update on public.orders
  for each row execute function public.sec_orders_guard();

-- order_items had no RLS at all: anyone could read every order and rewrite prices.
alter table public.order_items enable row level security;
drop policy if exists "oi select" on public.order_items;
drop policy if exists "oi insert" on public.order_items;
create policy "oi select" on public.order_items for select to authenticated
  using (exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid())
         or public.sec_is_admin()
         or exists (select 1 from public.products pr where pr.id = product_id and pr.seller_id = auth.uid()));
create policy "oi insert" on public.order_items for insert to authenticated
  with check (exists (select 1 from public.orders o where o.id = order_id and o.user_id = auth.uid() and o.status::text = 'pending'));
create or replace function public.sec_order_items_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
declare p numeric;
begin
  if not public.sec_client() then return new; end if;
  select pr.price into p from public.products pr where pr.id = new.product_id and pr.is_active;
  if p is null then raise exception 'Unknown product'; end if;
  new.quantity := greatest(1, least(coalesce(new.quantity, 1), 100));
  new.unit_price := p; new.total_price := p * new.quantity;
  return new;
end $$;
drop trigger if exists aa_oi_sec_guard on public.order_items;
create trigger aa_oi_sec_guard before insert on public.order_items
  for each row execute function public.sec_order_items_guard();
revoke update, delete on public.order_items from anon, authenticated;

-- 3e. Ads: no self-approval, no editing of delivery counters.
create or replace function public.sec_ads_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not public.sec_client() or public.sec_is_admin() then return new; end if;
  if tg_op = 'INSERT' then
    new.status := 'pending_review'; new.impressions := 0; new.clicks := 0; new.spend := 0;
  else
    new.impressions := old.impressions; new.clicks := old.clicks; new.spend := old.spend;
    new.advertiser_id := old.advertiser_id;
    if new.status is distinct from old.status and new.status not in ('paused', 'cancelled') then
      new.status := old.status;
    end if;
  end if;
  return new;
end $$;
drop trigger if exists aa_ads_sec_guard on public.ad_campaigns;
create trigger aa_ads_sec_guard before insert or update on public.ad_campaigns
  for each row execute function public.sec_ads_guard();

-- 3f. KYC requests: a user files them, only staff decide them.
create or replace function public.sec_verif_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not public.sec_client() then return new; end if;
  perform public.sec_i_rl('verif_request', 5, 86400);
  new.status := 'pending'; new.reviewed_by := null; new.reviewed_at := null; new.review_note := null;
  return new;
end $$;
drop trigger if exists aa_verif_sec_guard on public.verification_requests;
create trigger aa_verif_sec_guard before insert on public.verification_requests
  for each row execute function public.sec_verif_guard();

-- -----------------------------------------------------------------------------
-- 4. Privilege tables: exco / blog  [SEC-08]
-- -----------------------------------------------------------------------------
drop policy if exists "admins_manage_exco" on public.exco_assignments;      -- let a user insert their own exco row
drop policy if exists "Exco blog editors can manage posts" on public.blog_posts;
create policy "Exco blog editors can manage posts" on public.blog_posts for all to authenticated
  using (public.sec_is_admin()
         or exists (select 1 from public.exco_assignments e where e.exco_id = auth.uid() and e.exco_role = 'blog_editor')
         or exists (select 1 from public.admin_permissions a where a.admin_id = auth.uid() and a.permission = 'manage_blog'))
  with check (public.sec_is_admin()
         or exists (select 1 from public.exco_assignments e where e.exco_id = auth.uid() and e.exco_role = 'blog_editor')
         or exists (select 1 from public.admin_permissions a where a.admin_id = auth.uid() and a.permission = 'manage_blog'));

-- -----------------------------------------------------------------------------
-- 5. Chat / notifications / error log  [SEC-09 .. SEC-11]
-- -----------------------------------------------------------------------------
drop policy if exists "gacom_chat_members_insert" on public.chat_members;
drop policy if exists "chat_members_insert" on public.chat_members;
drop policy if exists "gacom_chats_insert" on public.chats;
-- legacy self-referential SELECT policies recurse (chats UPDATE -> chat_members -> chat_members) and are
-- superseded by chats_select / chat_members_select, which go through the SECURITY DEFINER user_chat_ids()
drop policy if exists "gacom_chat_members_select" on public.chat_members;
drop policy if exists "gacom_chats_select" on public.chats;
create or replace function public.sec_chat_creator(p_chat uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as
$$ select exists (select 1 from public.chats c where c.id = p_chat and c.created_by = auth.uid()) $$;
create policy "chat_members_insert" on public.chat_members for insert to authenticated
  with check (public.sec_chat_creator(chat_id));
create or replace function public.sec_chat_members_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if public.sec_client() then perform public.sec_i_rl('chat_member_add', 60, 3600); end if;
  return new;
end $$;
drop trigger if exists aa_chat_members_sec on public.chat_members;
create trigger aa_chat_members_sec before insert on public.chat_members
  for each row execute function public.sec_chat_members_guard();
create or replace function public.sec_chats_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not public.sec_client() then return new; end if;
  if tg_op = 'INSERT' then
    perform public.sec_i_rl('chat_create', 30, 3600);
  else
    new.created_by := old.created_by; new.type := old.type; new.community_id := old.community_id;
  end if;
  return new;
end $$;
drop trigger if exists aa_chats_sec on public.chats;
create trigger aa_chats_sec before insert or update on public.chats
  for each row execute function public.sec_chats_guard();

-- Notifications are written by SECURITY DEFINER triggers/RPCs only (no client INSERT exists in lib/).
drop policy if exists "System can insert notifications" on public.notifications;
drop policy if exists "gacom_notifs_insert" on public.notifications;
revoke insert, delete on public.notifications from anon, authenticated;

-- error_logs: anonymous crash reports stay possible, but bounded and not forgeable.
drop policy if exists "anyone logs errors" on public.error_logs;
create policy "anyone logs errors" on public.error_logs for insert to anon, authenticated
  with check (user_id is null or user_id = auth.uid());
create or replace function public.sec_errlog_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not public.sec_client() then return new; end if;
  perform public.sec_i_rl('errlog', case when auth.uid() is null then 300 else 30 end, 60);
  new.error := left(new.error, 4000); new.stack := left(new.stack, 8000); new.route := left(new.route, 300);
  return new;
end $$;
drop trigger if exists aa_errlog_sec on public.error_logs;
create trigger aa_errlog_sec before insert on public.error_logs
  for each row execute function public.sec_errlog_guard();

-- -----------------------------------------------------------------------------
-- 6. Tables that shipped without RLS  [SEC-12]
-- -----------------------------------------------------------------------------
alter table public.product_reviews enable row level security;
alter table public.post_comment_likes enable row level security;
alter table public.product_categories enable row level security;
alter table public.blog_likes enable row level security;
alter table public.blog_comments enable row level security;
alter table public.reports enable row level security;

drop policy if exists "pr read" on public.product_reviews;   create policy "pr read" on public.product_reviews for select using (true);
drop policy if exists "pr write own" on public.product_reviews;
create policy "pr write own" on public.product_reviews for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "pr update own" on public.product_reviews;
create policy "pr update own" on public.product_reviews for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());
drop policy if exists "pr delete own" on public.product_reviews;
create policy "pr delete own" on public.product_reviews for delete to authenticated using (user_id = auth.uid() or public.sec_is_admin());
drop policy if exists "pcl read" on public.post_comment_likes;  create policy "pcl read" on public.post_comment_likes for select using (true);
drop policy if exists "pcl insert" on public.post_comment_likes;
create policy "pcl insert" on public.post_comment_likes for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "pcl delete" on public.post_comment_likes;
create policy "pcl delete" on public.post_comment_likes for delete to authenticated using (user_id = auth.uid());
drop policy if exists "pc read" on public.product_categories;   create policy "pc read" on public.product_categories for select using (true);
drop policy if exists "pc admin" on public.product_categories;
create policy "pc admin" on public.product_categories for all to authenticated using (public.sec_is_admin()) with check (public.sec_is_admin());
drop policy if exists "bl read" on public.blog_likes;   create policy "bl read" on public.blog_likes for select using (true);
drop policy if exists "bl insert" on public.blog_likes;
create policy "bl insert" on public.blog_likes for insert to authenticated with check (user_id = auth.uid());
drop policy if exists "bl delete" on public.blog_likes;
create policy "bl delete" on public.blog_likes for delete to authenticated using (user_id = auth.uid());
drop policy if exists "bc read" on public.blog_comments;   create policy "bc read" on public.blog_comments for select using (true);
drop policy if exists "bc insert" on public.blog_comments;
create policy "bc insert" on public.blog_comments for insert to authenticated with check (author_id = auth.uid());
drop policy if exists "bc delete" on public.blog_comments;
create policy "bc delete" on public.blog_comments for delete to authenticated using (author_id = auth.uid() or public.sec_is_admin());
drop policy if exists "rep insert" on public.reports;
create policy "rep insert" on public.reports for insert to authenticated with check (reporter_id = auth.uid());
drop policy if exists "rep read" on public.reports;
create policy "rep read" on public.reports for select to authenticated using (reporter_id = auth.uid() or public.sec_is_admin());
drop policy if exists "rep admin" on public.reports;
create policy "rep admin" on public.reports for update to authenticated using (public.sec_is_admin()) with check (public.sec_is_admin());

create or replace function public.sec_reviews_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if public.sec_client() then
    new.is_verified_purchase := false;
    new.rating := greatest(1, least(new.rating, 5));
    new.review := left(new.review, 2000);
  end if;
  return new;
end $$;
drop trigger if exists aa_reviews_sec on public.product_reviews;
create trigger aa_reviews_sec before insert or update on public.product_reviews
  for each row execute function public.sec_reviews_guard();

-- Social counters and moderation flags cannot be set by the author.
create or replace function public.sec_posts_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not public.sec_client() then return new; end if;
  if tg_op = 'INSERT' then
    new.likes_count := 0; new.comments_count := 0; new.shares_count := 0; new.views_count := 0;
    new.is_pinned := false; new.is_featured := false;
  else
    new.likes_count := old.likes_count; new.comments_count := old.comments_count; new.shares_count := old.shares_count;
    new.views_count := old.views_count; new.is_pinned := old.is_pinned; new.is_featured := old.is_featured;
    new.author_id := old.author_id;
  end if;
  return new;
end $$;
drop trigger if exists aa_posts_sec on public.posts;
create trigger aa_posts_sec before insert or update on public.posts
  for each row execute function public.sec_posts_guard();

-- -----------------------------------------------------------------------------
-- 7. Points / streak / quest ledgers a client can still insert  [SEC-13]
-- -----------------------------------------------------------------------------
create or replace function public.sec_scores_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
declare day_total bigint;
begin
  if not public.sec_client() then return new; end if;
  if new.user_id is distinct from auth.uid() then raise exception 'permission denied' using errcode = '42501'; end if;
  perform public.sec_i_rl('score_burst', 12, 60);
  perform public.sec_i_rl('score_day', 400, 86400);
  new.score := greatest(0, least(new.score, 100000));
  new.game_name := left(new.game_name, 60);
  new.created_at := now();
  select coalesce(sum(score), 0) into day_total from public.game_scores
   where user_id = new.user_id and created_at > now() - interval '24 hours';
  if day_total + new.score > 300000 then raise exception 'Daily points limit reached' using errcode = '54000'; end if;
  return new;
end $$;
drop trigger if exists aa_scores_sec on public.game_scores;
create trigger aa_scores_sec before insert on public.game_scores
  for each row execute function public.sec_scores_guard();
revoke update, delete on public.game_scores from anon, authenticated;

create or replace function public.sec_playlog_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if public.sec_client() and abs(new.play_date - (now() at time zone 'utc')::date) > 1 then
    raise exception 'Invalid play date' using errcode = '22023';
  end if;
  return new;
end $$;
drop trigger if exists aa_playlog_sec on public.daily_play_log;
create trigger aa_playlog_sec before insert on public.daily_play_log
  for each row execute function public.sec_playlog_guard();

create or replace function public.sec_freeze_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not public.sec_client() then return new; end if;
  if tg_op = 'INSERT' then
    if new.user_id is distinct from auth.uid() then raise exception 'permission denied' using errcode = '42501'; end if;
    if exists (select 1 from public.streak_freezes f where f.user_id = new.user_id
               and date_trunc('month', f.granted_at) = date_trunc('month', now())) then
      raise exception 'Streak freeze already granted this month' using errcode = '54000';
    end if;
    new.granted_at := now(); new.used_at := null; new.used_for_date := null;
  else
    new.user_id := old.user_id; new.granted_at := old.granted_at;
    if old.used_at is not null then new.used_at := old.used_at; new.used_for_date := old.used_for_date; end if;
    if new.used_for_date is not null and (new.used_for_date > current_date or new.used_for_date < current_date - 7) then
      raise exception 'Invalid freeze date' using errcode = '22023';
    end if;
  end if;
  return new;
end $$;
drop trigger if exists aa_freeze_sec on public.streak_freezes;
create trigger aa_freeze_sec before insert or update on public.streak_freezes
  for each row execute function public.sec_freeze_guard();
revoke delete on public.streak_freezes from anon, authenticated;

create or replace function public.sec_lqp_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not public.sec_client() then return new; end if;
  new.best_stars := greatest(0, least(new.best_stars, 3));
  if tg_op = 'INSERT' then new.plays := least(greatest(new.plays, 1), 1);
  else
    new.best_stars := greatest(new.best_stars, old.best_stars);
    new.plays := least(greatest(new.plays, old.plays), old.plays + 1);
  end if;
  return new;
end $$;
drop trigger if exists aa_lqp_sec on public.life_quest_progress;
create trigger aa_lqp_sec before insert or update on public.life_quest_progress
  for each row execute function public.sec_lqp_guard();

-- -----------------------------------------------------------------------------
-- 8. Legacy RPCs with a user-id parameter (IDOR)  [SEC-15 .. SEC-17]
-- -----------------------------------------------------------------------------
drop function if exists public.get_user_id_by_email(text);
create function public.get_user_id_by_email(email text)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare result_id uuid;
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  perform public.sec_rl('uid_by_email', 30, 60);
  select u.id into result_id from auth.users u where lower(u.email) = lower(get_user_id_by_email.email) limit 1;
  return result_id;
end $$;

create or replace function public.increment_posts_count(user_id uuid)
returns void language sql security definer set search_path = public, pg_temp as $$
  update public.profiles p
     set posts_count = (select count(*) from public.posts x where x.author_id = p.id and not coalesce(x.is_deleted, false))
   where p.id = increment_posts_count.user_id and p.id = auth.uid();
$$;

create or replace function public.get_direct_chats_for_user(uid uuid)
returns table(chat_id uuid, other_user_id uuid)
language sql stable security definer set search_path = public, pg_temp as $$
  select cm1.chat_id, cm2.user_id
  from public.chat_members cm1
  join public.chat_members cm2 on cm1.chat_id = cm2.chat_id and cm2.user_id <> cm1.user_id
  join public.chats c on c.id = cm1.chat_id and c.type = 'direct'
  where cm1.user_id = auth.uid() and uid = auth.uid();
$$;

create or replace function public.my_mission_code(p_user uuid default auth.uid())
returns text language sql stable security definer set search_path = public, pg_temp as $$
  select 'GAC-' || upper(substr(md5(auth.uid()::text || coalesce((select id::text from public.mission_seasons where is_active limit 1), '')), 1, 4));
$$;

-- Client-callable wrapper so the Arena can debit its OWN wallet (the raw deduct/refund are server-only).
create or replace function public.arena_deduct_my_stake(p_amount integer, p_reference text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_amount is null or p_amount <= 0 or p_amount > 1000000 then return jsonb_build_object('success', false, 'error', 'Invalid amount'); end if;
  perform pg_advisory_xact_lock(hashtextextended('gacom:wallet:' || auth.uid()::text, 0));
  perform public.sec_rl('arena_stake', 30, 60);
  return public.deduct_arena_stake(auth.uid(), p_amount, 'ARENA_' || left(coalesce(p_reference, ''), 60) || '_' || auth.uid()::text);
end $$;

-- -----------------------------------------------------------------------------
-- 9. Institutions: stop publishing every institution's login password  [SEC-18]
-- -----------------------------------------------------------------------------
do $$
begin
  if to_regclass('public.institutions') is not null
     and exists (select 1 from information_schema.columns where table_schema = 'public' and table_name = 'institutions' and column_name = 'login_code') then
    create table if not exists public.institution_secrets (
      institution_id uuid primary key references public.institutions(id) on delete cascade,
      login_code text, updated_at timestamptz not null default now());
    -- the BEFORE INSERT guard on institutions writes the secret before the institution row exists
    alter table public.institution_secrets alter constraint institution_secrets_institution_id_fkey deferrable initially deferred;
    alter table public.institution_secrets enable row level security;
    revoke all on public.institution_secrets from anon, authenticated;
    grant select on public.institution_secrets to authenticated;
    drop policy if exists "inst secrets admin" on public.institution_secrets;
    create policy "inst secrets admin" on public.institution_secrets for select to authenticated using (public.sec_is_admin());
    insert into public.institution_secrets (institution_id, login_code)
      select id, login_code from public.institutions where login_code is not null
      on conflict (institution_id) do update set login_code = excluded.login_code, updated_at = now();
    update public.institutions set login_code = null where login_code is not null;
  end if;
end $$;

create or replace function public.sec_inst_guard()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare n jsonb := to_jsonb(new); admin boolean := public.sec_is_admin() or auth.uid() is null;
begin
  if n ? 'login_code' and (n ->> 'login_code') is not null and to_regclass('public.institution_secrets') is not null then
    insert into public.institution_secrets (institution_id, login_code) values (new.id, n ->> 'login_code')
      on conflict (institution_id) do update set login_code = excluded.login_code, updated_at = now();
    n := jsonb_set(n, '{login_code}', 'null'::jsonb);
  end if;
  if not admin and tg_op = 'INSERT' then
    if n ? 'login_email' then n := jsonb_set(n, '{login_email}', 'null'::jsonb); end if;
    if n ? 'ai_calls_used' then n := jsonb_set(n, '{ai_calls_used}', '0'::jsonb); end if;
    if n ? 'ai_calls_limit' then n := jsonb_set(n, '{ai_calls_limit}', to_jsonb(least(coalesce((n ->> 'ai_calls_limit')::int, 100), 100))); end if;
    if n ? 'created_by' then n := jsonb_set(n, '{created_by}', to_jsonb(auth.uid())); end if;
  end if;
  new := jsonb_populate_record(new, n);
  return new;
end $$;
do $$ begin
  if to_regclass('public.institutions') is not null then
    drop trigger if exists aa_inst_sec on public.institutions;
    create trigger aa_inst_sec before insert or update on public.institutions
      for each row execute function public.sec_inst_guard();
    revoke select on public.institutions from anon;
  end if;
end $$;
create or replace function public.admin_institution_codes()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  return coalesce((select jsonb_object_agg(institution_id::text, login_code) from public.institution_secrets), '{}'::jsonb);
end $$;

-- Institution list stays readable to anonymous sign-up screens, minus credentials.
do $$
declare cols text;
begin
  if to_regclass('public.institutions') is not null then
    select string_agg(quote_ident(column_name), ', ') into cols from information_schema.columns
     where table_schema = 'public' and table_name = 'institutions' and column_name not in ('login_code', 'login_email');
    execute format('grant select (%s) on public.institutions to anon', cols);
  end if;
end $$;

-- Secrets exposed to anonymous visitors through broad SELECT policies (tournament rooms).
do $$
declare t record; cols text;
begin
  for t in select * from (values ('tournament_matches', array['room_id_assigned', 'room_password_assigned']),
                                 ('game_rooms', array['room_code', 'room_password'])) v(tbl, hidden) loop
    if to_regclass('public.' || t.tbl) is not null then
      select string_agg(quote_ident(column_name), ', ') into cols from information_schema.columns
       where table_schema = 'public' and table_name = t.tbl and column_name <> all (t.hidden);
      execute format('revoke select on public.%I from anon', t.tbl);
      execute format('grant select (%s) on public.%I to anon', cols, t.tbl);
    end if;
  end loop;
end $$;

-- Room credentials for a match, only to its players and tournament staff.
create or replace function public.get_match_room(p_match uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare m record;
begin
  select * into m from public.tournament_matches where id = p_match;
  if not found then return null; end if;
  if not (auth.uid() in (m.player1_id, m.player2_id) or public.sec_is_admin()
          or exists (select 1 from public.exco_assignments e where e.exco_id = auth.uid())) then
    raise exception 'Not your match' using errcode = '42501';
  end if;
  return jsonb_build_object('room_id', m.room_id_assigned, 'room_password', m.room_password_assigned);
end $$;

-- -----------------------------------------------------------------------------
-- 10. Rate limits and per-user serialisation inside existing RPCs  [SEC-19, SEC-20]
-- -----------------------------------------------------------------------------
do $$
declare w text := $q$perform pg_advisory_xact_lock(hashtextextended('gacom:wallet:' || coalesce(auth.uid()::text, ''), 0)); perform public.sec_rl('wallet_op', 30, 60);$q$;
        f text; n integer;
begin
  foreach f in array array['purchase_cosmetic', 'purchase_bundle', 'purchase_house_item', 'found_house', 'duel_join', 'duel_quick'] loop
    n := public.sec_patch_fn(f, w);
    raise notice 'sec_patch % -> %', f, n;
  end loop;
  perform public.sec_patch_fn('found_house', $q$perform public.sec_rl('found_house', 3, 3600);$q$);
  perform public.sec_patch_fn('darkom_challenge', $q$perform public.sec_rl('dk_challenge', 10, 60);$q$);
  perform public.sec_patch_fn('darkom_respond_challenge', $q$perform public.sec_rl('dk_respond', 30, 60);$q$);
  perform public.sec_patch_fn('darkom_report_user', $q$perform public.sec_rl('dk_report', 10, 300);$q$);
  perform public.sec_patch_fn('darkom_report_run', $q$perform public.sec_rl('dk_run', 20, 60);$q$);
  perform public.sec_patch_fn('darkom_report_squad_match', $q$perform public.sec_rl('dk_squad_match', 20, 60);$q$);
  perform public.sec_patch_fn('darkom_report_duel', $q$perform public.sec_rl('dk_duel', 20, 60);$q$);
  perform public.sec_patch_fn('darkom_create_squad', $q$perform public.sec_rl('dk_squad_new', 5, 60);$q$);
  perform public.sec_patch_fn('darkom_join_squad', $q$perform public.sec_rl('dk_squad_join', 20, 60);$q$);
  perform public.sec_patch_fn('darkom_block_user', $q$perform public.sec_rl('dk_block', 30, 60);$q$);
  perform public.sec_patch_fn('journey_report_run', $q$perform public.sec_rl('journey_run', 30, 60);$q$);
  perform public.sec_patch_fn('request_join_house', $q$perform public.sec_rl('house_req', 20, 3600);$q$);
  perform public.sec_patch_fn('join_house', $q$perform public.sec_rl('house_join', 20, 3600);$q$);
  perform public.sec_patch_fn('equip_cosmetic', $q$perform public.sec_rl('equip', 60, 60);$q$);
  -- prize caps are checked-then-inserted: serialise per mission, and cap code-word guessing
  perform public.sec_patch_fn('submit_mission',
    $q$perform pg_advisory_xact_lock(hashtextextended('mission:' || p_mission_id::text, 0)); perform public.sec_rl('mission_submit:' || p_mission_id::text, 6, 3600);$q$);
  perform public.sec_patch_fn('claim_mission',
    $q$perform pg_advisory_xact_lock(hashtextextended('mission:' || p_mission_id::text, 0)); perform public.sec_rl('mission_claim', 30, 60);$q$);
  perform public.sec_patch_fn('claim_collection_milestone',
    $q$perform pg_advisory_xact_lock(hashtextextended('gacom:wallet:' || coalesce(auth.uid()::text, ''), 0));$q$);
  -- withdrawal approval RPCs exist in production only: make sure they refuse non-staff
  perform public.sec_patch_fn('approve_withdrawal',
    $q$if not (public.sec_is_admin() or exists (select 1 from public.exco_assignments x where x.exco_id = auth.uid() and x.exco_role = 'finance_team')) then raise exception 'Not allowed' using errcode = '42501'; end if;$q$);
  perform public.sec_patch_fn('reject_withdrawal',
    $q$if not (public.sec_is_admin() or exists (select 1 from public.exco_assignments x where x.exco_id = auth.uid() and x.exco_role = 'finance_team')) then raise exception 'Not allowed' using errcode = '42501'; end if;$q$);
end $$;
drop function if exists public.sec_patch_fn(text, text);

-- -----------------------------------------------------------------------------
-- 11. Storage  [SEC-21]
-- -----------------------------------------------------------------------------
do $$
declare r record; managed text[] := array['avatars', 'post-media', 'product-images', 'blog-images', 'community-banners'];
begin
  if to_regclass('storage.objects') is null or to_regclass('storage.buckets') is null then return; end if;
  -- identity / KYC style buckets are never public
  update storage.buckets set public = false
   where name ~* '(kyc|verif|identity|passport|document|receipt|invoice|clip|attachment)';
  -- limits on the public media buckets
  update storage.buckets set file_size_limit = 5242880,  allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp', 'image/gif']
   where name in ('avatars', 'blog-images', 'community-banners', 'product-images') and file_size_limit is null;
  update storage.buckets set file_size_limit = 52428800, allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp', 'image/gif', 'video/mp4', 'video/quicktime', 'video/webm']
   where name = 'post-media' and file_size_limit is null;
  -- drop any policy that is global (names no bucket) or targets a managed bucket; recreate below
  for r in select policyname from pg_policies where schemaname = 'storage' and tablename = 'objects'
           and policyname not in ('mission clips upload', 'mission clips read', 'support attachments upload', 'support attachments read')
           and (coalesce(qual, '') || coalesce(with_check, '') !~ 'bucket_id'
                or coalesce(qual, '') || coalesce(with_check, '') ~ ('(' || array_to_string(managed, '|') || ')'))
  loop
    execute format('drop policy %I on storage.objects', r.policyname);
  end loop;
  -- public read stays via bucket.public; writes are owner-folder only
  create policy "sec media insert own folder" on storage.objects for insert to authenticated
    with check (bucket_id in ('avatars', 'post-media', 'product-images', 'blog-images', 'community-banners')
                and (storage.foldername(name))[1] = auth.uid()::text);
  create policy "sec media update own folder" on storage.objects for update to authenticated
    using (bucket_id in ('avatars', 'post-media', 'product-images', 'blog-images', 'community-banners')
           and (storage.foldername(name))[1] = auth.uid()::text)
    with check (bucket_id in ('avatars', 'post-media', 'product-images', 'blog-images', 'community-banners')
                and (storage.foldername(name))[1] = auth.uid()::text);
  create policy "sec media delete own folder" on storage.objects for delete to authenticated
    using (bucket_id in ('avatars', 'post-media', 'product-images', 'blog-images', 'community-banners')
           and ((storage.foldername(name))[1] = auth.uid()::text or public.sec_is_admin()));
exception when others then raise notice 'storage hardening partially skipped: %', sqlerrm;
end $$;
-- -----------------------------------------------------------------------------
-- 12. Realtime: stop broadcasting private rows  [SEC-22]
-- -----------------------------------------------------------------------------
do $$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['profiles', 'tournament_matches', 'match_results', 'exco_assignments'] loop
      if exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
        execute format('alter publication supabase_realtime drop table public.%I', t);
      end if;
    end loop;
  end if;
end $$;

-- -----------------------------------------------------------------------------
-- 13. Table privileges (defence in depth beneath RLS)  [SEC-23]
-- -----------------------------------------------------------------------------
do $$
declare r record;
begin
  for r in select c.oid::regclass as t from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p') loop
    execute format('revoke truncate, references, trigger on %s from anon, authenticated', r.t);
    execute format('revoke insert, update, delete on %s from anon', r.t);
  end loop;
  grant insert on public.error_logs to anon;
  revoke all on all sequences in schema public from anon;
end $$;
do $$ begin
  alter default privileges in schema public revoke truncate, references, trigger on tables from anon, authenticated;
  alter default privileges in schema public revoke insert, update, delete on tables from anon;
  alter default privileges in schema public revoke all on sequences from anon;
  alter default privileges revoke execute on functions from public;
  alter default privileges in schema public revoke execute on functions from public, anon, authenticated;
end $$;
do $$ begin
  alter default privileges for role postgres in schema public revoke execute on functions from public, anon, authenticated;
exception when others then raise notice 'default privileges (postgres) skipped: %', sqlerrm; end $$;
do $$ begin
  alter default privileges for role supabase_admin in schema public revoke execute on functions from public, anon, authenticated;
exception when others then raise notice 'default privileges (supabase_admin) skipped: %', sqlerrm; end $$;

-- -----------------------------------------------------------------------------
-- 14. EXECUTE grants  [SEC-24]
--     anon: nothing (except policy helpers). authenticated: unchanged unless internal. Internal helpers: nobody but service_role / definer callers.
--     Functions referenced by RLS policies keep the grant their policies need.
-- -----------------------------------------------------------------------------
do $$
declare
  r record;
  internal text[] := array[
    'grant_cosmetic','revoke_cosmetic','grant_trophy','grant_set_bonuses','grant_track_rewards','evaluate_trophies',
    'identity_notify','apply_mission_reward','apple_apply_transaction','award_house_week','rotate_daily_deals',
    'rotate_featured','rotate_shop','darkom_award','darkom_close_stale_squads','darkom_refresh_squad_arrays',
    'darkom_squad_json','darkom_clean_text','darkom_mute_minutes','darkom_name','duel_resolve','duel_settle',
    'security_log','security_scan','security_posture','support_mark_breaches','deduct_arena_stake','refund_arena_stake',
    'credit_wallet_from_reference','mission_metric_value','cosmetic_json','cosmetic_is_pro','cosmetic_effective_price',
    'journey_zone_open','journey_zone_stars','house_role_of','darkom_blocked_either','mission_window','mission_winners_left',
    'house_goal_progress','house_goal_template_for','house_week_points','sec_rl','sec_patch_fn','sec_inst_guard'];
  anon_ok text[] := array['house_leaderboard','get_house_top_members','get_house_goal','get_competition_standings'];
  pol_auth oid[]; pol_anon oid[];
begin
  select array_agg(distinct d.refobjid) into pol_auth
    from pg_depend d join pg_policy po on d.classid = 'pg_policy'::regclass and d.objid = po.oid
   where d.refclassid = 'pg_proc'::regclass;
  select array_agg(distinct d.refobjid) into pol_anon
    from pg_depend d join pg_policy po on d.classid = 'pg_policy'::regclass and d.objid = po.oid
   where d.refclassid = 'pg_proc'::regclass and (po.polroles = '{0}' or po.polroles @> array['anon'::regrole::oid]);

  for r in select p.oid, p.oid::regprocedure as sig, p.proname, p.prorettype, p.prokind
           from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prokind in ('f', 'p')
           and not exists (select 1 from pg_depend d where d.classid = 'pg_proc'::regclass and d.objid = p.oid and d.deptype = 'e') loop
    execute format('revoke all on function %s from public, anon', r.sig);
    if r.prorettype = 'trigger'::regtype then
      execute format('revoke all on function %s from authenticated', r.sig);
    elsif r.proname = any (internal) and r.oid <> all (coalesce(pol_auth, '{}')) then
      execute format('revoke all on function %s from authenticated', r.sig);
      execute format('grant execute on function %s to service_role', r.sig);
    elsif r.proname ~ '^(sec_|admin_set_|admin_institution_codes|my_wallet|get_match_room|arena_deduct_my_stake|join_paid_competition|get_user_id_by_email|increment_posts_count|get_direct_chats_for_user|my_mission_code)'
          and r.proname not in ('sec_rl', 'sec_patch_fn') then
      execute format('grant execute on function %s to authenticated, service_role', r.sig);
    end if;      -- everything else keeps the authenticated grant it already has (migrations 18/19 revoked theirs on purpose)
    if r.proname = any (anon_ok) or r.oid = any (coalesce(pol_anon, '{}')) or r.proname in ('sec_client', 'sec_is_admin', 'sec_i_rl') then
      execute format('grant execute on function %s to anon', r.sig);
    end if;
  end loop;
end $$;
-- the pre-existing security / support helpers keep their own stricter grants from 18 and 19
do $$ begin
  revoke all on function public.security_log(text, text, uuid, uuid, jsonb, text, text, text) from public, anon, authenticated;
  grant execute on function public.security_log(text, text, uuid, uuid, jsonb, text, text, text) to service_role;
exception when undefined_function then null; end $$;

-- Report (not auto-fix: unknown prod tables may rely on being open) any table still without RLS.
do $$
declare r record;
begin
  for r in select c.relname from pg_class c where c.relnamespace = 'public'::regnamespace and c.relkind in ('r', 'p') and not c.relrowsecurity loop
    raise warning 'SECURITY: public.% has RLS disabled', r.relname;
  end loop;
end $$;

notify pgrst, 'reload schema';
