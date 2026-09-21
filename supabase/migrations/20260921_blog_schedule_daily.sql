-- Moves the AI blog draft from once a week (Monday) to every day, same
-- time (21:00 UTC / 10pm Lagos). cron.schedule() upserts by job name, so
-- this updates the existing job rather than creating a duplicate.

select cron.schedule(
  'gacom-weekly-blog-draft',
  '0 21 * * *', -- 21:00 UTC every day = 10:00 PM Lagos time
  $$
  select net.http_post(
    url := 'https://rxccipqvyrcfpsadgpzp.supabase.co/functions/v1/generate-weekly-blog-post',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ANON_KEY_HERE'),
    body := '{}'::jsonb
  );
  $$
);
