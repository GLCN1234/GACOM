-- Verified (blue tick) monthly subscription, and competition hosting for subscribers.
--
--   1. verification_subscriptions: pay from the wallet, 30 days per month, renew any time
--   2. is_competition_host(): active subscriber, or an admin
--   3. Hosting: a subscriber creates and runs their own competitions through functions.
--        - the prize pool is taken from the host's wallet up front and held in escrow
--        - paid entry fees stay locked on the players until the host settles or cancels
--        - settling pays winners from escrow, returns the rest, pays the host the entry
--          fees minus the platform fee (competitions.platform_fee_percent, default 10)
--        - cancel before the start refunds everyone; a host who never settles is
--          refunded automatically 7 days after the end time
--   4. Direct client inserts into competitions are refused for non-admins, so the old
--      open form can no longer bypass the subscription check.
-- Run after 20261020_security_hardening.sql.

-- ---------------------------------------------------------------------------
-- 1. Verification subscription
-- ---------------------------------------------------------------------------
create table if not exists public.verification_subscriptions (
  user_id uuid primary key references auth.users(id) on delete cascade,
  started_at timestamptz not null default now(),
  expires_at timestamptz not null,
  months_paid integer not null default 0,
  last_paid integer not null default 0,
  updated_at timestamptz not null default now()
);
alter table public.verification_subscriptions enable row level security;
drop policy if exists "own verification sub" on public.verification_subscriptions;
create policy "own verification sub" on public.verification_subscriptions for select using (user_id = auth.uid());
revoke insert, update, delete on public.verification_subscriptions from anon, authenticated;

-- Monthly price in naira. Change the number here to reprice.
create or replace function public.verification_price()
returns integer language sql immutable as $$ select 2000 $$;
grant execute on function public.verification_price() to authenticated, anon;

create or replace function public.verification_active(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.verification_subscriptions s where s.user_id = p_user and s.expires_at > now());
$$;

create or replace function public.is_competition_host(p_user uuid default auth.uid())
returns boolean language sql stable security definer set search_path = public as $$
  select p_user is not null and (
    public.verification_active(p_user)
    or exists (select 1 from public.profiles p where p.id = p_user and p.role::text in ('admin', 'super_admin'))
  );
$$;
grant execute on function public.is_competition_host(uuid) to authenticated;

-- State for the settings card and the host screens. Also drops the blue tick
-- when a subscription has run out.
create or replace function public.verification_state()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.verification_subscriptions;
  st text;
  active boolean := false;
begin
  if uid is null then return null; end if;
  select * into s from public.verification_subscriptions where user_id = uid;
  select verification_status::text into st from public.profiles where id = uid;
  if found then
    active := s.user_id is not null and s.expires_at > now();
    if s.user_id is not null and not active and st = 'verified' then
      update public.profiles set verification_status = 'unverified' where id = uid;
      st := 'unverified';
    end if;
  end if;
  return jsonb_build_object(
    'active', active,
    'expires_at', case when s.user_id is null then null else s.expires_at end,
    'days_left', case when active then ceil(extract(epoch from (s.expires_at - now())) / 86400.0)::int else 0 end,
    'status', st,
    'price', public.verification_price(),
    'host', public.is_competition_host(uid));
end;
$$;
grant execute on function public.verification_state() to authenticated;

create or replace function public.verification_subscribe(p_months integer default 1)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  months integer := greatest(1, least(coalesce(p_months, 1), 12));
  amount integer;
  r jsonb;
  ref text;
  base timestamptz;
  new_exp timestamptz;
  bal numeric;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  perform public.sec_rl('verify_sub', 6, 3600);
  if exists (select 1 from public.profiles where id = uid and is_banned is true) then
    return jsonb_build_object('success', false, 'error', 'This account cannot subscribe');
  end if;
  amount := public.verification_price() * months;
  ref := 'VERIFY_' || uid::text || '_' || floor(extract(epoch from clock_timestamp()) * 1000)::bigint::text;
  r := public.deduct_arena_stake(uid, amount, ref);
  if coalesce((r ->> 'success')::boolean, false) is not true then
    return jsonb_build_object('success', false, 'error', coalesce(r ->> 'error', 'Not enough balance. Please fund your wallet.'));
  end if;
  begin
    select greatest(now(), coalesce((select expires_at from public.verification_subscriptions where user_id = uid), now())) into base;
    new_exp := base + (months * 30) * interval '1 day';
    insert into public.verification_subscriptions (user_id, expires_at, months_paid, last_paid)
    values (uid, new_exp, months, amount)
    on conflict (user_id) do update
      set expires_at = new_exp,
          months_paid = public.verification_subscriptions.months_paid + months,
          last_paid = amount,
          updated_at = now();
    update public.profiles set verification_status = 'verified' where id = uid;
  exception when others then
    perform public.refund_arena_stake(uid, amount, ref || '_REFUND');
    return jsonb_build_object('success', false, 'error', 'Could not complete the subscription, you were not charged');
  end;
  select wallet_balance into bal from public.profiles where id = uid;
  return jsonb_build_object('success', true, 'expires_at', new_exp, 'paid', amount, 'balance', bal);
end;
$$;
grant execute on function public.verification_subscribe(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Hosting tables and columns
-- ---------------------------------------------------------------------------
alter table public.competitions add column if not exists hosted boolean not null default false;
alter table public.competitions add column if not exists prize_secured boolean not null default false;

create table if not exists public.competition_hosting (
  competition_id uuid primary key references public.competitions(id) on delete cascade,
  host_id uuid not null references auth.users(id) on delete cascade,
  prize_escrow integer not null default 0,
  prize_status text not null default 'held' check (prize_status in ('held', 'paid', 'refunded')),
  fee_status text not null default 'collecting' check (fee_status in ('collecting', 'settled', 'refunded')),
  entry_pool integer not null default 0,
  platform_cut integer not null default 0,
  host_net integer not null default 0,
  payout jsonb,
  settled_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists competition_hosting_host_idx on public.competition_hosting (host_id);
alter table public.competition_hosting enable row level security;
drop policy if exists "host sees own hosting" on public.competition_hosting;
create policy "host sees own hosting" on public.competition_hosting for select
  using (host_id = auth.uid() or public.sec_is_admin());
revoke insert, update, delete on public.competition_hosting from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Guards on the competitions table
-- ---------------------------------------------------------------------------
create or replace function public.sec_competitions_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not public.sec_client() or public.sec_is_admin() then return new; end if;
  if tg_op = 'INSERT' then
    raise exception 'Competitions are created by verified hosts from the Host screen' using errcode = '42501';
  end if;
  if new.prize_pool is distinct from old.prize_pool
     or new.entry_fee is distinct from old.entry_fee
     or new.competition_type is distinct from old.competition_type
     or new.status is distinct from old.status
     or new.winner_id is distinct from old.winner_id
     or new.winner_announced_at is distinct from old.winner_announced_at
     or new.created_by is distinct from old.created_by
     or new.is_admin_created is distinct from old.is_admin_created
     or new.platform_fee_percent is distinct from old.platform_fee_percent
     or new.max_participants is distinct from old.max_participants
     or new.starts_at is distinct from old.starts_at
     or new.ends_at is distinct from old.ends_at
     or new.hosted is distinct from old.hosted
     or new.prize_secured is distinct from old.prize_secured
     or new.is_featured is distinct from old.is_featured then
    raise exception 'permission denied: protected competition field' using errcode = '42501';
  end if;
  return new;
end $$;
drop trigger if exists aa_competitions_sec_guard on public.competitions;
create trigger aa_competitions_sec_guard before insert or update on public.competitions
  for each row execute function public.sec_competitions_guard();

-- A hosted competition that still holds money can never be deleted.
create or replace function public.sec_competitions_no_delete()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if old.hosted and exists (
    select 1 from public.competition_hosting h
     where h.competition_id = old.id and (h.prize_status = 'held' or h.fee_status = 'collecting')) then
    raise exception 'Cancel or settle this hosted competition before deleting it' using errcode = '42501';
  end if;
  return old;
end $$;
drop trigger if exists aa_competitions_no_delete on public.competitions;
create trigger aa_competitions_no_delete before delete on public.competitions
  for each row execute function public.sec_competitions_no_delete();

-- ---------------------------------------------------------------------------
-- 4. Create
-- ---------------------------------------------------------------------------
create or replace function public.host_create_competition(
  p_title text, p_game text, p_description text, p_rules text, p_banner_url text,
  p_platform text, p_region text, p_entry_fee integer, p_prize_pool integer, p_max integer,
  p_starts timestamptz, p_ends timestamptz, p_deadline timestamptz, p_tags text[],
  p_scope_type text default 'all', p_scope_country text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  t text := btrim(coalesce(p_title, ''));
  g text := btrim(coalesce(p_game, ''));
  fee integer := greatest(0, coalesce(p_entry_fee, 0));
  prize integer := greatest(0, coalesce(p_prize_pool, 0));
  mx integer := coalesce(p_max, 100);
  dl timestamptz := coalesce(p_deadline, p_starts);
  cid uuid := gen_random_uuid();
  active_n integer;
  r jsonb;
  ref text;
  bal numeric;
  tags text[];
  scope text := coalesce(nullif(p_scope_type, ''), 'all');
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if not public.is_competition_host(uid) then
    return jsonb_build_object('success', false, 'error', 'Hosting is for verified members. Subscribe to verification first.');
  end if;
  perform public.sec_rl('host_create', 6, 3600);

  if length(t) < 4 or length(t) > 80 then return jsonb_build_object('success', false, 'error', 'The title needs 4 to 80 characters'); end if;
  if length(g) < 2 or length(g) > 60 then return jsonb_build_object('success', false, 'error', 'Enter the game name'); end if;
  if length(coalesce(p_description, '')) > 1500 then return jsonb_build_object('success', false, 'error', 'The description is too long'); end if;
  if length(coalesce(p_rules, '')) > 3000 then return jsonb_build_object('success', false, 'error', 'The rules are too long'); end if;
  if p_banner_url is not null and p_banner_url <> '' and (p_banner_url !~ '^https://' or length(p_banner_url) > 500) then
    return jsonb_build_object('success', false, 'error', 'The banner must be an uploaded image');
  end if;
  if fee <> 0 and (fee < 100 or fee > 50000) then return jsonb_build_object('success', false, 'error', 'Entry fee is 0, or between N100 and N50,000'); end if;
  if prize > 500000 then return jsonb_build_object('success', false, 'error', 'The prize pool can be at most N500,000'); end if;
  if mx < 2 or mx > 1000 then return jsonb_build_object('success', false, 'error', 'Players must be between 2 and 1,000'); end if;
  if p_starts is null or p_ends is null then return jsonb_build_object('success', false, 'error', 'Pick a start and end time'); end if;
  if p_starts < now() + interval '1 hour' then return jsonb_build_object('success', false, 'error', 'Start at least 1 hour from now'); end if;
  if p_starts > now() + interval '90 days' then return jsonb_build_object('success', false, 'error', 'Start within the next 90 days'); end if;
  if p_ends <= p_starts or p_ends > p_starts + interval '30 days' then
    return jsonb_build_object('success', false, 'error', 'It must end after it starts, within 30 days');
  end if;
  if dl > p_starts then dl := p_starts; end if;
  if dl < now() then dl := p_starts; end if;
  if scope not in ('all', 'country') then scope := 'all'; end if;
  if scope = 'country' and coalesce(btrim(p_scope_country), '') = '' then
    return jsonb_build_object('success', false, 'error', 'Pick the country for a country-only competition');
  end if;

  select count(*) into active_n from public.competitions
   where created_by = uid and hosted and status::text in ('upcoming', 'live');
  if active_n >= 3 and not public.sec_is_admin() then
    return jsonb_build_object('success', false, 'error', 'You can run 3 competitions at a time. Finish one first.');
  end if;

  select coalesce(array_agg(x), '{}') into tags
    from (select left(btrim(v), 24) as x from unnest(coalesce(p_tags, '{}')) v where btrim(v) <> '' limit 6) q;

  ref := 'HOSTPRIZE_' || cid::text;
  if prize > 0 then
    r := public.deduct_arena_stake(uid, prize, ref);
    if coalesce((r ->> 'success')::boolean, false) is not true then
      return jsonb_build_object('success', false, 'error', coalesce(r ->> 'error', 'Not enough balance to fund the prize pool'));
    end if;
  end if;

  begin
    insert into public.competitions (
      id, title, description, game_name, banner_url, created_by, is_admin_created, competition_type,
      entry_fee, prize_pool, max_participants, status, rules, platform, region, starts_at, ends_at,
      registration_deadline, platform_fee_percent, tags, scope_type, scope_country, hosted, prize_secured)
    values (
      cid, t, nullif(btrim(coalesce(p_description, '')), ''), g, nullif(p_banner_url, ''), uid, false,
      (case when fee > 0 then 'paid' else 'free' end)::competition_type,
      fee, prize, mx, 'upcoming', nullif(btrim(coalesce(p_rules, '')), ''), nullif(btrim(coalesce(p_platform, '')), ''),
      nullif(btrim(coalesce(p_region, '')), ''), p_starts, p_ends, dl, 10, tags, scope,
      case when scope = 'country' then btrim(p_scope_country) else null end, true, prize > 0);
    insert into public.competition_hosting (competition_id, host_id, prize_escrow, prize_status)
    values (cid, uid, prize, case when prize > 0 then 'held' else 'paid' end);
  exception when others then
    if prize > 0 then perform public.refund_arena_stake(uid, prize, ref || '_REFUND'); end if;
    return jsonb_build_object('success', false, 'error', 'Could not create the competition, you were not charged');
  end;

  select wallet_balance into bal from public.profiles where id = uid;
  return jsonb_build_object('success', true, 'id', cid, 'balance', bal);
end;
$$;
grant execute on function public.host_create_competition(text, text, text, text, text, text, text, integer, integer, integer, timestamptz, timestamptz, timestamptz, text[], text, text) to authenticated;

-- Text-only edits, before the start.
create or replace function public.host_update_competition(
  p_id uuid, p_title text, p_description text, p_rules text, p_banner_url text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); c public.competitions; t text := btrim(coalesce(p_title, ''));
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into c from public.competitions where id = p_id;
  if not found or not c.hosted or (c.created_by <> uid and not public.sec_is_admin()) then
    return jsonb_build_object('success', false, 'error', 'Not your competition');
  end if;
  if c.status::text <> 'upcoming' then return jsonb_build_object('success', false, 'error', 'It has already started'); end if;
  if length(t) < 4 or length(t) > 80 then return jsonb_build_object('success', false, 'error', 'The title needs 4 to 80 characters'); end if;
  if length(coalesce(p_description, '')) > 1500 or length(coalesce(p_rules, '')) > 3000 then
    return jsonb_build_object('success', false, 'error', 'The text is too long');
  end if;
  if p_banner_url is not null and p_banner_url <> '' and (p_banner_url !~ '^https://' or length(p_banner_url) > 500) then
    return jsonb_build_object('success', false, 'error', 'The banner must be an uploaded image');
  end if;
  update public.competitions set title = t, description = nullif(btrim(coalesce(p_description, '')), ''),
         rules = nullif(btrim(coalesce(p_rules, '')), ''), banner_url = nullif(p_banner_url, '')
   where id = p_id;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.host_update_competition(uuid, text, text, text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Refund everything (cancel, force refund, host never settled)
-- ---------------------------------------------------------------------------
create or replace function public.comp_refund_all(p_comp uuid, p_reason text)
returns void language plpgsql security definer set search_path = public as $$
declare
  c public.competitions;
  h public.competition_hosting;
  pr record;
  fee numeric;
  bal numeric;
  r jsonb;
  has_h boolean := false;
begin
  select * into c from public.competitions where id = p_comp for update;
  if not found then return; end if;
  select * into h from public.competition_hosting where competition_id = p_comp for update;
  has_h := found;
  fee := coalesce(c.entry_fee, 0);

  if (not has_h or h.fee_status = 'collecting') and fee > 0 then
    for pr in select user_id from public.competition_participants
               where competition_id = p_comp and payment_status = 'paid' loop
      select wallet_balance into bal from public.profiles where id = pr.user_id for update;
      update public.profiles
         set wallet_locked_balance = greatest(0, coalesce(wallet_locked_balance, 0) - fee),
             wallet_balance = wallet_balance + fee
       where id = pr.user_id;
      insert into public.wallet_transactions (user_id, type, amount, balance_before, balance_after, status, description, reference)
      select pr.user_id, 'refund', fee, bal, bal + fee, 'success',
             'Refund: ' || left(coalesce(c.title, 'competition'), 80), 'COMPREFUND_' || p_comp::text || '_' || pr.user_id::text
       where not exists (select 1 from public.wallet_transactions wt
                          where wt.reference = 'COMPREFUND_' || p_comp::text || '_' || pr.user_id::text);
      update public.competition_participants set payment_status = 'refunded' where competition_id = p_comp and user_id = pr.user_id;
      perform public.identity_notify(pr.user_id, 'Entry fee refunded',
        left(coalesce(c.title, 'The competition'), 80) || ' was cancelled. Your entry fee is back in your wallet.',
        jsonb_build_object('kind', 'competition_refund', 'competition', p_comp));
    end loop;
  end if;

  if has_h and h.prize_status = 'held' and h.prize_escrow > 0 then
    r := public.refund_arena_stake(h.host_id, h.prize_escrow, 'HOSTPRIZE_REFUND_' || p_comp::text);
    if coalesce((r ->> 'success')::boolean, false) is not true then
      raise exception 'host refund failed';
    end if;
  end if;

  update public.competition_hosting
     set prize_status = case when prize_status = 'held' then 'refunded' else prize_status end,
         fee_status = 'refunded', settled_at = now(),
         payout = jsonb_build_object('refunded', true, 'reason', left(coalesce(p_reason, ''), 120))
   where competition_id = p_comp;
  update public.competitions set status = 'cancelled', prize_secured = false where id = p_comp;
end;
$$;
revoke all on function public.comp_refund_all(uuid, text) from public, anon, authenticated;

create or replace function public.host_cancel_competition(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); c public.competitions;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into c from public.competitions where id = p_id;
  if not found or not c.hosted then return jsonb_build_object('success', false, 'error', 'Competition not found'); end if;
  if c.created_by <> uid and not public.sec_is_admin() then return jsonb_build_object('success', false, 'error', 'Not your competition'); end if;
  if c.status::text in ('ended', 'cancelled') then return jsonb_build_object('success', false, 'error', 'It is already closed'); end if;
  if not public.sec_is_admin() and (c.status::text <> 'upcoming' or c.starts_at <= now()) then
    return jsonb_build_object('success', false, 'error', 'It has started. Settle it with the winners instead.');
  end if;
  perform public.comp_refund_all(p_id, case when public.sec_is_admin() then 'Cancelled by admin' else 'Cancelled by host' end);
  return jsonb_build_object('success', true);
exception when others then
  return jsonb_build_object('success', false, 'error', 'Could not cancel right now. Nothing was changed.');
end;
$$;
grant execute on function public.host_cancel_competition(uuid) to authenticated;

create or replace function public.admin_force_refund_competition(p_id uuid, p_reason text default 'Admin refund')
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  perform public.comp_refund_all(p_id, p_reason);
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.admin_force_refund_competition(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Settle: pay winners, return the rest, pay the host
-- ---------------------------------------------------------------------------
-- p_winners: [{"user_id": "...", "percent": 60}, ...] in finishing order. Percentages
-- add up to at most 100; whatever is not given out goes back to the host.
create or replace function public.host_finish_competition(p_id uuid, p_winners jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  c public.competitions;
  h public.competition_hosting;
  w jsonb;
  wid uuid;
  pct numeric;
  total_pct numeric := 0;
  place integer := 0;
  amt integer;
  paid_out integer := 0;
  leftover integer;
  pool integer := 0;
  cut integer;
  net integer;
  fee numeric;
  r jsonb;
  first_winner uuid;
  seen uuid[] := '{}';
  pr record;
  summary jsonb := '[]'::jsonb;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  perform public.sec_rl('host_finish', 10, 3600);
  select * into c from public.competitions where id = p_id for update;
  if not found or not c.hosted then return jsonb_build_object('success', false, 'error', 'Competition not found'); end if;
  if c.created_by <> uid and not public.sec_is_admin() then return jsonb_build_object('success', false, 'error', 'Not your competition'); end if;
  if c.status::text in ('ended', 'cancelled') then return jsonb_build_object('success', false, 'error', 'It is already closed'); end if;
  if c.starts_at > now() then return jsonb_build_object('success', false, 'error', 'It has not started yet. Cancel it instead if you want to call it off.'); end if;
  select * into h from public.competition_hosting where competition_id = p_id for update;
  if not found or (h.prize_status <> 'held' and h.prize_escrow > 0) or h.fee_status <> 'collecting' then
    return jsonb_build_object('success', false, 'error', 'This competition is already settled');
  end if;
  if jsonb_typeof(p_winners) <> 'array' or jsonb_array_length(p_winners) < 1 or jsonb_array_length(p_winners) > 10 then
    return jsonb_build_object('success', false, 'error', 'Pick between 1 and 10 winners');
  end if;

  -- validate first, pay second
  for w in select * from jsonb_array_elements(p_winners) loop
    begin
      wid := (w ->> 'user_id')::uuid;
      pct := coalesce((w ->> 'percent')::numeric, 0);
    exception when others then
      return jsonb_build_object('success', false, 'error', 'The winner list is not valid');
    end;
    if wid = any(seen) then return jsonb_build_object('success', false, 'error', 'A player appears twice'); end if;
    seen := seen || wid;
    if wid = c.created_by then return jsonb_build_object('success', false, 'error', 'The host cannot win their own competition'); end if;
    if not exists (select 1 from public.competition_participants where competition_id = p_id and user_id = wid) then
      return jsonb_build_object('success', false, 'error', 'Winners must be players who joined');
    end if;
    if pct < 0 or pct > 100 then return jsonb_build_object('success', false, 'error', 'Percentages must be between 0 and 100'); end if;
    total_pct := total_pct + pct;
  end loop;
  if total_pct > 100 then return jsonb_build_object('success', false, 'error', 'The percentages add up to more than 100'); end if;
  if h.prize_escrow > 0 and total_pct <= 0 then return jsonb_build_object('success', false, 'error', 'Give the winners a share of the prize'); end if;

  for w in select * from jsonb_array_elements(p_winners) loop
    place := place + 1;
    wid := (w ->> 'user_id')::uuid;
    pct := coalesce((w ->> 'percent')::numeric, 0);
    amt := floor(h.prize_escrow * pct / 100.0)::int;
    if place = 1 then first_winner := wid; end if;
    if amt > 0 then
      r := public.refund_arena_stake(wid, amt, 'HOSTWIN_' || p_id::text || '_' || wid::text);
      if coalesce((r ->> 'success')::boolean, false) is not true then raise exception 'winner payout failed'; end if;
      update public.profiles set total_winnings = coalesce(total_winnings, 0) + amt where id = wid;
      paid_out := paid_out + amt;
    end if;
    update public.competition_participants set rank = place where competition_id = p_id and user_id = wid;
    if place = 1 then update public.profiles set competitions_won = coalesce(competitions_won, 0) + 1 where id = wid; end if;
    perform public.identity_notify(wid, 'You placed ' || place || ' in ' || left(c.title, 60),
      case when amt > 0 then 'N' || amt || ' has been added to your wallet.' else 'Well played.' end,
      jsonb_build_object('kind', 'competition_win', 'competition', p_id, 'place', place));
    summary := summary || jsonb_build_object('user_id', wid, 'place', place, 'amount', amt);
  end loop;

  leftover := h.prize_escrow - paid_out;
  if leftover > 0 then
    r := public.refund_arena_stake(h.host_id, leftover, 'HOSTPRIZE_LEFT_' || p_id::text);
    if coalesce((r ->> 'success')::boolean, false) is not true then raise exception 'host return failed'; end if;
  end if;

  fee := coalesce(c.entry_fee, 0);
  if fee > 0 then
    for pr in select user_id from public.competition_participants where competition_id = p_id and payment_status = 'paid' loop
      update public.profiles set wallet_locked_balance = greatest(0, coalesce(wallet_locked_balance, 0) - fee) where id = pr.user_id;
      pool := pool + fee::int;
    end loop;
    cut := floor(pool * coalesce(c.platform_fee_percent, 10) / 100.0)::int;
    net := pool - cut;
    if net > 0 then
      r := public.refund_arena_stake(h.host_id, net, 'HOSTFEES_' || p_id::text);
      if coalesce((r ->> 'success')::boolean, false) is not true then raise exception 'host fee payout failed'; end if;
    end if;
  else
    cut := 0; net := 0;
  end if;

  update public.competition_hosting
     set prize_status = case when prize_escrow > 0 then 'paid' else prize_status end, fee_status = 'settled',
         entry_pool = pool, platform_cut = cut, host_net = net, settled_at = now(), payout = summary
   where competition_id = p_id;
  update public.competitions set status = 'ended', winner_id = first_winner, winner_announced_at = now() where id = p_id;
  return jsonb_build_object('success', true, 'paid_out', paid_out, 'returned', greatest(leftover, 0), 'entry_pool', pool, 'platform_cut', cut, 'host_net', net);
exception when others then
  return jsonb_build_object('success', false, 'error', 'Could not settle right now. Nothing was paid, try again.');
end;
$$;
grant execute on function public.host_finish_competition(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Sweep: a host who never settles is refunded 7 days after the end time
-- ---------------------------------------------------------------------------
create or replace function public.comp_sweep()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in
    select c.id from public.competitions c
      join public.competition_hosting h on h.competition_id = c.id
     where c.hosted and c.status::text in ('upcoming', 'live')
       and c.ends_at + interval '7 days' < now()
       and (h.prize_status = 'held' or h.fee_status = 'collecting')
     limit 10
  loop
    begin
      perform public.comp_refund_all(r.id, 'Host did not settle in time');
      n := n + 1;
    exception when others then null;
    end;
  end loop;
  return n;
end;
$$;
grant execute on function public.comp_sweep() to authenticated;

-- ---------------------------------------------------------------------------
-- 8. The host's own list
-- ---------------------------------------------------------------------------
create or replace function public.host_my_competitions()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); res jsonb;
begin
  if uid is null then return '[]'::jsonb; end if;
  perform public.comp_sweep();
  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.starts_at desc), '[]'::jsonb) into res from (
    select c.id, c.title, c.game_name, c.banner_url, c.status::text as status, c.starts_at, c.ends_at,
           c.entry_fee, c.prize_pool, c.max_participants, c.current_participants, c.platform_fee_percent,
           h.prize_status, h.fee_status, h.entry_pool, h.platform_cut, h.host_net, h.prize_escrow,
           (c.status::text = 'upcoming' and c.starts_at > now()) as can_cancel,
           (c.status::text in ('upcoming', 'live') and c.starts_at <= now()) as can_finish,
           (select count(*) from public.competition_participants p where p.competition_id = c.id) as players
      from public.competitions c join public.competition_hosting h on h.competition_id = c.id
     where c.created_by = uid and c.hosted
     order by c.starts_at desc limit 50
  ) t;
  return res;
end;
$$;
grant execute on function public.host_my_competitions() to authenticated;

-- Players of one hosted competition, for the winner picker.
create or replace function public.host_competition_players(p_id uuid)
returns table (user_id uuid, username text, display_name text, avatar_url text, payment_status text)
language plpgsql security definer set search_path = public as $$
begin
  if auth.uid() is null then return; end if;
  if not exists (select 1 from public.competitions c where c.id = p_id and (c.created_by = auth.uid() or public.sec_is_admin())) then return; end if;
  return query
    select p.user_id, pr.username::text, pr.display_name::text, pr.avatar_url::text, p.payment_status::text
      from public.competition_participants p join public.profiles pr on pr.id = p.user_id
     where p.competition_id = p_id and p.user_id <> auth.uid()
     order by p.registered_at
     limit 500;
end;
$$;
grant execute on function public.host_competition_players(uuid) to authenticated;

-- Banner images for hosted competitions
insert into storage.buckets (id, name, public) values ('competition-banners', 'competition-banners', true)
on conflict (id) do nothing;
drop policy if exists "comp banners read" on storage.objects;
create policy "comp banners read" on storage.objects for select using (bucket_id = 'competition-banners');
drop policy if exists "comp banners upload own" on storage.objects;
create policy "comp banners upload own" on storage.objects for insert to authenticated
  with check (bucket_id = 'competition-banners' and (storage.foldername(name))[1] = auth.uid()::text and public.is_competition_host(auth.uid()));
drop policy if exists "comp banners update own" on storage.objects;
create policy "comp banners update own" on storage.objects for update to authenticated
  using (bucket_id = 'competition-banners' and (storage.foldername(name))[1] = auth.uid()::text);
