-- Darkom City mission board: 120 repeatable missions (24 in each of the 5 districts),
-- three daily missions, and a points total. The catalogue itself lives in the app;
-- the server only checks ids, unlocks, plausibility and decides the rewards.
--
--   mission id   m_<district>_<nn>      district: neon rustyard docks spire grid, nn: 01..24
--   tier         (nn - 1) / 6           0 Rookie, 1 Veteran, 2 Elite, 3 Legend
--   unlock       nn <= 6 (Rookie tier is open everywhere) or the district's story chapter reached
--   points       20 + 20 * tier         first clear in full, repeats pay a quarter
--   daily bonus  +60 points the first time each of today's three daily missions is cleared

alter table public.darkom_progress add column if not exists mission_points integer not null default 0;
alter table public.darkom_progress add column if not exists mission_day date;
alter table public.darkom_progress add column if not exists missions_today integer not null default 0;

create table if not exists public.darkom_mission_log (
  user_id uuid not null references auth.users(id) on delete cascade,
  mission_id text not null,
  times integer not null default 0,
  best_time integer,
  best_score integer not null default 0,
  daily_day date,
  first_at timestamptz not null default now(),
  last_at timestamptz not null default now(),
  primary key (user_id, mission_id)
);
alter table public.darkom_mission_log enable row level security;
drop policy if exists "own darkom mission log" on public.darkom_mission_log;
create policy "own darkom mission log" on public.darkom_mission_log for select using (user_id = auth.uid());
revoke insert, update, delete on public.darkom_mission_log from anon, authenticated;

-- the three daily missions for a day, given how many districts the player has reached (1..5)
create or replace function public.darkom_daily_ids(p_day date, p_cap integer)
returns text[] language plpgsql immutable as $$
declare
  names text[] := array['neon', 'rustyard', 'docks', 'spire', 'grid'];
  cap integer := greatest(1, least(coalesce(p_cap, 1), 5));
  dn integer := (p_day - date '2026-01-01');
  res text[] := '{}';
  i integer;
  d integer;
  n integer;
begin
  for i in 0..2 loop
    d := (dn * 3 + i * 2 + 1) % cap;
    n := ((dn * 7 + i * 11) % 24) + 1;
    res := res || ('m_' || names[d + 1] || '_' || lpad(n::text, 2, '0'));
  end loop;
  return res;
end;
$$;
revoke all on function public.darkom_daily_ids(date, integer) from public, anon, authenticated;

create or replace function public.darkom_get_missions()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  today date := (now() at time zone 'utc')::date;
  p public.darkom_progress;
  done jsonb := '{}'::jsonb;
  daily_done jsonb := '[]'::jsonb;
  r record;
begin
  if uid is null then return null; end if;
  select * into p from public.darkom_progress where user_id = uid;
  for r in select mission_id, times, daily_day from public.darkom_mission_log where user_id = uid loop
    done := done || jsonb_build_object(r.mission_id, r.times);
    if r.daily_day = today then daily_done := daily_done || to_jsonb(r.mission_id); end if;
  end loop;
  return jsonb_build_object(
    'points', coalesce(p.mission_points, 0),
    'done', done,
    'daily_done', daily_done,
    'missions_today', case when p.mission_day = today then coalesce(p.missions_today, 0) else 0 end);
end;
$$;
grant execute on function public.darkom_get_missions() to authenticated;

create or replace function public.darkom_report_mission(
  p_mission text, p_kills integer, p_score integer, p_duration_sec integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  today date := (now() at time zone 'utc')::date;
  p public.darkom_progress;
  mdistrict text;
  mn integer;
  dch integer;
  cap integer;
  tier integer;
  kills integer := coalesce(p_kills, 0);
  score integer := coalesce(p_score, 0);
  dur integer := coalesce(p_duration_sec, 0);
  lg public.darkom_mission_log;
  first_clear boolean;
  is_daily boolean;
  daily_bonus integer := 0;
  pts integer;
  xp integer;
  rewarded boolean;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  perform public.sec_rl('dk_mission', 20, 60);

  if p_mission is null or p_mission !~ '^m_(neon|rustyard|docks|spire|grid)_(0[1-9]|1[0-9]|2[0-4])$' then
    return jsonb_build_object('success', true, 'accepted', false, 'points', 0, 'xp', 0);
  end if;
  mdistrict := split_part(p_mission, '_', 2);
  mn := split_part(p_mission, '_', 3)::int;
  tier := (mn - 1) / 6;
  dch := public.darkom_district_chapter(mdistrict);

  insert into public.darkom_progress (user_id) values (uid) on conflict (user_id) do nothing;
  select * into p from public.darkom_progress where user_id = uid for update;
  cap := least(greatest(p.chapter, 1), 5);
  if p.mission_day is distinct from today then p.mission_day := today; p.missions_today := 0; end if;

  -- plausibility and unlock
  if not (mn <= 6 or dch <= cap) then return jsonb_build_object('success', true, 'accepted', false, 'points', 0, 'xp', 0); end if;
  if kills < 0 or score < 0 or dur < 8 or dur > 1800 then return jsonb_build_object('success', true, 'accepted', false, 'points', 0, 'xp', 0); end if;
  if kills > 2 * dur + 3 or kills > 400 then return jsonb_build_object('success', true, 'accepted', false, 'points', 0, 'xp', 0); end if;
  if score > 400 * dur + 500 or score > 200000 then return jsonb_build_object('success', true, 'accepted', false, 'points', 0, 'xp', 0); end if;

  insert into public.darkom_mission_log (user_id, mission_id) values (uid, p_mission) on conflict do nothing;
  select * into lg from public.darkom_mission_log where user_id = uid and mission_id = p_mission for update;
  first_clear := lg.times = 0;
  is_daily := p_mission = any (public.darkom_daily_ids(today, cap));
  rewarded := p.missions_today < 40;

  pts := 20 + 20 * tier;
  if not first_clear then pts := greatest(5, pts / 4); end if;
  if is_daily and lg.daily_day is distinct from today then daily_bonus := 60; end if;
  if not rewarded then pts := 0; daily_bonus := 0; end if;
  xp := case when rewarded then least(200, 30 + 20 * tier + least(kills, 40)) else 0 end;

  update public.darkom_mission_log set
    times = times + 1,
    best_time = case when best_time is null or dur < best_time then dur else best_time end,
    best_score = greatest(best_score, score),
    daily_day = case when daily_bonus > 0 then today else daily_day end,
    last_at = now()
  where user_id = uid and mission_id = p_mission;

  update public.darkom_progress set
    mission_points = mission_points + pts + daily_bonus,
    mission_day = today,
    missions_today = p.missions_today + 1,
    total_kills = total_kills + kills,
    best_score = greatest(best_score, score),
    updated_at = now()
  where user_id = uid
  returning * into p;

  if xp > 0 then
    insert into public.game_scores (user_id, game_name, score, won) values (uid, 'Darkom City', xp, true);
    insert into public.daily_play_log (user_id, play_date) values (uid, today) on conflict do nothing;
  end if;

  return jsonb_build_object('success', true, 'accepted', true, 'points', pts, 'daily_bonus', daily_bonus,
    'xp', xp, 'first', first_clear, 'total_points', p.mission_points);
end;
$$;
grant execute on function public.darkom_report_mission(text, integer, integer, integer) to authenticated;

notify pgrst, 'reload schema';
