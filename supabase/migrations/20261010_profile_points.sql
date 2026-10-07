-- Total points a player has gathered across every game (Arena, Edu and the
-- game store), read by the profile page.
create or replace function public.user_game_totals(p_user uuid)
returns table (total_points bigint, games_played bigint, wins bigint)
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(greatest(score, 0)), 0)::bigint,
         count(*)::bigint,
         count(*) filter (where won is true)::bigint
    from public.game_scores
   where user_id = p_user;
$$;

grant execute on function public.user_game_totals(uuid) to authenticated;


notify pgrst, 'reload schema';
