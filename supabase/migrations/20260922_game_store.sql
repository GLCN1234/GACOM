-- Real, database-backed game store listings — replaces the fully
-- hardcoded list in game_store_screen.dart. Covers both GACOM's own
-- built-in games and games developers submit for review.
create table if not exists game_listings (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  tagline text, -- short one-line description shown on cards
  description text, -- full description shown on the detail page
  icon_url text,
  screenshots text[] default array[]::text[],
  category text not null default 'Arcade', -- Puzzle, Action, Strategy, Board, Arcade, Card, Educational
  developer_name text not null default 'GACOM',
  developer_id uuid references auth.users(id),
  play_route text, -- internal app route for GACOM's own built-in games
  play_url text, -- external URL for developer-submitted web games, if not an internal route
  is_gacom_official boolean not null default false,
  status text not null default 'pending', -- 'pending' | 'approved' | 'rejected'
  rating numeric default 0,
  rating_count integer default 0,
  is_featured boolean not null default false,
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);
alter table game_listings enable row level security;

-- Anyone can see approved listings (the actual store front).
drop policy if exists "anyone views approved games" on game_listings;
create policy "anyone views approved games" on game_listings for select
  using (status = 'approved' or developer_id = auth.uid());

-- Any signed-in user can submit a game (lands as 'pending').
drop policy if exists "users submit games" on game_listings;
create policy "users submit games" on game_listings for insert
  with check (auth.uid() = developer_id and status = 'pending');

-- Admins insert approved games directly (e.g. when approving a developer
-- application) — a separate, additional policy, since the one above only
-- covers a user submitting their own pending entry.
drop policy if exists "admins insert any game" on game_listings;
create policy "admins insert any game" on game_listings for insert
  with check (exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('admin', 'super_admin')));

-- Admins review (approve/reject) anything.
drop policy if exists "admins manage all games" on game_listings;
create policy "admins manage all games" on game_listings for update
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('admin', 'super_admin')))
  with check (exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('admin', 'super_admin')));

-- Real per-user ratings, not just hand-edited aggregate numbers — one
-- rating per user per game (they can change it later), with the
-- aggregate on game_listings kept correct automatically via trigger.
create table if not exists game_ratings (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references game_listings(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rating integer not null check (rating >= 1 and rating <= 5),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(game_id, user_id)
);
alter table game_ratings enable row level security;
drop policy if exists "anyone views ratings" on game_ratings;
create policy "anyone views ratings" on game_ratings for select using (true);
drop policy if exists "users insert own rating" on game_ratings;
create policy "users insert own rating" on game_ratings for insert with check (auth.uid() = user_id);
drop policy if exists "users update own rating" on game_ratings;
create policy "users update own rating" on game_ratings for update using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Security definer so the trigger can update game_listings.rating even
-- though the rating user themselves has no direct UPDATE permission on
-- that table — only on their own row in game_ratings.
create or replace function update_game_rating_aggregate() returns trigger
language plpgsql security definer as $$
begin
  update game_listings set
    rating = (select coalesce(avg(rating), 0) from game_ratings where game_id = coalesce(new.game_id, old.game_id)),
    rating_count = (select count(*) from game_ratings where game_id = coalesce(new.game_id, old.game_id))
  where id = coalesce(new.game_id, old.game_id);
  return coalesce(new, old);
end;
$$;

drop trigger if exists game_rating_aggregate_trigger on game_ratings;
create trigger game_rating_aggregate_trigger
after insert or update or delete on game_ratings
for each row execute function update_game_rating_aggregate();
-- source instead of a hardcoded list plus a separate database table.
-- Safe to re-run: only inserts if the table is still empty.
insert into game_listings (name, tagline, category, developer_name, play_route, is_gacom_official, status, is_featured)
select * from (values
  ('Chess', 'Alpha-beta AI engine, full rules', 'Strategy', 'GACOM', '/arena/practice/chess', true, 'approved', true),
  ('Tic-Tac-Toe', 'Unbeatable minimax AI', 'Board', 'GACOM', '/arena/practice/tictactoe', true, 'approved', false),
  ('RPS Battle', 'Best of 5 — Rock Paper Scissors', 'Arcade', 'GACOM', '/arena/practice/rps', true, 'approved', false),
  ('Trivia', '10 questions, race the clock', 'Educational', 'GACOM', '/arena/practice/trivia', true, 'approved', false),
  ('Reaction', 'Tap fastest, pure reflexes', 'Arcade', 'GACOM', '/arena/practice/reaction', true, 'approved', false),
  ('Connect Four', '4 in a row vs AI', 'Board', 'GACOM', '/arena/practice/connect4', true, 'approved', false),
  ('Reversi', 'Flip tiles, own the board', 'Board', 'GACOM', '/arena/practice/reversi', true, 'approved', false),
  ('Memory Match', 'Flip and match all pairs', 'Puzzle', 'GACOM', '/arena/practice/memory', true, 'approved', false),
  ('Word Scramble', 'Unscramble the hidden word', 'Puzzle', 'GACOM', '/arena/practice/wordscramble', true, 'approved', false),
  ('2048', 'Slide tiles, reach 2048', 'Puzzle', 'GACOM', '/arena/practice/2048', true, 'approved', true),
  ('Hangman', 'Guess the word before time runs out', 'Card', 'GACOM', '/arena/practice/hangman', true, 'approved', false),
  ('Speed Math', 'Solve equations before the timer', 'Educational', 'GACOM', '/arena/practice/speedmath', true, 'approved', false),
  ('Simon Says', 'Watch and repeat the sequence', 'Puzzle', 'GACOM', '/arena/practice/simon', true, 'approved', false),
  ('Minesweeper', 'Clear the field, avoid the mines', 'Puzzle', 'GACOM', '/arena/practice/minesweeper', true, 'approved', false),
  ('Blackjack', 'Beat the dealer to 21', 'Card', 'GACOM', '/arena/practice/blackjack', true, 'approved', false),
  ('Dots & Boxes', 'Claim the most boxes vs AI', 'Board', 'GACOM', '/arena/practice/dotsboxes', true, 'approved', false),
  ('Number Duel', 'Race the AI — solve maths first', 'Educational', 'GACOM', '/arena/practice/numberduel', true, 'approved', false),
  ('Snake', 'Classic snake — grow as long as you can', 'Arcade', 'GACOM', '/arena/practice/snake', true, 'approved', false),
  ('Survival Shooter', 'Move, auto-fire, survive the waves', 'Action', 'GACOM', '/arena/store/survival', true, 'approved', true)
) as seed(name, tagline, category, developer_name, play_route, is_gacom_official, status, is_featured)
where not exists (select 1 from game_listings limit 1);
