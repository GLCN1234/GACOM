-- Darkom City: server-side progress for the 2D action game. Rewards are cosmetic
-- only (titles, trails, an outfit, weapon skins, a trophy). XP is recorded as a
-- game_scores row ('Darkom City'), the same table every other game feeds, so it
-- counts toward profile points, the leaderboard and the Missions metrics
-- games_played / game_wins. Progress is written only by darkom_report_run.

create table if not exists public.darkom_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  chapter integer not null default 1 check (chapter between 1 and 6),
  best_score integer not null default 0,
  total_kills integer not null default 0,
  echo_wins integer not null default 0,
  contracts_done text[] not null default '{}',
  reward_day date,
  runs_today integer not null default 0,
  updated_at timestamptz not null default now()
);

create table if not exists public.darkom_runs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  district text,
  kills integer not null default 0,
  score integer not null default 0,
  duration_sec integer not null default 0,
  accepted boolean not null default false,
  created_at timestamptz not null default now()
);
create index if not exists darkom_runs_user_idx on public.darkom_runs (user_id, created_at desc);

alter table public.darkom_progress enable row level security;
alter table public.darkom_runs enable row level security;
drop policy if exists "own darkom progress" on public.darkom_progress;
create policy "own darkom progress" on public.darkom_progress for select using (auth.uid() = user_id);
drop policy if exists "own darkom runs" on public.darkom_runs;
create policy "own darkom runs" on public.darkom_runs for select using (auth.uid() = user_id);
grant select on public.darkom_progress, public.darkom_runs to authenticated;
revoke insert, update, delete on public.darkom_progress from anon, authenticated;
revoke insert, update, delete on public.darkom_runs from anon, authenticated;

-- Trophy
insert into public.trophy_defs (key, name, description, icon, rarity, sort_order) values
  ('city_relit', 'City Relit', 'Finish the Darkom City story', 'light_mode_rounded', 'mythic', 14)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- Cosmetics. Earned items are never sold; shop items fill out the weapon tiers.
-- ---------------------------------------------------------------------------
insert into public.cosmetic_items
  (category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
select * from (values
  ('title','Echo Breaker','Echo Breaker','{}'::jsonb,0,'rare',false,'user','You beat your own Echo.',200,'earned','Defeat an Echo in Darkom City'),
  ('title','Shade Hunter','Shade Hunter','{}'::jsonb,0,'rare',false,'user','Five hundred shades and counting.',201,'earned','Defeat 500 shades in Darkom City'),
  ('title','Darkom Native','Darkom Native','{}'::jsonb,0,'common',false,'user','You know the Neon Quarter by heart.',202,'earned','Finish chapter 1 of Darkom City'),
  ('title','City Relit','City Relit','{}'::jsonb,0,'mythic',false,'user','The lights are back on.',203,'earned','Finish the Darkom City story'),
  ('trail','Neon Trail','','{"kind":"lightning","color":"#FF2E97"}'::jsonb,0,'rare',false,'user','Magenta neon behind your hero.',204,'earned','Finish chapter 2 of Darkom City'),
  ('hero_outfit','Gridrunner','','{"shirt":"#0D1320","pants":"#1B2A41","skin":"#8D5A3B","hair":"#2ED3E6"}'::jsonb,0,'epic',false,'user','A courier suit lit by the Dead Grid.',205,'earned','Finish chapter 4 of Darkom City'),
  ('weapon_skin','Neon Edge Dagger','dagger','{"weapon":"dagger","metal":"#FF2E97","hi":"#FFD1EA","ex":"#7A0F4A","w":"#0D1320","glow":"#FF2E97"}'::jsonb,0,'epic',false,'user','Pink neon along the blade.',206,'earned','Beat your Echo 3 times in Darkom City'),
  ('weapon_skin','Echo Staff','staff','{"weapon":"staff","metal":"#8E9BB5","hi":"#E3EBFF","ex":"#3A4560","w":"#10131C","glow":"#9FB4FF"}'::jsonb,0,'epic',false,'user','Hums with a borrowed memory.',207,'earned','Beat your Echo 10 times in Darkom City'),
  ('weapon_skin','Dockbreaker Hammer','hammer','{"weapon":"hammer","metal":"#2E6F8E","hi":"#9FDCF2","ex":"#133A4D","w":"#1C2B33","glow":"#2ED3E6"}'::jsonb,0,'epic',false,'user','Salt-stained iron from Glasswater Docks.',208,'earned','Finish chapter 3 of Darkom City'),
  ('weapon_skin','Rustyard Cleaver','axe','{"weapon":"axe","metal":"#A8522B","hi":"#F2B48C","ex":"#5A2411","w":"#26160E","glow":"#FF7A2E"}'::jsonb,0,'epic',false,'user','Scrap steel with an orange burn.',209,'earned','Finish chapter 3 of Darkom City'),
  ('weapon_skin','Blackout Sword','sword','{"weapon":"sword","metal":"#12161F","hi":"#4A5470","ex":"#00E5FF","w":"#0A0C12","glow":"#00E5FF"}'::jsonb,0,'epic',false,'user','Dark steel with a cyan edge.',210,'earned','Finish chapter 5 of Darkom City'),
  ('weapon_skin','Deadgrid Bulwark','shield','{"weapon":"shield","metal":"#1B2A41","hi":"#5FA8FF","ex":"#B060FF","w":"#0D1320","glow":"#5FA8FF"}'::jsonb,0,'epic',false,'user','Circuit lines across the face.',211,'earned','Finish chapter 5 of Darkom City'),

  ('weapon_skin','Voidglass Dagger','dagger','{"weapon":"dagger","metal":"#3B2A6B","hi":"#C9B2FF","ex":"#7C4DFF","w":"#120C24","glow":"#7C4DFF"}'::jsonb,800,'epic',false,'user','Smoked violet glass.',12,'shop',null),
  ('weapon_skin','Sunfang Dagger','dagger','{"weapon":"dagger","metal":"#FFC93C","hi":"#FFF6CF","ex":"#B45309","w":"#3A2A0C","glow":"#FFC93C"}'::jsonb,1500,'legendary',false,'user','A fang of molten gold.',13,'shop',null),
  ('weapon_skin','Crimson Sword','sword','{"weapon":"sword","metal":"#C0263D","hi":"#FFC2CB","ex":"#6B0F1F","w":"#2A0E14","glow":"#FF4F66"}'::jsonb,800,'epic',false,'user','Blood red edge.',22,'shop',null),
  ('weapon_skin','Aurum Sword','sword','{"weapon":"sword","metal":"#E8B923","hi":"#FFF3B0","ex":"#8A5A00","w":"#2E2208","glow":"#FFD84A"}'::jsonb,1500,'legendary',false,'user','Royal gold, honed bright.',23,'shop',null),
  ('weapon_skin','Azure Shield','shield','{"weapon":"shield","metal":"#3C9DFF","hi":"#CFE6FF","ex":"#1F5FA8","w":"#1B2A41","glow":"#3C9DFF"}'::jsonb,500,'rare',false,'user','Deep sky blue.',32,'shop',null),
  ('weapon_skin','Obsidian Shield','shield','{"weapon":"shield","metal":"#1A1D26","hi":"#6B7790","ex":"#FF4F66","w":"#0B0D12","glow":"#FF4F66"}'::jsonb,800,'epic',false,'user','Black glass with red trim.',33,'shop',null),
  ('weapon_skin','Jade Staff','staff','{"weapon":"staff","metal":"#2FBF8F","hi":"#C7F5E4","ex":"#126B4E","w":"#1F2D24","glow":"#2FBF8F"}'::jsonb,400,'rare',false,'user','Carved green stone.',42,'shop',null),
  ('weapon_skin','Starlit Staff','staff','{"weapon":"staff","metal":"#F6E7FF","hi":"#FFFFFF","ex":"#B8A2FF","w":"#1A1030","glow":"#E9D2FF"}'::jsonb,1500,'legendary',false,'user','A pale star at its tip.',43,'shop',null),
  ('weapon_skin','Stormcall Axe','axe','{"weapon":"axe","metal":"#5B6C8F","hi":"#C9D6F5","ex":"#FFD84A","w":"#1B2A41","glow":"#FFD84A"}'::jsonb,800,'epic',false,'user','Yellow lightning in the steel.',52,'shop',null),
  ('weapon_skin','Magma Axe','axe','{"weapon":"axe","metal":"#E2411A","hi":"#FFD2A8","ex":"#7A1D05","w":"#2A1208","glow":"#FF6A1A"}'::jsonb,1500,'legendary',false,'user','Cracked with lava light.',53,'shop',null)
) as seed(category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
where not exists (select 1 from public.cosmetic_items c where c.category = seed.category and c.name = seed.name);

-- ---------------------------------------------------------------------------
-- Helpers (internal)
-- ---------------------------------------------------------------------------
-- Grants a catalogue item by category and name when cond is true. Returns a label
-- such as 'Echo Breaker (title)' only when it was newly granted, else null.
create or replace function public.darkom_award(p_user uuid, p_category text, p_name text, p_cond boolean)
returns text language plpgsql security definer set search_path = public as $$
declare iid uuid;
begin
  if not coalesce(p_cond, false) then return null; end if;
  select id into iid from public.cosmetic_items where category = p_category and name = p_name limit 1;
  if iid is null then return null; end if;
  if public.grant_cosmetic(p_user, iid, 'darkom', p_name) then
    return p_name || ' (' || case p_category when 'hero_outfit' then 'outfit' when 'weapon_skin' then 'weapon skin' else p_category end || ')';
  end if;
  return null;
end;
$$;
revoke all on function public.darkom_award(uuid, text, text, boolean) from public, anon, authenticated;

create or replace function public.darkom_district_chapter(p_district text)
returns integer language sql immutable as $$
  select case p_district when 'neon' then 1 when 'rustyard' then 2 when 'docks' then 3 when 'spire' then 4 when 'grid' then 5 else 0 end;
$$;

-- ---------------------------------------------------------------------------
-- Public RPCs
-- ---------------------------------------------------------------------------
create or replace function public.darkom_get_progress()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); p public.darkom_progress;
begin
  if uid is null then return null; end if;
  select * into p from public.darkom_progress where user_id = uid;
  if not found then
    return jsonb_build_object('chapter', 1, 'best_score', 0, 'total_kills', 0, 'echo_wins', 0,
                              'contracts_done', '[]'::jsonb, 'runs_today', 0);
  end if;
  return jsonb_build_object('chapter', p.chapter, 'best_score', p.best_score, 'total_kills', p.total_kills,
    'echo_wins', p.echo_wins, 'contracts_done', to_jsonb(p.contracts_done),
    'runs_today', case when p.reward_day = (now() at time zone 'utc')::date then p.runs_today else 0 end);
end;
$$;
grant execute on function public.darkom_get_progress() to authenticated;

create or replace function public.darkom_report_run(
  p_district text, p_kills integer, p_score integer, p_duration_sec integer,
  p_contracts text[], p_echo_defeated boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  today date := (now() at time zone 'utc')::date;
  p public.darkom_progress;
  dch integer;
  kills integer := coalesce(p_kills, 0);
  score integer := coalesce(p_score, 0);
  dur integer := coalesce(p_duration_sec, 0);
  echo boolean := coalesce(p_echo_defeated, false);
  req text[];
  k text;
  cap integer;
  ok boolean := true;
  fresh text[] := '{}';
  all_done text[];
  old_chapter integer;
  new_chapter integer;
  xp integer := 0;
  unlocks text[] := '{}';
  u text;
  rewarded boolean;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;

  insert into public.darkom_progress (user_id) values (uid) on conflict (user_id) do nothing;
  select * into p from public.darkom_progress where user_id = uid for update;
  if p.reward_day is distinct from today then
    p.reward_day := today; p.runs_today := 0;
  end if;
  old_chapter := p.chapter;
  cap := least(p.chapter, 5);

  -- plausibility
  dch := public.darkom_district_chapter(p_district);
  if dch = 0 or dch > cap then ok := false; end if;
  if kills < 0 or score < 0 or dur < 5 or dur > 3600 then ok := false; end if;
  if kills > 2 * dur + 3 or kills > 600 then ok := false; end if;
  if score > 400 * dur + 500 or score > 500000 then ok := false; end if;

  -- contract validation: valid key, chapter within what the player has reached
  req := coalesce(p_contracts, '{}');
  if array_length(req, 1) > 20 then ok := false; end if;
  foreach k in array req loop
    if k !~ '^c[1-5]_([1-3]|echo)$' or substring(k from 2 for 1)::int > cap then ok := false; end if;
  end loop;

  if not ok then
    insert into public.darkom_runs (user_id, district, kills, score, duration_sec, accepted)
      values (uid, left(coalesce(p_district, ''), 20), greatest(kills, 0), greatest(score, 0), greatest(dur, 0), false);
    return jsonb_build_object('success', true, 'accepted', false, 'xp', 0, 'chapter', old_chapter,
      'chapter_advanced', false, 'new_contracts', '[]'::jsonb, 'unlocks', '[]'::jsonb);
  end if;

  rewarded := p.runs_today < 12;
  if not rewarded then
    insert into public.darkom_runs (user_id, district, kills, score, duration_sec, accepted)
      values (uid, p_district, kills, score, dur, true);
    return jsonb_build_object('success', true, 'accepted', true, 'xp', 0, 'chapter', old_chapter,
      'chapter_advanced', false, 'new_contracts', '[]'::jsonb, 'unlocks', '[]'::jsonb);
  end if;

  -- new contracts (an Echo contract only counts when the Echo was defeated in this run)
  foreach k in array req loop
    if k like '%\_echo' and not echo then continue; end if;
    if not (k = any (p.contracts_done)) and not (k = any (fresh)) then fresh := fresh || k; end if;
  end loop;
  all_done := p.contracts_done || fresh;

  -- chapter advance: all three contracts and the Echo fight of the current chapter
  new_chapter := p.chapter;
  if p.chapter <= 5
     and ('c' || p.chapter || '_1') = any (all_done) and ('c' || p.chapter || '_2') = any (all_done)
     and ('c' || p.chapter || '_3') = any (all_done) and ('c' || p.chapter || '_echo') = any (all_done) then
    new_chapter := p.chapter + 1;
  end if;

  xp := least(400, kills * 2 + cardinality(fresh) * 40 + (case when echo then 60 else 0 end)
                   + (case when new_chapter > old_chapter then 100 else 0 end) + 10);

  update public.darkom_progress set
    chapter = new_chapter,
    best_score = greatest(best_score, score),
    total_kills = total_kills + kills,
    echo_wins = echo_wins + (case when echo then 1 else 0 end),
    contracts_done = all_done,
    reward_day = today,
    runs_today = p.runs_today + 1,
    updated_at = now()
  where user_id = uid
  returning * into p;

  insert into public.darkom_runs (user_id, district, kills, score, duration_sec, accepted)
    values (uid, p_district, kills, score, dur, true);

  -- XP: the same points ledger every game uses (game_scores), plus today's play log
  insert into public.game_scores (user_id, game_name, score, won) values (uid, 'Darkom City', xp, echo);
  insert into public.daily_play_log (user_id, play_date) values (uid, today) on conflict do nothing;

  -- cosmetics
  foreach u in array array[
    public.darkom_award(uid, 'title', 'Echo Breaker', p.echo_wins >= 1),
    public.darkom_award(uid, 'title', 'Shade Hunter', p.total_kills >= 500),
    public.darkom_award(uid, 'title', 'Darkom Native', p.chapter > 1),
    public.darkom_award(uid, 'trail', 'Neon Trail', p.chapter > 2),
    public.darkom_award(uid, 'hero_outfit', 'Gridrunner', p.chapter > 4),
    public.darkom_award(uid, 'weapon_skin', 'Dockbreaker Hammer', p.chapter > 3),
    public.darkom_award(uid, 'weapon_skin', 'Rustyard Cleaver', p.chapter > 3),
    public.darkom_award(uid, 'weapon_skin', 'Neon Edge Dagger', p.echo_wins >= 3),
    public.darkom_award(uid, 'weapon_skin', 'Echo Staff', p.echo_wins >= 10),
    public.darkom_award(uid, 'weapon_skin', 'Blackout Sword', p.chapter > 5),
    public.darkom_award(uid, 'weapon_skin', 'Deadgrid Bulwark', p.chapter > 5),
    public.darkom_award(uid, 'title', 'City Relit', p.chapter > 5)
  ] loop
    if u is not null then unlocks := unlocks || u; end if;
  end loop;
  if p.chapter > 5 and public.grant_trophy(uid, 'city_relit') then
    unlocks := unlocks || 'City Relit (trophy)'::text;
  end if;

  return jsonb_build_object('success', true, 'accepted', true, 'xp', xp, 'chapter', p.chapter,
    'chapter_advanced', p.chapter > old_chapter, 'new_contracts', to_jsonb(fresh), 'unlocks', to_jsonb(unlocks));
end;
$$;
grant execute on function public.darkom_report_run(text, integer, integer, integer, text[], boolean) to authenticated;

notify pgrst, 'reload schema';
