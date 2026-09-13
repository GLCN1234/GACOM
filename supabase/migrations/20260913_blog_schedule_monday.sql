-- Moves the weekly AI blog draft from Wednesday 09:00 UTC to Monday
-- 21:00 UTC (10:00 PM Lagos/WAT time, which is UTC+1).
-- cron.schedule() upserts by job name, so calling it again with the same
-- name updates the existing job's schedule rather than creating a
-- duplicate — no need to unschedule the old one first.

select cron.schedule(
  'gacom-weekly-blog-draft',
  '0 21 * * 1', -- 21:00 UTC every Monday = 10:00 PM Lagos time
  $$
  select net.http_post(
    url := 'https://rxccipqvyrcfpsadgpzp.supabase.co/functions/v1/generate-weekly-blog-post',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ANON_KEY_HERE'),
    body := '{}'::jsonb
  );
  $$
);
