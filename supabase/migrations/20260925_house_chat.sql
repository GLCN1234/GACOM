-- Real house chat — only members of a house can read or post in it.
-- Realtime is enabled on this table (last statement below) so messages
-- appear live, using the exact same .stream() pattern already proven
-- working for live match updates elsewhere in the app.
create table if not exists house_messages (
  id uuid primary key default gen_random_uuid(),
  house_id uuid not null references houses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  message text not null,
  created_at timestamptz not null default now()
);
alter table house_messages enable row level security;

drop policy if exists "members read house messages" on house_messages;
create policy "members read house messages" on house_messages for select
  using (exists (select 1 from house_members hm where hm.house_id = house_messages.house_id and hm.user_id = auth.uid()));

drop policy if exists "members post house messages" on house_messages;
create policy "members post house messages" on house_messages for insert
  with check (
    auth.uid() = user_id
    and exists (select 1 from house_members hm where hm.house_id = house_messages.house_id and hm.user_id = auth.uid())
  );

create index if not exists house_messages_house_idx on house_messages (house_id, created_at);

do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname='supabase_realtime' and tablename='house_messages') then
    alter publication supabase_realtime add table public.house_messages;
  end if;
end $$;
