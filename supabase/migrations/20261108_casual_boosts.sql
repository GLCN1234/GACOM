-- Casual boosts.
--
-- Small, time-limited boosts to COSMETIC PROGRESSION only: Season Pass XP and
-- skin evolution XP. They are bought with wallet money like any shop item and
-- kept in an inventory until the player switches one on. They are applied on
-- the server, in the two functions that award that XP, so the app cannot fake
-- or skip them.
--
-- Fairness rules, enforced here and not only in the app:
--   * A boost never changes a score, points, rank, stake, prize, win or any
--     combat or game stat. It only scales how fast the Season Pass and skin
--     evolution fill, and nothing else reads those numbers for ranking.
--   * So it cannot touch duels, stake matches, competitions or ranked boards:
--     those never read pass or evolution XP. boost_allowed() also says no for
--     those contexts, for any future feature that asks.
--   * One boost on at a time, at most 25 percent, at most 60 minutes, at most 3
--     switched on per day, at most 10 held per type. The Season Pass daily XP
--     cap still applies after the boost.
-- Run after 20261031 (season pass) and 20261011 (wallet shop).

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table if not exists public.boost_items (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text not null default '',
  kind text not null check (kind in ('pass_xp', 'skin_xp')),
  pct integer not null check (pct between 1 and 25),
  minutes integer not null check (minutes between 5 and 60),
  price integer not null check (price > 0),
  is_active boolean not null default true,
  sort_order integer not null default 0
);

create table if not exists public.user_boosts (
  user_id uuid not null references auth.users(id) on delete cascade,
  boost_id uuid not null references public.boost_items(id) on delete cascade,
  qty integer not null default 0 check (qty between 0 and 10),
  primary key (user_id, boost_id)
);

create table if not exists public.boost_active (
  user_id uuid primary key references auth.users(id) on delete cascade,
  boost_id uuid not null references public.boost_items(id),
  kind text not null,
  pct integer not null,
  started_at timestamptz not null default now(),
  ends_at timestamptz not null
);

create table if not exists public.boost_log (
  id bigserial primary key,
  user_id uuid not null references auth.users(id) on delete cascade,
  boost_id uuid not null references public.boost_items(id),
  activated_at timestamptz not null default now()
);
create index if not exists boost_log_user_day on public.boost_log (user_id, activated_at desc);

alter table public.boost_items enable row level security;
alter table public.user_boosts enable row level security;
alter table public.boost_active enable row level security;
alter table public.boost_log enable row level security;

drop policy if exists "boost items readable" on public.boost_items;
create policy "boost items readable" on public.boost_items for select using (is_active);
drop policy if exists "own boosts readable" on public.user_boosts;
create policy "own boosts readable" on public.user_boosts for select using (auth.uid() = user_id);
drop policy if exists "own active boost readable" on public.boost_active;
create policy "own active boost readable" on public.boost_active for select using (auth.uid() = user_id);
drop policy if exists "own boost log readable" on public.boost_log;
create policy "own boost log readable" on public.boost_log for select using (auth.uid() = user_id);
-- No insert, update or delete policies: every change goes through the functions below.

-- ---------------------------------------------------------------------------
-- Catalogue (prices are in the same wallet currency as the cosmetic shop)
-- ---------------------------------------------------------------------------
insert into public.boost_items (key, name, description, kind, pct, minutes, price, sort_order) values
  ('pass_xp_20_30', 'Pass Surge',    '+20% Season Pass XP for 30 minutes. Your daily pass cap still applies.', 'pass_xp', 20, 30, 150, 1),
  ('pass_xp_25_60', 'Pass Surge+',   '+25% Season Pass XP for 60 minutes. Your daily pass cap still applies.', 'pass_xp', 25, 60, 250, 2),
  ('skin_xp_20_30', 'Forge Spark',   '+20% evolution XP for your equipped evolving skins, for 30 minutes.',    'skin_xp', 20, 30, 120, 3),
  ('skin_xp_25_60', 'Forge Spark+',  '+25% evolution XP for your equipped evolving skins, for 60 minutes.',    'skin_xp', 25, 60, 200, 4)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- Rules
-- ---------------------------------------------------------------------------

-- Where a boost may count. Anything with a rank, a stake or a prize says no.
create or replace function public.boost_allowed(p_context text)
returns boolean language sql immutable as $$
  select lower(coalesce(p_context, '')) in ('casual', 'free_play', 'pass', 'practice');
$$;
grant execute on function public.boost_allowed(text) to authenticated;

-- The multiplier a player has right now for one kind (1 when nothing is on).
create or replace function public.boost_multiplier(p_user uuid, p_kind text)
returns numeric language sql stable security definer set search_path = public as $$
  select coalesce(
    (select 1 + least(a.pct, 25) / 100.0
       from public.boost_active a
      where a.user_id = p_user and a.kind = p_kind and a.ends_at > now()),
    1.0);
$$;
revoke all on function public.boost_multiplier(uuid, text) from public, anon, authenticated;

-- Season Pass XP: the boost scales the amount before the existing caps.
create or replace function public.pass_add_xp(p_user uuid, p_amount integer)
returns void language plpgsql security definer set search_path = public as $$
declare
  s public.pass_seasons;
  today date := (now() at time zone 'utc')::date;
  pr public.pass_progress;
  add_xp integer;
  base integer;
begin
  if p_user is null or coalesce(p_amount, 0) <= 0 then return; end if;
  s := public.pass_active();
  if s.id is null then return; end if;
  base := ceil(p_amount * public.boost_multiplier(p_user, 'pass_xp'))::integer;
  insert into public.pass_progress (user_id, season_id) values (p_user, s.id) on conflict do nothing;
  select * into pr from public.pass_progress where user_id = p_user and season_id = s.id for update;
  if pr.xp_day is distinct from today then pr.xp_day := today; pr.xp_today := 0; end if;
  add_xp := least(base, 400, greatest(0, s.daily_xp_cap - pr.xp_today));
  if add_xp <= 0 then return; end if;
  update public.pass_progress set
    xp = least(xp + add_xp, s.xp_per_level * s.max_level),
    xp_day = today,
    xp_today = pr.xp_today + add_xp,
    updated_at = now()
  where user_id = p_user and season_id = s.id;
end;
$$;
revoke all on function public.pass_add_xp(uuid, integer) from public, anon, authenticated;

-- Skin evolution XP: the boost scales the amount, then everything works as before.
create or replace function public.evo_add_xp(p_user uuid, p_amount integer)
returns void language plpgsql security definer set search_path = public as $$
declare
  uc record;
  slot_item uuid;
  ch text;
  newxp bigint;
  ev record;
  top_item uuid;
begin
  if p_amount is null or p_amount <= 0 then return; end if;
  p_amount := ceil(p_amount * public.boost_multiplier(p_user, 'skin_xp'))::integer;
  select equipped_weapon, equipped_hero_outfit into uc from public.user_cosmetics where user_id = p_user;
  if not found then return; end if;
  foreach slot_item in array array[uc.equipped_weapon, uc.equipped_hero_outfit] loop
    if slot_item is null then continue; end if;
    ch := null;
    select e.chain into ch from public.cosmetic_evolutions e where e.item_id = slot_item;
    if ch is null then continue; end if;
    insert into public.user_evolution_xp (user_id, chain, xp) values (p_user, ch, p_amount)
    on conflict (user_id, chain) do update set xp = public.user_evolution_xp.xp + p_amount, updated_at = now()
    returning xp into newxp;
    for ev in select * from public.cosmetic_evolutions where chain = ch and stage > 1 and xp_needed <= newxp order by stage loop
      if public.grant_cosmetic(p_user, ev.item_id, 'earned', 'evo:' || ch || ':' || ev.stage) then
        perform public.identity_notify(p_user, 'Your skin evolved',
          (select name from public.cosmetic_items where id = ev.item_id) || ' is unlocked and equipped.',
          jsonb_build_object('kind', 'evolution', 'chain', ch, 'stage', ev.stage));
      end if;
    end loop;
    top_item := null;
    select e.item_id into top_item from public.cosmetic_evolutions e
      where e.chain = ch and e.xp_needed <= newxp order by e.stage desc limit 1;
    if top_item is not null and top_item <> slot_item then
      update public.user_cosmetics set
        equipped_weapon = case when equipped_weapon = slot_item then top_item else equipped_weapon end,
        equipped_hero_outfit = case when equipped_hero_outfit = slot_item then top_item else equipped_hero_outfit end,
        updated_at = now()
      where user_id = p_user;
    end if;
  end loop;
end;
$$;
revoke all on function public.evo_add_xp(uuid, integer) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- What the app reads
-- ---------------------------------------------------------------------------
create or replace function public.boost_state()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  act public.boost_active;
  used integer;
  cat jsonb;
  bal numeric;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into act from public.boost_active where user_id = uid and ends_at > now();
  select count(*) into used from public.boost_log where user_id = uid and activated_at > now() - interval '24 hours';
  select coalesce(jsonb_agg(jsonb_build_object(
      'id', b.id, 'key', b.key, 'name', b.name, 'description', b.description, 'kind', b.kind,
      'pct', b.pct, 'minutes', b.minutes, 'price', b.price,
      'qty', coalesce(u.qty, 0)) order by b.sort_order), '[]'::jsonb)
    into cat
    from public.boost_items b
    left join public.user_boosts u on u.boost_id = b.id and u.user_id = uid
   where b.is_active;
  select wallet_balance into bal from public.profiles where id = uid;
  return jsonb_build_object(
    'success', true,
    'catalog', cat,
    'active', case when act.user_id is null then null else jsonb_build_object(
        'boost_id', act.boost_id, 'kind', act.kind, 'pct', act.pct, 'ends_at', act.ends_at,
        'name', (select name from public.boost_items where id = act.boost_id)) end,
    'used_today', used,
    'daily_cap', 3,
    'max_held', 10,
    'balance', bal);
end;
$$;
grant execute on function public.boost_state() to authenticated;

create or replace function public.buy_boost(p_boost_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  b public.boost_items;
  held integer;
  r jsonb;
  ref text;
  bal numeric;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into b from public.boost_items where id = p_boost_id and is_active;
  if not found then return jsonb_build_object('success', false, 'error', 'This boost is not available'); end if;
  select coalesce(qty, 0) into held from public.user_boosts where user_id = uid and boost_id = p_boost_id;
  if coalesce(held, 0) >= 10 then
    return jsonb_build_object('success', false, 'error', 'You can hold at most 10 of each boost');
  end if;
  ref := 'BOOST_' || p_boost_id::text || '_' || uid::text || '_' || extract(epoch from clock_timestamp())::text;
  r := public.deduct_arena_stake(uid, b.price, ref);
  if coalesce((r ->> 'success')::boolean, false) is not true then
    return jsonb_build_object('success', false, 'error', coalesce(r ->> 'error', 'Not enough balance'));
  end if;
  begin
    insert into public.user_boosts (user_id, boost_id, qty) values (uid, p_boost_id, 1)
    on conflict (user_id, boost_id) do update set qty = public.user_boosts.qty + 1;
  exception when others then
    perform public.refund_arena_stake(uid, b.price, 'BOOST_REFUND_' || ref);
    return jsonb_build_object('success', false, 'error', 'Could not complete the purchase, you were not charged');
  end;
  select wallet_balance into bal from public.profiles where id = uid;
  return jsonb_build_object('success', true, 'balance', bal);
end;
$$;
grant execute on function public.buy_boost(uuid) to authenticated;

create or replace function public.activate_boost(p_boost_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  b public.boost_items;
  used integer;
  ends timestamptz;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into b from public.boost_items where id = p_boost_id and is_active;
  if not found then return jsonb_build_object('success', false, 'error', 'This boost is not available'); end if;
  -- lock the player's boost state so two taps cannot both succeed
  perform 1 from public.user_boosts where user_id = uid and boost_id = p_boost_id for update;
  if not exists (select 1 from public.user_boosts where user_id = uid and boost_id = p_boost_id and qty > 0) then
    return jsonb_build_object('success', false, 'error', 'You do not have this boost');
  end if;
  if exists (select 1 from public.boost_active where user_id = uid and ends_at > now()) then
    return jsonb_build_object('success', false, 'error', 'A boost is already running. Wait for it to end.');
  end if;
  select count(*) into used from public.boost_log where user_id = uid and activated_at > now() - interval '24 hours';
  if used >= 3 then
    return jsonb_build_object('success', false, 'error', 'You can switch on 3 boosts every 24 hours');
  end if;
  ends := now() + make_interval(mins => b.minutes);
  update public.user_boosts set qty = qty - 1 where user_id = uid and boost_id = p_boost_id;
  delete from public.boost_active where user_id = uid;
  insert into public.boost_active (user_id, boost_id, kind, pct, ends_at) values (uid, b.id, b.kind, b.pct, ends);
  insert into public.boost_log (user_id, boost_id) values (uid, b.id);
  return jsonb_build_object('success', true, 'kind', b.kind, 'pct', b.pct, 'ends_at', ends);
end;
$$;
grant execute on function public.activate_boost(uuid) to authenticated;
