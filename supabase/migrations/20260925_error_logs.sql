-- Every crash the friendly error screen catches also gets logged here,
-- so admins/developers can see real error descriptions instead of
-- relying on users sending screenshots.
create table if not exists error_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references auth.users(id) on delete set null,
  error text not null,
  stack text,
  route text,
  created_at timestamptz not null default now()
);
alter table error_logs enable row level security;

drop policy if exists "anyone logs errors" on error_logs;
create policy "anyone logs errors" on error_logs for insert with check (true);

drop policy if exists "admins view error logs" on error_logs;
create policy "admins view error logs" on error_logs for select
  using (exists (select 1 from profiles p where p.id = auth.uid() and p.role in ('admin', 'super_admin')));

create index if not exists error_logs_created_idx on error_logs (created_at desc);
