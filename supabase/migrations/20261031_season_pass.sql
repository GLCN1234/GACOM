-- Season pass. Season 1 launches with the Agon event.
--
--   * One season is active at a time (pass_seasons). Name, dates and the premium price
--     are rows an admin can edit; no app release is needed.
--   * Pass XP comes from Darkom City play (every 'Darkom City' row written to game_scores,
--     which covers story runs and board missions). A daily cap stops grinding.
--   * Every level has a free reward and a premium reward (pass_rewards). Premium is bought
--     once per season with wallet money and is retroactive: rewards from levels already
--     reached can be claimed straight away.
--   * Cosmetic rewards are rows in cosmetic_items with source 'earned', so they never
--     appear in the shop.
--   * Other games can add XP later by calling pass_add_xp (internal, not callable by players).

create table if not exists public.pass_seasons (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  tagline text,
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  premium_price integer not null default 2000 check (premium_price >= 0),
  xp_per_level integer not null default 150 check (xp_per_level > 0),
  max_level integer not null default 40 check (max_level between 1 and 100),
  daily_xp_cap integer not null default 500 check (daily_xp_cap > 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.pass_rewards (
  season_id uuid not null references public.pass_seasons(id) on delete cascade,
  level integer not null check (level >= 1),
  track text not null check (track in ('free', 'premium')),
  kind text not null check (kind in ('points', 'cosmetic')),
  amount integer not null default 0,
  item_id uuid references public.cosmetic_items(id),
  label text not null,
  primary key (season_id, level, track)
);

create table if not exists public.pass_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  season_id uuid not null references public.pass_seasons(id) on delete cascade,
  xp integer not null default 0,
  premium boolean not null default false,
  premium_at timestamptz,
  claimed text[] not null default '{}',
  xp_day date,
  xp_today integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, season_id)
);

alter table public.pass_seasons enable row level security;
alter table public.pass_rewards enable row level security;
alter table public.pass_progress enable row level security;
drop policy if exists "anyone reads pass seasons" on public.pass_seasons;
create policy "anyone reads pass seasons" on public.pass_seasons for select using (true);
drop policy if exists "anyone reads pass rewards" on public.pass_rewards;
create policy "anyone reads pass rewards" on public.pass_rewards for select using (true);
drop policy if exists "own pass progress" on public.pass_progress;
create policy "own pass progress" on public.pass_progress for select using (user_id = auth.uid());
revoke insert, update, delete on public.pass_seasons, public.pass_rewards, public.pass_progress from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Season 1 cosmetics (earned only, never sold)
-- ---------------------------------------------------------------------------
insert into public.cosmetic_items
  (category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
select v.* from (values
  ('name_color','Signal Cyan','#00E5FF','{}'::jsonb,0,'common',false,'user','Season 1 free track.',900,'earned','Season 1 pass, free track'),
  ('name_color','Ember','#FF6A00','{}'::jsonb,0,'rare',false,'user','Season 1 free track.',901,'earned','Season 1 pass, free track'),
  ('title','S1 Recruit','S1 Recruit','{}'::jsonb,0,'common',false,'user','Season 1 free track.',902,'earned','Season 1 pass, free track'),
  ('title','S1 Veteran','S1 Veteran','{}'::jsonb,0,'rare',false,'user','Season 1 free track.',903,'earned','Season 1 pass, free track'),
  ('title','Season 1 Finisher','Season 1 Finisher','{}'::jsonb,0,'epic',false,'user','Reached level 40 in Season 1.',904,'earned','Season 1 pass, free track'),
  ('weapon_skin','Pulse Sword','sword','{"weapon":"sword","metal":"#9FB4D0","hi":"#D6E4F5","ex":"#5E7391","w":"#33414F","glow":"#40C4FF"}'::jsonb,0,'rare',false,'user','Season 1 free track.',905,'earned','Season 1 pass, free track'),
  ('name_color','Solar Gold','#FFC400','{}'::jsonb,0,'rare',false,'user','Season 1 premium.',910,'earned','Season 1 pass, premium track'),
  ('name_color','Violet Static','#B388FF','{}'::jsonb,0,'epic',false,'user','Season 1 premium.',911,'earned','Season 1 pass, premium track'),
  ('title','Darkom Contractor','Darkom Contractor','{}'::jsonb,0,'rare',false,'user','Season 1 premium.',912,'earned','Season 1 pass, premium track'),
  ('title','Agon Pioneer','Agon Pioneer','{}'::jsonb,0,'legendary',false,'user','Season 1 premium. Agon launch season.',913,'earned','Season 1 pass, premium track'),
  ('weapon_skin','Neon Edge Sword','sword','{"weapon":"sword","metal":"#FF2E93","hi":"#FFB3D9","ex":"#8A0F52","w":"#1A0A14","glow":"#FF2E93"}'::jsonb,0,'rare',false,'user','Season 1 premium.',914,'earned','Season 1 pass, premium track'),
  ('weapon_skin','Blackout Hammer','hammer','{"weapon":"hammer","metal":"#2B2F3A","hi":"#7A8499","ex":"#00E5FF","w":"#14161C","glow":"#00E5FF"}'::jsonb,0,'epic',false,'user','Season 1 premium.',915,'earned','Season 1 pass, premium track'),
  ('weapon_skin','Agon Crown Sword','sword','{"weapon":"sword","metal":"#FFD54F","hi":"#FFF8DC","ex":"#C2410C","w":"#3A2A0C","glow":"#FFD54F"}'::jsonb,0,'legendary',false,'user','Season 1 premium. Agon launch season.',916,'earned','Season 1 pass, premium track'),
  ('hero_outfit','Night Courier','','{"shirt":"#1F2A44","pants":"#0F1626","skin":"#8D5A3B","hair":"#14100C","hair_style":"low"}'::jsonb,0,'rare',false,'user','Season 1 premium.',917,'earned','Season 1 pass, premium track'),
  ('hero_outfit','Gridwalker','','{"shirt":"#00C896","pants":"#0B3B33","skin":"#A66E47","hair":"#14100C","hair_style":"braids"}'::jsonb,0,'epic',false,'user','Season 1 premium.',918,'earned','Season 1 pass, premium track'),
  ('hero_outfit','Season 1 Champion','','{"shirt":"#FFB300","pants":"#3A2A0C","skin":"#5A3A28","hair":"#14100C","hair_style":"afro"}'::jsonb,0,'legendary',false,'user','Season 1 premium. Level 40.',919,'earned','Season 1 pass, premium track')
) as v(category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
where not exists (select 1 from public.cosmetic_items c where c.category = v.category and c.name = v.name);

-- ---------------------------------------------------------------------------
-- Season 1 and its 40 levels
-- ---------------------------------------------------------------------------
insert into public.pass_seasons (key, name, tagline, starts_at, ends_at, premium_price, xp_per_level, max_level, daily_xp_cap)
values ('s1', 'Season 1', 'The Agon season', now(), now() + interval '60 days', 2000, 150, 40, 500)
on conflict (key) do nothing;

do $$
declare
  sid uuid := (select id from public.pass_seasons where key = 's1');
  lvl integer;
  free_items jsonb := '{"3":["name_color","Signal Cyan"],"8":["title","S1 Recruit"],"15":["name_color","Ember"],"20":["weapon_skin","Pulse Sword"],"28":["title","S1 Veteran"],"40":["title","Season 1 Finisher"]}';
  prem_items jsonb := '{"1":["name_color","Solar Gold"],"5":["weapon_skin","Neon Edge Sword"],"10":["hero_outfit","Night Courier"],"15":["title","Darkom Contractor"],"20":["weapon_skin","Blackout Hammer"],"25":["name_color","Violet Static"],"30":["hero_outfit","Gridwalker"],"35":["weapon_skin","Agon Crown Sword"],"38":["hero_outfit","Season 1 Champion"],"40":["title","Agon Pioneer"]}';
  pair jsonb;
  iid uuid;
begin
  if sid is null then return; end if;
  for lvl in 1..40 loop
    -- free track
    pair := free_items -> lvl::text;
    if pair is not null then
      select id into iid from public.cosmetic_items where category = pair ->> 0 and name = pair ->> 1 limit 1;
      insert into public.pass_rewards (season_id, level, track, kind, amount, item_id, label)
      values (sid, lvl, 'free', 'cosmetic', 0, iid, pair ->> 1) on conflict do nothing;
    else
      insert into public.pass_rewards (season_id, level, track, kind, amount, label)
      values (sid, lvl, 'free', 'points', 20 + (lvl / 10) * 10, (20 + (lvl / 10) * 10) || ' points') on conflict do nothing;
    end if;
    -- premium track
    pair := prem_items -> lvl::text;
    if pair is not null then
      select id into iid from public.cosmetic_items where category = pair ->> 0 and name = pair ->> 1 limit 1;
      insert into public.pass_rewards (season_id, level, track, kind, amount, item_id, label)
      values (sid, lvl, 'premium', 'cosmetic', 0, iid, pair ->> 1) on conflict do nothing;
    else
      insert into public.pass_rewards (season_id, level, track, kind, amount, label)
      values (sid, lvl, 'premium', 'points', 50 + (lvl / 10) * 25, (50 + (lvl / 10) * 25) || ' points') on conflict do nothing;
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- Functions
-- ---------------------------------------------------------------------------
create or replace function public.pass_active()
returns public.pass_seasons language sql stable security definer set search_path = public as $$
  select * from public.pass_seasons
   where is_active and starts_at <= now() and ends_at > now()
   order by starts_at desc limit 1;
$$;
revoke all on function public.pass_active() from public, anon, authenticated;

-- Internal: add XP for a user in the active season, respecting the daily cap.
create or replace function public.pass_add_xp(p_user uuid, p_amount integer)
returns void language plpgsql security definer set search_path = public as $$
declare
  s public.pass_seasons;
  today date := (now() at time zone 'utc')::date;
  pr public.pass_progress;
  add_xp integer;
begin
  if p_user is null or coalesce(p_amount, 0) <= 0 then return; end if;
  s := public.pass_active();
  if s.id is null then return; end if;
  insert into public.pass_progress (user_id, season_id) values (p_user, s.id) on conflict do nothing;
  select * into pr from public.pass_progress where user_id = p_user and season_id = s.id for update;
  if pr.xp_day is distinct from today then pr.xp_day := today; pr.xp_today := 0; end if;
  add_xp := least(p_amount, 400, greatest(0, s.daily_xp_cap - pr.xp_today));
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

-- Every Darkom City score row is XP the player earned; it feeds the pass.
create or replace function public.pass_from_game_scores()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.game_name = 'Darkom City' and coalesce(new.score, 0) > 0 then
    perform public.pass_add_xp(new.user_id, new.score);
  end if;
  return new;
exception when others then
  return new; -- never block a game score because of the pass
end;
$$;
revoke all on function public.pass_from_game_scores() from public, anon, authenticated;
drop trigger if exists pass_from_game_scores on public.game_scores;
create trigger pass_from_game_scores after insert on public.game_scores
  for each row execute function public.pass_from_game_scores();

create or replace function public.pass_state()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.pass_seasons;
  pr public.pass_progress;
  lvl integer := 0;
  rewards jsonb;
  bal numeric;
begin
  if uid is null then return null; end if;
  s := public.pass_active();
  if s.id is null then return jsonb_build_object('season', null); end if;
  select * into pr from public.pass_progress where user_id = uid and season_id = s.id;
  if found then lvl := least(s.max_level, pr.xp / s.xp_per_level); end if;
  select wallet_balance into bal from public.profiles where id = uid;

  select coalesce(jsonb_agg(jsonb_build_object(
      'level', r.level, 'track', r.track, 'kind', r.kind, 'amount', r.amount, 'label', r.label,
      'claimed', found_claim(r.level, r.track, pr.claimed),
      'item', case when ci.id is null then null else jsonb_build_object(
        'name', ci.name, 'category', ci.category, 'rarity', ci.rarity, 'value', ci.value, 'asset', ci.asset) end
    ) order by r.level, r.track), '[]'::jsonb)
  into rewards
  from public.pass_rewards r
  left join public.cosmetic_items ci on ci.id = r.item_id
  where r.season_id = s.id;

  return jsonb_build_object(
    'season', jsonb_build_object(
      'id', s.id, 'key', s.key, 'name', s.name, 'tagline', s.tagline, 'ends_at', s.ends_at,
      'premium_price', s.premium_price, 'xp_per_level', s.xp_per_level, 'max_level', s.max_level,
      'daily_xp_cap', s.daily_xp_cap),
    'xp', coalesce(pr.xp, 0),
    'level', lvl,
    'premium', coalesce(pr.premium, false),
    'xp_today', case when pr.xp_day = (now() at time zone 'utc')::date then pr.xp_today else 0 end,
    'balance', coalesce(bal, 0),
    'rewards', rewards);
end;
$$;
grant execute on function public.pass_state() to authenticated;

-- helper used by pass_state: has this level/track been claimed
create or replace function public.found_claim(p_level integer, p_track text, p_claimed text[])
returns boolean language sql immutable as $$
  select coalesce((p_level::text || ':' || p_track) = any (p_claimed), false);
$$;
revoke all on function public.found_claim(integer, text, text[]) from public, anon, authenticated;
grant execute on function public.found_claim(integer, text, text[]) to authenticated;

create or replace function public.pass_claim(p_level integer, p_track text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.pass_seasons;
  pr public.pass_progress;
  r public.pass_rewards;
  lvl integer;
  k text := p_level::text || ':' || coalesce(p_track, '');
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  perform public.sec_rl('pass_claim', 40, 60);
  s := public.pass_active();
  if s.id is null then return jsonb_build_object('success', false, 'error', 'No season is running'); end if;
  select * into pr from public.pass_progress where user_id = uid and season_id = s.id for update;
  if not found then return jsonb_build_object('success', false, 'error', 'Play to earn pass levels first'); end if;
  lvl := least(s.max_level, pr.xp / s.xp_per_level);
  if p_track not in ('free', 'premium') then return jsonb_build_object('success', false, 'error', 'Unknown track'); end if;
  if p_level < 1 or p_level > lvl then return jsonb_build_object('success', false, 'error', 'Reach level ' || p_level || ' first'); end if;
  if p_track = 'premium' and not pr.premium then return jsonb_build_object('success', false, 'error', 'Unlock the premium pass first'); end if;
  if k = any (pr.claimed) then return jsonb_build_object('success', false, 'error', 'Already claimed'); end if;
  select * into r from public.pass_rewards where season_id = s.id and level = p_level and track = p_track;
  if not found then return jsonb_build_object('success', false, 'error', 'No reward at this level'); end if;

  if r.kind = 'cosmetic' and r.item_id is not null then
    perform public.grant_cosmetic(uid, r.item_id, 'season_pass', s.key);
  elsif r.kind = 'points' and r.amount > 0 then
    insert into public.game_scores (user_id, game_name, score, won) values (uid, 'Season Pass', r.amount, false);
  end if;
  update public.pass_progress set claimed = claimed || k, updated_at = now() where user_id = uid and season_id = s.id;
  return jsonb_build_object('success', true, 'label', r.label, 'kind', r.kind);
end;
$$;
grant execute on function public.pass_claim(integer, text) to authenticated;

create or replace function public.pass_buy_premium()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.pass_seasons;
  pr public.pass_progress;
  r jsonb;
  bal numeric;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  perform public.sec_rl('pass_buy', 6, 60);
  perform pg_advisory_xact_lock(hashtextextended('gacom:wallet:' || uid::text, 0));
  s := public.pass_active();
  if s.id is null then return jsonb_build_object('success', false, 'error', 'No season is running'); end if;
  insert into public.pass_progress (user_id, season_id) values (uid, s.id) on conflict do nothing;
  select * into pr from public.pass_progress where user_id = uid and season_id = s.id for update;
  if pr.premium then return jsonb_build_object('success', false, 'error', 'You already have the premium pass'); end if;

  r := public.deduct_arena_stake(uid, s.premium_price, 'PASS_' || s.key || '_' || uid::text);
  if coalesce((r ->> 'success')::boolean, false) is not true then
    return jsonb_build_object('success', false, 'error', coalesce(r ->> 'error', 'Not enough balance'));
  end if;
  begin
    update public.pass_progress set premium = true, premium_at = now(), updated_at = now()
     where user_id = uid and season_id = s.id;
  exception when others then
    perform public.refund_arena_stake(uid, s.premium_price, 'PASS_REFUND_' || s.key || '_' || uid::text);
    return jsonb_build_object('success', false, 'error', 'Could not unlock the pass, you were not charged');
  end;
  select wallet_balance into bal from public.profiles where id = uid;
  return jsonb_build_object('success', true, 'balance', bal, 'paid', s.premium_price);
end;
$$;
grant execute on function public.pass_buy_premium() to authenticated;

notify pgrst, 'reload schema';
