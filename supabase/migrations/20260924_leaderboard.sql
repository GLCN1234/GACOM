-- Every completed game session's final score, per user per game — the
-- foundation both the leaderboard (top scores across everyone) and the
-- personal scorecard (a user's own history) read from. Practice games
-- currently track a score locally and just discard it when the game
-- ends; this is what actually persists it.
create table if not exists game_scores (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  game_name text not null, -- matches the name shown in the game store, e.g. 'Chess', '2048', 'Whot'
  score integer not null default 0,
  won boolean, -- null for score-based games with no explicit win/loss (e.g. 2048), true/false for head-to-head ones
  created_at timestamptz not null default now()
);
alter table game_scores enable row level security;

drop policy if exists "anyone views scores" on game_scores;
create policy "anyone views scores" on game_scores for select using (true);
drop policy if exists "users insert own scores" on game_scores;
create policy "users insert own scores" on game_scores for insert with check (auth.uid() = user_id);

create index if not exists game_scores_leaderboard_idx on game_scores (game_name, score desc);
create index if not exists game_scores_user_idx on game_scores (user_id, game_name);
