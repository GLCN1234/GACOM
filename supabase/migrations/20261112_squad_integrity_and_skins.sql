-- Squad board integrity, plus contract skins for every weapon.
--
-- A phone-hosted game cannot be proven honest by the server, so the board is
-- protected in layers instead:
--   1. Time comes from the SERVER clock (when the squad started to when each
--      player reports). A phone cannot claim a faster time than really passed.
--   2. Each contract has a minimum possible time. Anything faster is refused,
--      with no reward and no board entry.
--   3. A team time counts only when at least 2 teammates reported, and it is the
--      UPPER MEDIAN of their times, so one cheater cannot pull it down.
--   4. Block Sweep also needs the teammates' own kill counts to add up to the target.
--   5. Admins can remove a squad from the board (darkom_admin_coop_flag).
-- Colluding squads that all cheat and wait out the minimum can still tie the
-- minimum. For prizes, runs would need to be replayed on a server.

alter table public.darkom_coop_rewards add column if not exists elapsed integer;
alter table public.darkom_coop_rewards add column if not exists kills integer not null default 0;

create table if not exists public.darkom_coop_flags (
  squad_id uuid primary key references public.darkom_squads(id) on delete cascade,
  reason text not null default '',
  flagged_by uuid,
  created_at timestamptz not null default now()
);
alter table public.darkom_coop_flags enable row level security;

-- The old per-squad table trusted the first report. The board is now computed
-- from every player's server-timed report instead.
drop table if exists public.darkom_coop_runs;

-- ---------------------------------------------------------------------------
-- Contract skins for all six weapons. The first two were sword only.
-- ---------------------------------------------------------------------------
update public.cosmetic_items set name = 'Squad Steel Sword', earn_hint = 'Clear 6 Squad Contracts (you get the skin for all six weapons)'
  where category = 'weapon_skin' and name = 'Squad Steel';
update public.cosmetic_items set name = 'Bounty Brass Sword', earn_hint = 'Clear 15 Squad Contracts (you get the skin for all six weapons)'
  where category = 'weapon_skin' and name = 'Bounty Brass';

insert into public.cosmetic_items
  (category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
select 'weapon_skin', set_name || ' ' || initcap(w), w,
  jsonb_build_object('weapon', w, 'metal', metal, 'hi', hi, 'ex', ex, 'w', wood, 'glow', glow),
  0, rarity, false, 'user', descr, base_sort + idx, 'earned', hint
from (values
  ('Squad Steel', 'epic', 940, 'Cold blue steel with a green edge.', 'Clear 6 Squad Contracts (you get the skin for all six weapons)', '#9FB4CC', '#E8F4FF', '#3A5A7A', '#1B2433', '#69F0AE'),
  ('Bounty Brass', 'legendary', 960, 'Brass fit for a bounty crew.', 'Clear 15 Squad Contracts (you get the skin for all six weapons)', '#C9A24B', '#FFF3C4', '#6B4A12', '#2B1D08', '#FFD54F')
) as s(set_name, rarity, base_sort, descr, hint, metal, hi, ex, wood, glow)
cross join (values ('sword', 0), ('dagger', 1), ('hammer', 2), ('axe', 3), ('staff', 4), ('shield', 5)) as wp(w, idx)
where not exists (
  select 1 from public.cosmetic_items c
  where c.category = 'weapon_skin' and c.name = s.set_name || ' ' || initcap(wp.w));

-- ---------------------------------------------------------------------------
-- The reward and evidence function.
-- ---------------------------------------------------------------------------
create or replace function public.darkom_report_coop_contract(p_squad uuid, p_contract text, p_seconds integer, p_kills integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.darkom_squads;
  today date := (now() at time zone 'utc')::date;
  done_today integer;
  paid_today integer;
  elapsed integer;
  floor_s integer;
  base integer;
  xp integer;
  cleared integer;
  kinds integer;
  unlocked text[] := '{}';
  item uuid;
  w text;
  nm text;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_contract is null or p_contract !~ '^(clear|hold|bounty|data)$' then
    return jsonb_build_object('success', false, 'error', 'Unknown contract');
  end if;
  select * into s from public.darkom_squads where id = p_squad;
  if not found then return jsonb_build_object('success', false, 'error', 'Squad not found'); end if;
  if not exists (select 1 from public.darkom_squad_members x where x.squad_id = p_squad and x.user_id = uid) then
    return jsonb_build_object('success', false, 'error', 'You were not in this squad');
  end if;
  if s.mode <> ('contract_' || p_contract) or s.status <> 'started' or s.started_at is null then
    return jsonb_build_object('success', true, 'accepted', false, 'note', 'This squad was not running that contract');
  end if;
  if coalesce(s.started_count, 0) < 2 then
    return jsonb_build_object('success', true, 'accepted', false, 'note', 'Contracts need at least 2 players');
  end if;
  if exists (select 1 from public.darkom_coop_flags f where f.squad_id = p_squad) then
    return jsonb_build_object('success', true, 'accepted', false, 'note', 'This run is under review');
  end if;

  -- The only clock that counts is the server's.
  elapsed := floor(extract(epoch from (now() - s.started_at)))::int;
  floor_s := case p_contract when 'clear' then 75 when 'bounty' then 60 when 'data' then 75 else 244 end;
  if elapsed < floor_s then
    return jsonb_build_object('success', true, 'accepted', false, 'note', 'That run was faster than the contract allows, so it was not counted');
  end if;
  if elapsed > 2700 then
    return jsonb_build_object('success', true, 'accepted', false, 'note', 'That run was too old to count');
  end if;
  if exists (select 1 from public.darkom_coop_rewards r where r.squad_id = p_squad and r.user_id = uid) then
    return jsonb_build_object('success', true, 'accepted', false, 'note', 'Already claimed for this contract');
  end if;
  select count(*), count(*) filter (where rewarded) into done_today, paid_today
    from public.darkom_coop_rewards r where r.user_id = uid and r.day = today;
  if done_today >= 6 then
    return jsonb_build_object('success', true, 'accepted', false, 'note', 'Daily squad contract limit reached');
  end if;

  base := case p_contract when 'clear' then 60 when 'hold' then 60 when 'bounty' then 70 else 70 end;
  xp := case when paid_today < 3 then base + least(2, greatest(0, s.started_count - 2)) * 10 else 0 end;
  insert into public.darkom_coop_rewards (squad_id, user_id, contract, xp, day, rewarded, elapsed, kills)
    values (p_squad, uid, p_contract, xp, today, xp > 0, elapsed, least(greatest(coalesce(p_kills, 0), 0), 500));
  if xp > 0 then perform public.pass_add_xp(uid, xp); end if;

  -- Cosmetic unlocks by contracts cleared. A set unlocks the skin for every weapon.
  select count(*), count(distinct contract) into cleared, kinds from public.darkom_coop_rewards r where r.user_id = uid;
  if cleared >= 1 then
    select c.id into item from public.cosmetic_items c where c.category = 'title' and c.name = 'Contract Crew';
    if item is not null and public.grant_cosmetic(uid, item, 'milestone', 'squad:1') then unlocked := array_append(unlocked, 'Contract Crew'); end if;
  end if;
  if cleared >= 3 then
    select c.id into item from public.cosmetic_items c where c.category = 'trail' and c.name = 'Patrol Pulse';
    if item is not null and public.grant_cosmetic(uid, item, 'milestone', 'squad:3') then unlocked := array_append(unlocked, 'Patrol Pulse'); end if;
  end if;
  if cleared >= 10 then
    select c.id into item from public.cosmetic_items c where c.category = 'trail' and c.name = 'Gridlock Gold';
    if item is not null and public.grant_cosmetic(uid, item, 'milestone', 'squad:10') then unlocked := array_append(unlocked, 'Gridlock Gold'); end if;
  end if;
  if kinds >= 4 then
    select c.id into item from public.cosmetic_items c where c.category = 'trail' and c.name = 'Four Corners';
    if item is not null and public.grant_cosmetic(uid, item, 'milestone', 'squad:all') then unlocked := array_append(unlocked, 'Four Corners'); end if;
  end if;
  foreach w in array array['sword', 'dagger', 'hammer', 'axe', 'staff', 'shield'] loop
    if cleared >= 6 then
      nm := 'Squad Steel ' || initcap(w);
      select c.id into item from public.cosmetic_items c where c.category = 'weapon_skin' and c.name = nm;
      if item is not null and public.grant_cosmetic(uid, item, 'milestone', 'squad:6') then unlocked := array_append(unlocked, nm); end if;
    end if;
    if cleared >= 15 then
      nm := 'Bounty Brass ' || initcap(w);
      select c.id into item from public.cosmetic_items c where c.category = 'weapon_skin' and c.name = nm;
      if item is not null and public.grant_cosmetic(uid, item, 'milestone', 'squad:15') then unlocked := array_append(unlocked, nm); end if;
    end if;
  end loop;

  return jsonb_build_object('success', true, 'accepted', true, 'xp', xp, 'cleared', cleared,
    'unlocked', to_jsonb(unlocked),
    'note', case when xp > 0 then 'Team reward: ' || xp || ' Season Pass XP' else 'Cleared. Today''s XP rewards are used up' end);
end;
$$;

-- ---------------------------------------------------------------------------
-- The board, computed from confirmed reports only.
-- ---------------------------------------------------------------------------
create or replace function public.darkom_coop_board(p_contract text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  runs jsonb;
  players jsonb;
  mine integer;
  kinds integer;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select coalesce(jsonb_agg(jsonb_build_object('names', t.names, 'seconds', t.secs, 'members', t.members) order by t.secs), '[]'::jsonb)
    into runs from (
      select g.secs, g.members,
        coalesce((select array_agg(m.name order by m.joined_at) from public.darkom_squad_members m where m.squad_id = g.squad_id), '{}') as names
      from (
        select r.squad_id,
               (array_agg(r.elapsed order by r.elapsed))[count(*) / 2 + 1] as secs,
               max(s.started_count) as members,
               sum(r.kills) as kills
        from public.darkom_coop_rewards r
        join public.darkom_squads s on s.id = r.squad_id
        where r.contract = p_contract and p_contract in ('clear', 'bounty', 'data')
          and r.elapsed is not null
          and not exists (select 1 from public.darkom_coop_flags f where f.squad_id = r.squad_id)
        group by r.squad_id
        having count(*) >= 2
      ) g
      where p_contract <> 'clear' or g.kills >= floor(0.8 * (14 + 8 * g.members))
      order by g.secs asc limit 10) t;
  select coalesce(jsonb_agg(jsonb_build_object('name', t.nm, 'cleared', t.n) order by t.n desc), '[]'::jsonb)
    into players from (
      select public.darkom_name(r.user_id) as nm, count(*)::int as n
      from public.darkom_coop_rewards r
      where not exists (select 1 from public.darkom_coop_flags f where f.squad_id = r.squad_id)
      group by r.user_id order by count(*) desc limit 10) t;
  select count(*), count(distinct contract) into mine, kinds from public.darkom_coop_rewards r
    where r.user_id = uid and not exists (select 1 from public.darkom_coop_flags f where f.squad_id = r.squad_id);
  return jsonb_build_object('success', true, 'runs', runs, 'players', players, 'mine', mine, 'kinds', kinds);
end;
$$;

-- ---------------------------------------------------------------------------
-- Admin: look at recent runs, take one off the board.
-- ---------------------------------------------------------------------------
create or replace function public.darkom_admin_coop_recent(p_hours integer default 48)
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not exists (select 1 from public.profiles p where p.id = auth.uid() and p.role::text in ('admin', 'super_admin')) then
    return jsonb_build_object('success', false, 'error', 'Admins only');
  end if;
  return jsonb_build_object('success', true, 'runs', coalesce((
    select jsonb_agg(x order by x.at desc) from (
      select r.squad_id, r.contract, count(*) as reports, min(r.elapsed) as fastest, max(r.elapsed) as slowest,
             sum(r.kills) as kills, max(r.created_at) as at,
             (select array_agg(m.name) from public.darkom_squad_members m where m.squad_id = r.squad_id) as names,
             exists (select 1 from public.darkom_coop_flags f where f.squad_id = r.squad_id) as flagged
      from public.darkom_coop_rewards r
      where r.created_at > now() - make_interval(hours => greatest(1, least(coalesce(p_hours, 48), 720)))
      group by r.squad_id, r.contract
      limit 200) x), '[]'::jsonb));
end;
$$;

create or replace function public.darkom_admin_coop_flag(p_squad uuid, p_reason text, p_unflag boolean default false)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not exists (select 1 from public.profiles p where p.id = auth.uid() and p.role::text in ('admin', 'super_admin')) then
    return jsonb_build_object('success', false, 'error', 'Admins only');
  end if;
  if p_unflag then
    delete from public.darkom_coop_flags where squad_id = p_squad;
  else
    insert into public.darkom_coop_flags (squad_id, reason, flagged_by) values (p_squad, coalesce(p_reason, ''), auth.uid())
      on conflict (squad_id) do update set reason = excluded.reason, flagged_by = excluded.flagged_by, created_at = now();
  end if;
  return jsonb_build_object('success', true);
end;
$$;

grant execute on function public.darkom_report_coop_contract(uuid, text, integer, integer) to authenticated;
grant execute on function public.darkom_coop_board(text) to authenticated;
grant execute on function public.darkom_admin_coop_recent(integer) to authenticated;
grant execute on function public.darkom_admin_coop_flag(uuid, text, boolean) to authenticated;
notify pgrst, 'reload schema';
