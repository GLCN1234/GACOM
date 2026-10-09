# GACOM application security audit

Scope: Supabase edge functions, Flutter client (lib/, android/, web/), Netlify config.
Not covered: RLS policies and SQL function bodies that live only in the live database (not in this repo), iOS project files.
Status key: FIXED (in this change), OWNER (needs you to run/deploy/decide), OPEN (reported, not changed).

## Findings

| # | Sev | Finding | Impact | Fix | Status |
|---|-----|---------|--------|-----|--------|
| 1 | Critical | `profiles` UPDATE policy is `USING (auth.uid() = id)` with no column limit (001 and 003 migrations). | Any signed-in user can PATCH their own row: set `role` to `super_admin`, `wallet_balance` to any number, unban themselves, self-verify. Every server-side role check is bypassed. | Implemented once, in `20261020_security_hardening.sql` (`sec_profiles_guard`; `20261020_profile_and_wallet_guards.sql` is now a no-op): rejects changes to role, is_banned, KYC, counters and verification approval from the `authenticated`/`anon` DB roles, and keeps wallet columns unchanged. SECURITY DEFINER RPCs and the service role are unaffected. | OWNER: apply migration |
| 2 | Critical | Paid competition entry was done by the client: it inserted the participant row and wrote `wallet_balance` itself. | Free entry to paid competitions; arbitrary wallet edits. | New `join_paid_competition()` RPC (atomic, row-locked, server-priced). Dart now calls it. `sec_participants_guard` blocks hand-made `paid` rows and any direct insert into a paid competition (RPC lives in `20261020_security_hardening.sql`). | FIXED in code, OWNER: apply migration |
| 3 | Critical | `arena-payout` had no authentication and trusted client amounts. | Anyone on the internet could pay any user. | Requires JWT, caller must be a match player or admin, amounts recomputed from `arena_matches` and `arena_settings`, status compare-and-swap before money moves, idempotency reference `ARENA_WIN_<match>`, rollback if the credit fails. | FIXED (previous run, reviewed) |
| 4 | High | `refund_arena_stake(p_user_id, p_amount, p_reference)` and `deduct_arena_stake(...)` are called directly from the client (`arena_service.dart`). Bodies are not in the repo. If executable by `authenticated` and not checking `auth.uid()`, any user can credit any wallet or debit another user's. | Money creation / griefing. | Cannot be fixed from this repo. Verify in SQL editor: `select proname, proacl from pg_proc where proname in ('refund_arena_stake','deduct_arena_stake');` Then either revoke execute from `authenticated` and move refund-on-failure server side, or make both functions use `auth.uid()` and reject a different `p_user_id` when `current_user = 'authenticated'`. Also confirm `refund_arena_stake` is idempotent on `p_reference` (arena-payout relies on it). | OWNER: verify and fix |
| 5 | High | `paystack-verify` had no authentication and `Access-Control-Allow-Origin: *`; it echoed raw errors. | Anyone could trigger crediting for any reference; internals leaked. | JWT required, reference must belong to the caller (`wallet_transactions` or `edu_subscriptions`), amount is Paystack's confirmed amount, Edu amount checked against the stored row, generic errors. | FIXED |
| 6 | High | No Paystack webhook, so a paid user depends on the browser returning. | Lost credits. | New `paystack-webhook`: HMAC-SHA512 of the raw body vs `x-paystack-signature` (constant time), amount re-confirmed via the verify API, idempotent credit. Deploy with `--no-verify-jwt`. | FIXED, OWNER: deploy + set URL |
| 7 | High | Cron functions (`ai-product-scout`, `generate-weekly-blog-post`, `generate-and-send-newsletter`, `process-subscription-renewals`, and the `advance_*` modes of the curriculum functions) were callable by anyone; the cron jobs authenticate with the PUBLIC anon key. | Anyone could burn AI quota, spam the whole user base with a newsletter, trigger card charges. | `requireCronOrAdmin`: needs `x-cron-secret` = `CRON_SECRET` or an admin session. The anon key no longer works. | FIXED, OWNER: update the pg_cron jobs (below) or they will return 401 |
| 8 | High | `create-institution-user` created or reset any account password; `livekit-token` let any user join any match room; `notify-order-received` let anyone email staff about any order; `chess-tutor` was an open Gemini proxy. | Account takeover of non-admin accounts, eavesdropping, spam, quota theft. | Admin-only with email/password validation and refusal to convert admin/privileged accounts; match rooms limited to the two players; order must belong to caller, HTML escaped; chess-tutor needs JWT, validated fields, key in header. | FIXED |
| 9 | High | `seed-demo-authors` and `seed-game-icons` were open to the internet. `seed-demo-authors` creates 40 auth users per call. | Auth table spam, cost. | Refuse unless `ALLOW_SEED_FUNCTIONS=true` AND (admin session OR `x-seed-secret` = `SEED_SECRET`). Rate limited. | FIXED (off by default) |
| 10 | High | `extract-and-segment-curriculum` / `generate-curriculum-games` accepted any caller, any `institution_id` and `uploaded_by`, unbounded PDF and prompt text. | Quota theft, writing into other institutions, prompt injection. | Role institution/admin; institution users limited to their own institution via `app_metadata.institution_id` (service-role-only field); PDF magic bytes, size and chunk caps; user text wrapped as untrusted. | FIXED, OWNER: re-run create-institution-user for existing institutions so `app_metadata` is set |
| 11 | Medium | `apple-verify`: now fetches the signed transaction from Apple's server API, binds it to the JWT user, checks bundle id, product, refund, sandbox gating. | Fake receipts / account transfer. | Reviewed and kept. `APPLE_ALLOW_SANDBOX` must stay unset in production. | FIXED (previous run, reviewed) |
| 12 | Medium | Model output stored or emailed as HTML (newsletter, blog) and `source_url` from a model. | Stored XSS / phishing links in emails and blog. | `sanitizeBasicHtml` allow-list, `safeHttpsUrlOrNull` for URLs. | FIXED |
| 13 | Medium | CORS `*` on every function; stack traces and upstream bodies returned (`String(err)`); Gemini key in the URL query string. | Info leak, key in logs. | `secureServe` wrapper: allow-list CORS, generic errors with a request id, key moved to `x-goog-api-key`, `redact()` on every logged error. | FIXED |
| 14 | Medium | Client router had no guard for `/admin*` or `/exco-dashboard`. | Admin UI reachable by deep link (data still protected by RLS). | Redirect guard reads the role from `profiles` (not editable `userMetadata`), fails closed. `/admin/support` also admits support staff roles. | FIXED (UI only; server remains authoritative) |
| 15 | Medium | Android: `allowBackup` and cleartext not set; web: no security headers; wildcard CORS on all of netlify. | Backup extraction of app data; clickjacking, MIME sniffing. | `allowBackup=false`, `usesCleartextTraffic=false`; HSTS, nosniff, Referrer-Policy, X-Frame-Options, Permissions-Policy, COOP, CSP Report-Only; wildcard CORS limited to static assets. | FIXED |
| 16 | Medium | `launchUrl` on server/user supplied URLs (blog links, game `play_url`, mission links) with no scheme check. | `javascript:`/`intent:`/`file:` links. | `safeHttpsUri()` helper, https only. | FIXED |
| 17 | Medium | Self-update trusts `full_url`/`arm64_url` from `latest.json`. App also holds `REQUEST_INSTALL_PACKAGES`. | If the release bucket is writable by a wrong party, malware download prompt (Android still enforces same-signature on update). | Download URLs must start with the release bucket prefix. Make sure `app-releases` is not publicly writable. | FIXED (partly) / OWNER: check bucket policy |
| 18 | Medium | `lib/utils/constants.dart` had a `paystackSecretKey` field (placeholder, unused). | Invites pasting a real secret into the client. | Removed. | FIXED |
| 19 | Medium | Cart builds the order total from client-side prices (`cart_screen.dart`) and inserts into `orders` directly. | A modified client can pay less than list price. | Needs a server RPC that prices items from `products` and computes delivery. Not changed (large flow). | OPEN |
| 20 | Medium | `node_modules/` (683 files) is tracked in git. | Supply-chain noise, stale vendored code. | `git rm -r --cached node_modules` and add to .gitignore (root `package.json` only lists supabase-js). | OPEN |
| 21 | Low | Password reset redirect `https://gacom.gg/reset-password` differs from the site domain `gamicom.net`; `institution` routing reads editable `userMetadata`. | Reset links may land on a domain you do not control; routing only, not authorisation. | Confirm the domain and the Supabase Auth redirect allow-list. | OPEN |
| 22 | Low | Dependencies: Flutter packages use caret ranges and there is no `pubspec.lock` in the repo. Edge functions import `jsr:@zaubrik/djwt` and `npm:unpdf` unpinned. | Unreviewed upgrades. | Commit `pubspec.lock`; pin `@zaubrik/djwt@x.y.z` and `unpdf@x.y.z`. Run `flutter pub outdated` / `npm audit` in CI. | OPEN (report only) |
| 23 | Info | Anon JWT (`role: anon`) and `pk_live_...` public key are committed in `app_constants.dart`. | Not secrets; expected in a client. | None. | OK |

Known limit: `arena-payout` winner is still reported by a player client. Real fix is a server-computed result or both players reporting the same winner.

## Secret scan (tracked files and full git history)

Patterns: `sk_live/test`, `pk_live/test`, JWTs, `gsk_`, `AIza`, `re_`, private key blocks, service-role assignments. Values are not printed.

| Where | What | Verdict |
|-------|------|---------|
| lib/core/constants/app_constants.dart, gacom_proxy_fix/lib/core/constants/app_constants.dart (commit d0ae099 and earlier) | JWT with `role: anon`, project ref rxccipqvyrcfpsadgpzp | Public by design, no rotation needed |
| same files | `pk_live_...` Paystack PUBLIC key | Public by design |
| gacom_fix5/import_users.js | Text mentions "service_role" only, no value | OK |
| lib/utils/constants.dart | placeholder strings only | OK, secret field removed |
| Any `sk_`, `gsk_`, `AIza`, `re_`, `BEGIN PRIVATE KEY`, service-role JWT | none found in tracked files or history | Nothing to rotate on this evidence |

Caveat: this scan covers what is in git. If a secret was ever pasted in chat, a CI log, or the Netlify build log, rotate it anyway. `build.sh` passes only public values via `--dart-define`.

## Owner steps (in order)

1. Apply `supabase/migrations/20261020_security_hardening.sql` (the guards file is a no-op now; then `20261021_support_lead_members.sql`). Test: as a normal user `update profiles set role='admin'` must fail; paid competition join must still work.
2. Check finding 4 (`refund_arena_stake` / `deduct_arena_stake` grants and bodies).
3. Set secrets (never commit them):
   ```
   supabase secrets set ALLOWED_ORIGINS="https://gamicom.net,https://www.gamicom.net,https://gamicom.netlify.app"
   supabase secrets set CRON_SECRET="$(openssl rand -hex 32)"
   supabase secrets set PAYSTACK_SECRET_KEY=sk_live_...        # same key; the webhook uses it to verify signatures
   supabase secrets set APPLE_ISSUER_ID=... APPLE_KEY_ID=... APPLE_BUNDLE_ID=com.mobtechsynergies.gacom
   supabase secrets set APPLE_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)"
   ```
   `ALLOWED_ORIGINS` defaults to gamicom.net, www.gamicom.net and localhost if unset. Mobile apps send no Origin and are unaffected. Do NOT set `ALLOW_SEED_FUNCTIONS` or `APPLE_ALLOW_SANDBOX` in production (set `APPLE_ALLOW_SANDBOX=true` only during App Review / TestFlight, then remove).
   There is no stored Apple "shared secret": the App Store Server API key (issuer, key id, .p8) above replaces it. If you still use legacy receipt validation anywhere, rotate that shared secret in App Store Connect.
4. Paystack dashboard: Settings > API Keys & Webhooks > Webhook URL = `https://rxccipqvyrcfpsadgpzp.supabase.co/functions/v1/paystack-webhook`. Deploy it with `supabase functions deploy paystack-webhook --no-verify-jwt`.
5. Update the pg_cron jobs so they send the cron secret instead of relying on the anon key (store the secret in Vault, do not paste it into a migration that is committed):
   ```sql
   select cron.alter_job(job_id := jobid, command := replace(command,
     'headers := jsonb_build_object(''Content-Type'', ''application/json'', ''Authorization'', ''Bearer ANON_KEY_HERE'')',
     'headers := jsonb_build_object(''Content-Type'', ''application/json'', ''x-cron-secret'', (select decrypted_secret from vault.decrypted_secrets where name = ''cron_secret''))'))
   from cron.job where command like '%functions/v1/%';
   ```
   (Create the vault secret first: `select vault.create_secret('<same value as CRON_SECRET>', 'cron_secret');`. Check each job's actual header text with `select jobname, command from cron.job;` since older jobs embed the real anon key.) The curriculum jobs that call `advance_queue` / `advance_segmentation` need the same header.
6. Deploy all changed functions: `supabase functions deploy` (paystack-webhook with `--no-verify-jwt`).
7. Re-run `create-institution-user` once per existing institution (admin dashboard) so their accounts get `app_metadata.institution_id`.
8. Netlify: deploy; watch the browser console for `[Report Only]` CSP lines for a week, then rename `Content-Security-Policy-Report-Only` to `Content-Security-Policy` in netlify.toml (steps are in the file comments).
9. Rotate anything that has ever been shared outside Supabase secrets: Paystack secret, Groq, Gemini, Resend, Unsplash, LiveKit, service-role key, Apple .p8. Rotation of the anon key and `pk_live` is not required.
10. Remove `node_modules` from git (finding 20) and commit `pubspec.lock`.

## What was checked per function

| Function | Identity | Authorisation | Other |
|----------|----------|---------------|-------|
| admin-product-action | JWT | admin role from profiles | column allow-list, https image URLs |
| apple-verify | JWT | purchase bound to caller | Apple server fetch, bundle/product/refund/env checks |
| arena-payout | JWT | player or admin | server amounts, CAS, idempotency, rollback |
| paystack-init | JWT (email from session) | n/a | amount bounds, callback allow-list |
| paystack-verify | JWT | reference ownership | Paystack-confirmed amount |
| paystack-webhook | HMAC-SHA512 signature | n/a | constant-time compare, verify API |
| create-institution-user | JWT | admin | refuses privileged targets |
| livekit-token | JWT | match player / house or squad member | validated room names |
| notify-order-received | JWT | order owner or admin | HTML escaped, rate limited |
| chess-tutor | JWT | n/a | validated inputs, header key |
| curriculum functions | JWT or cron secret | institution owner / admin | size caps, untrusted wrapping |
| ai-product-scout, blog, newsletter, renewals | cron secret or admin | n/a | sanitised model output |
| seed-* | admin or seed secret | disabled unless `ALLOW_SEED_FUNCTIONS=true` | rate limited |
| support-assistant | owned by another agent | not reviewed here | |
