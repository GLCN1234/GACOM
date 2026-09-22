-- Adds what's needed for real card auto-renewal: capturing the
-- reusable authorization from a successful card payment, and tracking
-- which channel was actually used, so the renewal job only ever
-- attempts to auto-charge card payers — transfer payers are never
-- silently auto-charged (which isn't possible anyway) and instead get
-- reminder emails.
alter table edu_subscriptions add column if not exists authorization_code text;
alter table edu_subscriptions add column if not exists payment_channel text;
alter table edu_subscriptions add column if not exists auto_renew boolean not null default false;
alter table edu_subscriptions add column if not exists last_renewal_attempt_at timestamptz;
alter table edu_subscriptions add column if not exists renewal_failed_count integer not null default 0;

-- Runs daily at 09:00 UTC (10am Lagos) — auto-renews card subscriptions
-- due, and sends reminder emails to everyone else expiring soon.
-- Replace ANON_KEY_HERE with your project's anon public key before running.
select cron.schedule(
  'gacom-subscription-renewals',
  '0 9 * * *',
  $$
  select net.http_post(
    url := 'https://rxccipqvyrcfpsadgpzp.supabase.co/functions/v1/process-subscription-renewals',
    headers := jsonb_build_object('Content-Type', 'application/json', 'Authorization', 'Bearer ANON_KEY_HERE'),
    body := '{}'::jsonb
  );
  $$
);
