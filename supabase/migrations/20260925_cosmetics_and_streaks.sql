-- Cosmetics catalog — what exists to unlock/equip. Purely visual by
-- design; nothing here touches scoring or matchmaking.
create table if not exists cosmetic_items (
  id uuid primary key default gen_random_uuid(),
  category text not null, -- 'name_color' | 'badge' | 'avatar_frame'
  name text not null,
  value text not null, -- hex color for name_color, icon name for badge, asset ref for avatar_frame
  requires_premium boolean not null default false,
  created_at timestamptz not null default now()
);
alter table cosmetic_items enable row level security;
drop policy if exists "anyone views cosmetic items" on cosmetic_items;
create policy "anyone views cosmetic items" on cosmetic_items for select using (true);

-- What a user actually owns/has equipped. One row per user; nullable
-- columns mean "using the default look" until they equip something.
create table if not exists user_cosmetics (
  user_id uuid primary key references auth.users(id) on delete cascade,
  equipped_name_color uuid references cosmetic_items(id),
  equipped_badge uuid references cosmetic_items(id),
  equipped_avatar_frame uuid references cosmetic_items(id),
  updated_at timestamptz not null default now()
);
alter table user_cosmetics enable row level security;
drop policy if exists "anyone views cosmetics" on user_cosmetics;
create policy "anyone views cosmetics" on user_cosmetics for select using (true);
drop policy if exists "users manage own cosmetics" on user_cosmetics;
create policy "users manage own cosmetics" on user_cosmetics for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Real daily play streak — didn't exist before at all. A row is
-- upserted once per calendar day a user completes any game; the streak
-- count itself is computed from consecutive-day activity.
create table if not exists daily_play_log (
  user_id uuid not null references auth.users(id) on delete cascade,
  play_date date not null,
  primary key (user_id, play_date)
);
alter table daily_play_log enable row level security;
drop policy if exists "users log own play" on daily_play_log;
create policy "users log own play" on daily_play_log for insert with check (auth.uid() = user_id);
drop policy if exists "users view own play log" on daily_play_log;
create policy "users view own play log" on daily_play_log for select using (auth.uid() = user_id);

-- Streak freezes — premium perk, regular play only (never touches
-- competition scoring). One row per freeze a user has available/used.
create table if not exists streak_freezes (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  granted_at timestamptz not null default now(),
  used_at timestamptz,
  used_for_date date
);
alter table streak_freezes enable row level security;
drop policy if exists "users manage own freezes" on streak_freezes;
create policy "users manage own freezes" on streak_freezes for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- Returns the user's current consecutive-day streak, purely from real
-- daily_play_log activity plus any streak_freezes covering a gap day.
create or replace function get_current_streak(p_user_id uuid)
returns integer language plpgsql stable as $$
declare
  streak int := 0;
  check_date date := current_date;
begin
  loop
    if exists (select 1 from daily_play_log where user_id = p_user_id and play_date = check_date) then
      streak := streak + 1;
      check_date := check_date - 1;
    elsif exists (select 1 from streak_freezes where user_id = p_user_id and used_for_date = check_date) then
      check_date := check_date - 1; -- frozen day doesn't break the streak, doesn't add to it either
    else
      exit;
    end if;
  end loop;
  return streak;
end;
$$;

-- Starter cosmetics: a few free, a few premium-only.
insert into cosmetic_items (category, name, value, requires_premium)
select * from (values
  ('name_color', 'Default', '#FFFFFF', false),
  ('name_color', 'Cyan', '#00E5FF', false),
  ('name_color', 'Gold', '#FFD700', true),
  ('name_color', 'Violet', '#8B5CF6', true),
  ('badge', 'None', '', false),
  ('badge', 'Rising Star', 'star_rounded', false),
  ('badge', 'Premium', 'workspace_premium_rounded', true),
  ('badge', 'Champion', 'emoji_events_rounded', true),
  ('avatar_frame', 'None', '', false),
  ('avatar_frame', 'Bronze Ring', 'bronze', false),
  ('avatar_frame', 'Gold Ring', 'gold', true),
  ('avatar_frame', 'Flame', 'flame', true)
) as seed(category, name, value, requires_premium)
where not exists (select 1 from cosmetic_items limit 1);
