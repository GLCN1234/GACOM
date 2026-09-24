-- Extends the existing competitions table with a score-threshold race
-- format ("first to reach 1000 points") alongside its existing
-- bracket-tournament format — same table, an additional optional field,
-- since a lot of the existing infra (title, game_name, dates, status)
-- already fits this use case exactly.
alter table competitions add column if not exists target_score integer;
alter table competitions add column if not exists winning_score_id uuid references game_scores(id);

-- Real-time check: has anyone hit the target since this competition
-- started? Called by the app to determine/display the current winner
-- without needing a cron job — the race is decided the moment someone's
-- score crosses target_score during the active window.
create or replace function get_competition_winner(p_competition_id uuid)
returns table(user_id uuid, score integer, achieved_at timestamptz)
language sql stable as $$
  select gs.user_id, gs.score, gs.created_at
  from game_scores gs
  join competitions c on c.id = p_competition_id
  where gs.game_name = c.game_name
    and c.target_score is not null
    and gs.score >= c.target_score
    and gs.created_at >= c.starts_at
    and gs.created_at <= c.ends_at
  order by gs.created_at asc
  limit 1;
$$;
