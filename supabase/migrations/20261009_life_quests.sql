-- Life Quests: story lessons for Edu. Four quests ship inside the app.
-- Extra quests can be added here as rows and appear without an app update.

create table if not exists public.life_quests (
  id text primary key,
  data jsonb not null,
  published boolean not null default false,
  created_at timestamptz not null default now()
);

alter table public.life_quests enable row level security;

drop policy if exists life_quests_read on public.life_quests;
create policy life_quests_read on public.life_quests
  for select to authenticated using (published = true);

grant select on public.life_quests to authenticated;

create table if not exists public.life_quest_progress (
  user_id uuid not null references public.profiles(id) on delete cascade,
  quest_id text not null,
  best_stars integer not null default 0,
  plays integer not null default 0,
  last_played timestamptz not null default now(),
  primary key (user_id, quest_id)
);

alter table public.life_quest_progress enable row level security;

drop policy if exists life_quest_progress_own_read on public.life_quest_progress;
create policy life_quest_progress_own_read on public.life_quest_progress
  for select to authenticated using (user_id = auth.uid());

drop policy if exists life_quest_progress_own_insert on public.life_quest_progress;
create policy life_quest_progress_own_insert on public.life_quest_progress
  for insert to authenticated with check (user_id = auth.uid());

drop policy if exists life_quest_progress_own_update on public.life_quest_progress;
create policy life_quest_progress_own_update on public.life_quest_progress
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select, insert, update on public.life_quest_progress to authenticated;


notify pgrst, 'reload schema';
