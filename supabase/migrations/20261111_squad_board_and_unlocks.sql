-- Squad board, contract-only cosmetics, and a stricter reward function.
-- Everything here is cosmetic or bragging rights. Nothing reads solo mission
-- points or any ranked ladder, and nothing touches wallets or prizes.

alter table public.darkom_coop_rewards add column if not exists rewarded boolean not null default true;

-- One row per winning squad: the fastest-team-time board reads this.
create table if not exists public.darkom_coop_runs (
  squad_id uuid primary key references public.darkom_squads(id) on delete cascade,
  contract text not null check (contract in ('clear', 'hold', 'bounty', 'data')),
  seconds integer not null check (seconds between 20 and 3600),
  members integer not null default 2,
  names text[] not null default '{}',
  created_at timestamptz not null default now()
);
create index if not exists darkom_coop_runs_board_idx on public.darkom_coop_runs (contract, seconds);
alter table public.darkom_coop_runs enable row level security;
drop policy if exists darkom_coop_runs_read on public.darkom_coop_runs;
create policy darkom_coop_runs_read on public.darkom_coop_runs for select using (true);

-- Contract-only cosmetics. Earned by clearing contracts, never sold.
insert into public.cosmetic_items
  (category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
select v.category, v.name, v.value, v.asset, v.price, v.rarity, v.requires_premium, v.scope, v.description, v.sort_order, v.source, nullif(v.earn_hint, '')
from (values
  ('title','Contract Crew','Contract Crew','{}'::jsonb,0,'rare',false,'user','Cleared a Squad Contract with friends.',930,'earned','Clear 1 Squad Contract'),
  ('trail','Patrol Pulse','','{"kind":"sparkle","color":"#69F0AE"}'::jsonb,0,'rare',false,'user','A green pulse for squads that finish the job.',931,'earned','Clear 3 Squad Contracts'),
  ('weapon_skin','Squad Steel','sword','{"weapon":"sword","metal":"#9FB4CC","hi":"#E8F4FF","ex":"#3A5A7A","w":"#1B2433","glow":"#69F0AE"}'::jsonb,0,'epic',false,'user','Cold blue steel with a green edge.',932,'earned','Clear 6 Squad Contracts'),
  ('trail','Gridlock Gold','','{"kind":"stars","color":"#FFD54F"}'::jsonb,0,'epic',false,'user','Gold stars for seasoned squads.',933,'earned','Clear 10 Squad Contracts'),
  ('weapon_skin','Bounty Brass','sword','{"weapon":"sword","metal":"#C9A24B","hi":"#FFF3C4","ex":"#6B4A12","w":"#2B1D08","glow":"#FFD54F"}'::jsonb,0,'legendary',false,'user','Brass fit for a bounty crew.',934,'earned','Clear 15 Squad Contracts'),
  ('trail','Four Corners','','{"kind":"flame","color":"#00E5FF"}'::jsonb,0,'legendary',false,'user','A cyan fire for squads that have done it all.',935,'earned','Clear all four kinds of Squad Contract')
) as v(category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
where not exists (select 1 from public.cosmetic_items c where c.category = v.category and c.name = v.name);

-- The reward function, now with the board, a daily count limit and the unlocks.
create or replace function public.darkom_report_coop_contract(p_squad uuid, p_contract text, p_seconds integer, p_kills integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.darkom_squads;
  today date := (now() at time zone 'utc')::date;
  done_today integer;
  paid_today integer;
  elapsed integer;
  secs integer;
  base integer;
  xp integer;
  cleared integer;
  kinds integer;
  unlocked text[] := '{}';
  m record;
  item uuid;
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
  elapsed := floor(extract(epoch from (now() - s.started_at)))::int;
  if elapsed < 75 or elapsed > 2700 then
    return jsonb_build_object('success', true, 'accepted', false, 'note', 'That run was too short or too old to count');
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
  insert into public.darkom_coop_rewards (squad_id, user_id, contract, xp, day, rewarded)
    values (p_squad, uid, p_contract, xp, today, xp > 0);
  if xp > 0 then perform public.pass_add_xp(uid, xp); end if;

  -- Team time: a claimed time can be at most 45 seconds under what really passed.
  secs := least(elapsed, greatest(coalesce(p_seconds, elapsed), elapsed - 45));
  secs := greatest(secs, 20);
  insert into public.darkom_coop_runs (squad_id, contract, seconds, members, names)
    values (p_squad, p_contract, secs, s.started_count,
      coalesce((select array_agg(x.name order by x.joined_at) from public.darkom_squad_members x where x.squad_id = p_squad), '{}'))
    on conflict (squad_id) do nothing;

  -- Cosmetic unlocks by contracts cleared.
  select count(*), count(distinct contract) into cleared, kinds from public.darkom_coop_rewards r where r.user_id = uid;
  for m in
    select * from (values
      (1, 'title', 'Contract Crew'), (3, 'trail', 'Patrol Pulse'), (6, 'weapon_skin', 'Squad Steel'),
      (10, 'trail', 'Gridlock Gold'), (15, 'weapon_skin', 'Bounty Brass')
    ) as t(need, cat, nm)
  loop
    if cleared >= m.need then
      select c.id into item from public.cosmetic_items c where c.category = m.cat and c.name = m.nm;
      if item is not null and public.grant_cosmetic(uid, item, 'milestone', 'squad:' || m.need) then
        unlocked := array_append(unlocked, m.nm);
      end if;
    end if;
  end loop;
  if kinds >= 4 then
    select c.id into item from public.cosmetic_items c where c.category = 'trail' and c.name = 'Four Corners';
    if item is not null and public.grant_cosmetic(uid, item, 'milestone', 'squad:all') then
      unlocked := array_append(unlocked, 'Four Corners');
    end if;
  end if;

  return jsonb_build_object('success', true, 'accepted', true, 'xp', xp, 'cleared', cleared,
    'unlocked', to_jsonb(unlocked),
    'note', case when xp > 0 then 'Team reward: ' || xp || ' Season Pass XP' else 'Cleared. Today''s XP rewards are used up' end);
end;
$$;

-- The squad board: fastest team times for a contract, most contracts cleared, and your own count.
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
  select coalesce(jsonb_agg(jsonb_build_object('names', t.names, 'seconds', t.seconds, 'members', t.members) order by t.seconds), '[]'::jsonb)
    into runs from (
      select r.names, r.seconds, r.members from public.darkom_coop_runs r
      where r.contract = p_contract and p_contract in ('clear', 'bounty', 'data')
      order by r.seconds asc, r.created_at asc limit 10) t;
  select coalesce(jsonb_agg(jsonb_build_object('name', t.nm, 'cleared', t.n) order by t.n desc), '[]'::jsonb)
    into players from (
      select public.darkom_name(r.user_id) as nm, count(*)::int as n
      from public.darkom_coop_rewards r group by r.user_id order by count(*) desc limit 10) t;
  select count(*), count(distinct contract) into mine, kinds from public.darkom_coop_rewards r where r.user_id = uid;
  return jsonb_build_object('success', true, 'runs', runs, 'players', players, 'mine', mine, 'kinds', kinds);
end;
$$;

grant execute on function public.darkom_report_coop_contract(uuid, text, integer, integer) to authenticated;
grant execute on function public.darkom_coop_board(text) to authenticated;
notify pgrst, 'reload schema';
