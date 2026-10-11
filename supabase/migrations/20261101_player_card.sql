-- Player card: one call that gathers everything the shareable card shows.
-- Public information only: no wallet, email or bank details. Private accounts
-- return nothing to other people.
--
-- Rank ladder (total points across every game, from game_scores):
--   Rookie 0, Bronze 500, Silver 2000, Gold 6000, Platinum 15000,
--   Diamond 35000, Master 75000, Legend 150000

create or replace function public.player_card(p_user uuid default auth.uid())
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := coalesce(p_user, auth.uid());
  me uuid := auth.uid();
  pr record;
  pts bigint := 0;
  played bigint := 0;
  wins bigint := 0;
  tiers text[] := array['Rookie', 'Bronze', 'Silver', 'Gold', 'Platinum', 'Diamond', 'Master', 'Legend'];
  floors integer[] := array[0, 500, 2000, 6000, 15000, 35000, 75000, 150000];
  ti integer := 1;
  i integer;
  hs record;
  title_txt text;
  name_color text;
  badges jsonb;
  dk record;
  cleared integer := 0;
  s public.pass_seasons;
  pass_lvl integer := null;
  pass_prem boolean := false;
  pp record;
begin
  if me is null then return null; end if;
  select id, username, display_name, gamer_tag, avatar_url, country, created_at,
         competitions_won, competitions_entered, followers_count, is_private
    into pr from public.profiles where id = uid;
  if not found then return null; end if;
  if coalesce(pr.is_private, false) and uid <> me then return null; end if;

  select coalesce(sum(greatest(score, 0)), 0), count(*), count(*) filter (where won is true)
    into pts, played, wins from public.game_scores where user_id = uid;
  for i in 1..8 loop
    if pts >= floors[i] then ti := i; end if;
  end loop;

  select h.name, h.banner_color into hs
    from public.house_members m join public.houses h on h.id = m.house_id
   where m.user_id = uid limit 1;

  select ci.value into title_txt from public.user_cosmetics uc
    join public.cosmetic_items ci on ci.id = uc.equipped_title where uc.user_id = uid;
  select ci.value into name_color from public.user_cosmetics uc
    join public.cosmetic_items ci on ci.id = uc.equipped_name_color where uc.user_id = uid;

  select coalesce(jsonb_agg(jsonb_build_object('key', x.key, 'name', x.name, 'icon', x.icon, 'rarity', x.rarity)), '[]'::jsonb)
    into badges from (
      select d.key, d.name, d.icon, d.rarity
        from public.user_trophies t join public.trophy_defs d on d.key = t.trophy_key
       where t.user_id = uid
       order by case d.rarity when 'mythic' then 5 when 'legendary' then 4 when 'epic' then 3 when 'rare' then 2 else 1 end desc,
                t.earned_at desc
       limit 5) x;

  select chapter, total_kills, best_score, mission_points into dk from public.darkom_progress where user_id = uid;
  select count(*) into cleared from public.darkom_mission_log where user_id = uid;

  s := public.pass_active();
  if s.id is not null then
    select xp, premium into pp from public.pass_progress where user_id = uid and season_id = s.id;
    if found then
      pass_lvl := least(s.max_level, pp.xp / s.xp_per_level);
      pass_prem := pp.premium;
    else
      pass_lvl := 0;
    end if;
  end if;

  return jsonb_build_object(
    'id', uid,
    'username', pr.username,
    'display_name', pr.display_name,
    'gamer_tag', pr.gamer_tag,
    'avatar_url', pr.avatar_url,
    'country', pr.country,
    'joined', pr.created_at,
    'followers', coalesce(pr.followers_count, 0),
    'points', pts,
    'games', played,
    'wins', wins,
    'comp_won', coalesce(pr.competitions_won, 0),
    'comp_entered', coalesce(pr.competitions_entered, 0),
    'rank', tiers[ti],
    'rank_index', ti - 1,
    'rank_next', case when ti < 8 then tiers[ti + 1] else null end,
    'rank_floor', floors[ti],
    'rank_next_floor', case when ti < 8 then floors[ti + 1] else null end,
    'house', case when hs.name is null then null else jsonb_build_object('name', hs.name, 'color', hs.banner_color) end,
    'title', title_txt,
    'name_color', name_color,
    'badges', badges,
    'darkom', jsonb_build_object(
      'chapter', coalesce(dk.chapter, 1), 'kills', coalesce(dk.total_kills, 0), 'best_score', coalesce(dk.best_score, 0),
      'mission_points', coalesce(dk.mission_points, 0), 'missions_cleared', cleared),
    'pass', case when pass_lvl is null then null else jsonb_build_object('name', s.name, 'level', pass_lvl, 'premium', pass_prem) end
  );
end;
$$;
grant execute on function public.player_card(uuid) to authenticated;

notify pgrst, 'reload schema';
