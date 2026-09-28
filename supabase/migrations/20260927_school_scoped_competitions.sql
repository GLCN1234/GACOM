-- Competitions can now be scoped to one school (institution_id set) or
-- open to everyone (institution_id null) — same competitions table,
-- one additional optional field, same pattern as the target_score
-- race format added earlier.
alter table competitions add column if not exists institution_id uuid references institutions(id);

-- Standings for a competition, respecting its institution scope when
-- set. Replaces doing this filter in Dart, since filtering by a joined
-- table's column (student_institutions) isn't something a simple
-- PostgREST query handles cleanly.
create or replace function get_competition_standings(p_competition_id uuid)
returns table(user_id uuid, display_name text, avatar_url text, score integer, created_at timestamptz)
language sql stable as $$
  select gs.user_id, p.display_name, p.avatar_url, gs.score, gs.created_at
  from game_scores gs
  join competitions c on c.id = p_competition_id
  join profiles p on p.id = gs.user_id
  where gs.game_name = c.game_name
    and gs.created_at >= c.starts_at
    and gs.created_at <= c.ends_at
    and (
      c.institution_id is null
      or exists (
        select 1 from student_institutions si
        where si.student_id = gs.user_id and si.institution_id = c.institution_id
      )
    )
  order by gs.score desc
  limit 10;
$$;

-- Top scores for a game, scoped to one school — the "My School"
-- leaderboard view. Same shape as the existing global leaderboard
-- query, just filtered through student_institutions.
create or replace function get_school_leaderboard(p_game_name text, p_institution_id uuid)
returns table(user_id uuid, display_name text, avatar_url text, score integer, won boolean, created_at timestamptz)
language sql stable as $$
  select gs.user_id, p.display_name, p.avatar_url, gs.score, gs.won, gs.created_at
  from game_scores gs
  join profiles p on p.id = gs.user_id
  join student_institutions si on si.student_id = gs.user_id
  where gs.game_name = p_game_name and si.institution_id = p_institution_id
  order by gs.score desc
  limit 10;
$$;
