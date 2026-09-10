-- ── Blog automation ──────────────────────────────────────────────────────
-- Marks posts created by the weekly AI writer, so the admin dashboard can
-- badge them distinctly in the review queue (vs posts written by staff).
alter table blog_posts
  add column if not exists is_ai_generated boolean default false;

-- ── Newsletter automation ────────────────────────────────────────────────
-- Per-user opt-out flag. Defaults to true (subscribed); users can flip
-- this off from their settings screen.
alter table profiles
  add column if not exists newsletter_subscribed boolean default true;

-- Log of every newsletter issue sent — lets the admin see history and
-- avoid double-sending if the cron job is accidentally triggered twice
-- in the same week.
create table if not exists newsletter_issues (
  id uuid primary key default uuid_generate_v4(),
  subject text not null,
  html_content text not null,
  recipient_count integer default 0,
  status text default 'draft', -- draft | sending | sent | failed
  error_message text,
  sent_at timestamp with time zone,
  created_at timestamp with time zone default now()
);

alter table newsletter_issues enable row level security;
drop policy if exists "Admins manage newsletter issues" on newsletter_issues;
create policy "Admins manage newsletter issues" on newsletter_issues for all
  using (exists (select 1 from profiles where id = auth.uid() and role in ('admin','super_admin')));

-- ── Weekly cron schedules ────────────────────────────────────────────────
-- NOTE: matches the auth pattern already used by the existing
-- gacom-curriculum-queue-advance cron — the invocation itself only needs
-- a valid (anon) JWT to pass the edge gateway. Each function internally
-- uses SUPABASE_SERVICE_ROLE_KEY (auto-available in edge functions) for
-- any privileged DB writes/reads, so no service-role secret is ever
-- committed here.
--
-- Replace ANON_KEY_HERE below with your project's anon public key
-- (Settings → API → anon public) before running this migration.

-- Wednesdays 09:00 UTC — AI drafts a trending-gaming-topic blog post.
select cron.schedule(
  'gacom-weekly-blog-draft',
  '0 9 * * 3',
  $$
  select net.http_post(
    url := 'https://rxccipqvyrcfpsadgpzp.supabase.co/functions/v1/generate-weekly-blog-post',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ANON_KEY_HERE'),
    body := '{}'::jsonb
  );
  $$
);

-- Fridays 10:00 UTC — AI drafts and sends the weekly newsletter.
select cron.schedule(
  'gacom-weekly-newsletter',
  '0 10 * * 5',
  $$
  select net.http_post(
    url := 'https://rxccipqvyrcfpsadgpzp.supabase.co/functions/v1/generate-and-send-newsletter',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ANON_KEY_HERE'),
    body := '{}'::jsonb
  );
  $$
);
