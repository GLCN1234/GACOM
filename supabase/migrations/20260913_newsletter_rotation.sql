-- Tracks which newsletter edition each user last received, so the daily
-- rotation knows who's still owed the current edition without needing a
-- separate join table.
alter table profiles add column if not exists newsletter_last_sent_issue_id uuid references newsletter_issues(id);

-- Move the newsletter job from a single weekly blast to a daily rotation
-- run (the edge function itself now decides each day whether to send the
-- next batch of an in-progress edition or start a new one).
select cron.schedule(
  'gacom-weekly-newsletter',
  '0 10 * * *', -- 10:00 UTC every day, not just Fridays
  $$
  select net.http_post(
    url := 'https://rxccipqvyrcfpsadgpzp.supabase.co/functions/v1/generate-and-send-newsletter',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ANON_KEY_HERE'),
    body := '{}'::jsonb
  );
  $$
);
