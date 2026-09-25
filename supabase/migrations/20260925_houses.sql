-- Houses — subscriber-founded clans with their own identity and
-- sub-leaderboard. Optionally tied to a school (institution_id) to
-- match existing school house structures like BBHS's; null means a
-- platform-wide house anyone can join regardless of school.
create table if not exists houses (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  banner_color text not null default '#E84B00',
  institution_id uuid references institutions(id),
  captain_id uuid not null references auth.users(id),
  created_at timestamptz not null default now()
);
alter table houses enable row level security;
drop policy if exists "anyone views houses" on houses;
create policy "anyone views houses" on houses for select using (true);
drop policy if exists "captains manage own house" on houses;
create policy "captains manage own house" on houses for update
  using (auth.uid() = captain_id) with check (auth.uid() = captain_id);
drop policy if exists "captains delete own house" on houses;
create policy "captains delete own house" on houses for delete using (auth.uid() = captain_id);
-- Insert permission is intentionally NOT granted broadly here — creating
-- a house requires premium, checked in the app before the insert is
-- ever attempted, same pattern as cosmetics. A signed-in check alone
-- would let anyone found a house, so this policy is deliberately
-- narrower than the others on this table.
drop policy if exists "signed in users create houses" on houses;
create policy "signed in users create houses" on houses for insert
  with check (auth.uid() = captain_id);

create table if not exists house_members (
  house_id uuid not null references houses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (house_id, user_id)
);
alter table house_members enable row level security;
drop policy if exists "anyone views house members" on house_members;
create policy "anyone views house members" on house_members for select using (true);
drop policy if exists "users join houses" on house_members;
create policy "users join houses" on house_members for insert with check (auth.uid() = user_id);
drop policy if exists "users leave houses" on house_members;
create policy "users leave houses" on house_members for delete using (auth.uid() = user_id);

-- A house's total sub-leaderboard points — sum of every member's
-- game_scores, computed live rather than stored, so it's always
-- correct without needing a trigger to keep it in sync.
create or replace function get_house_points(p_house_id uuid)
returns integer language sql stable as $$
  select coalesce(sum(gs.score), 0)::int
  from game_scores gs
  join house_members hm on hm.user_id = gs.user_id
  where hm.house_id = p_house_id;
$$;
