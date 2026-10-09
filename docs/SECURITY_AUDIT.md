# GACOM database security audit

Scope: every table, policy, function, view, storage bucket and realtime publication created by `supabase/migrations/` (001 to 20261019), plus the client calls in `lib/` that depend on them. Fixes are in `supabase/migrations/20261020_security_hardening.sql` (applies last, idempotent, safe to re-run).

## Method

1. Built the full schema on local Postgres 16 (scratch db `idt_sec`), applied every migration in filename order, then `20261018_security_center.sql` and `20261019_support_desk.sql`. Prerequisites that never lived in the repo were stubbed: `auth.*`, the three Supabase roles, `storage.*`, plus stand-ins for `institutions`, `student_institutions`, `edu_subscriptions` and, worst case, the production-only functions `deduct_arena_stake`, `refund_arena_stake`, `credit_wallet_from_reference`, `approve_withdrawal`, `reject_withdrawal`.
2. Catalog queries: RLS flag, `true` policies, column privileges, `SECURITY DEFINER` without `search_path`, EXECUTE for `anon`, views, buckets, publication membership.
3. Read every function that takes a user id, moves value, or grants rewards.
4. Real attacks as `set role authenticated` / `set role anon` with forged `request.jwt.claims`, run before and after the migration (section 3).
5. Cross-checked `lib/` for every `.rpc(...)` and `.from(...)` so legitimate calls keep working (section 4 lists the ones that need an app update).

## 1. Summary

| Severity | Count | Findings |
|---|---|---|
| Critical | 5 | SEC-01, 04, 06, 09, 18 |
| High | 11 | SEC-02, 03, 05, 07, 08, 12, 13, 15, 21, 22, 24 |
| Medium | 8 | SEC-10, 11, 14, 16, 19, 20, 23, 25 |
| Low | 2 | SEC-17, 26 |

Worst three, in plain words:
1. Any signed-in user could edit their own `profiles` row, so they could make themselves super admin, set their wallet to any amount, or mark themselves verified (SEC-01). Related: the client-callable `refund_arena_stake` / `deduct_arena_stake` took a user id and an amount, so anyone could credit themselves or empty someone else's wallet (SEC-04).
2. Anyone, even logged out, could read every institution's login password (SEC-18), and any signed-in user could add themselves to someone else's private chat and read it (SEC-09).
3. Withdrawals were not tied to the balance and `approve_withdrawal` had no staff check in the code we could test (SEC-06).

## 2. Findings

Format: id, severity, what an attacker could do, fix, how tested.

### Critical

**SEC-01 profiles self-escalation (Critical).** Policy `profiles_update` is `auth.uid() = id` with full-table UPDATE privilege. Attacker: `update profiles set role='super_admin', is_admin=true, wallet_balance=1e6, verification_status='verified'`. Fix: column-level UPDATE grant (no role, is_admin, ban, KYC url, counters), plus `sec_profiles_guard` trigger that rejects changes to protected columns from any client role and only allows `verification_status` to move to `pending`. Wallet columns are reverted silently (see SEC-05 for why). Staff actions moved to audited RPCs `admin_set_user_role` (only a super admin can touch admin roles, no self change), `admin_set_user_ban`, `admin_set_verification`. Tested: A1, A2, A3.

**SEC-04 arena stake RPCs callable by clients (Critical).** `refund_arena_stake(p_user_id, p_amount, ref)` and `deduct_arena_stake(...)` are called from `lib/features/arena/services/arena_service.dart` with a user id the client supplies. Attacker credits themselves any amount or debits another player. These functions are not in the repo (production only), so their bodies are unverified. Fix: EXECUTE revoked from `anon`/`authenticated`; they remain callable from SECURITY DEFINER code (duels, shop, houses), which is how every in-repo caller uses them. New `arena_deduct_my_stake(amount, reference)` debits only `auth.uid()`. Tested: A5a, A5b. App change needed: section 4.

**SEC-06 withdrawals (Critical).** Policy `users_own_withdrawals` was `FOR ALL` for the owner: attacker inserts a request for any amount with `status='approved'`, or flips their own row to approved. `approve_withdrawal` / `reject_withdrawal` (production only) were callable by anyone with no verifiable staff check. Fix: separate select/insert/update policies (update only admin or finance_team exco), `sec_withdrawal_guard` (status forced to `pending`, amount must fit balance minus pending requests, 5 per hour, staff cannot change amount or owner), and the two RPCs are patched at migration time to refuse anyone who is not admin or finance_team (skipped with a notice if they are not plpgsql). Tested: A12a, A12b, X8.

**SEC-09 chat takeover (Critical).** `chat_members` INSERT `with check (true)` (twice) and `chats` INSERT `with check (true)`: add yourself to any chat id, then `messages_select` returns its history. Fix: members can only be added by the chat creator (`sec_chat_creator`), rate limited; chat type/owner immutable; legacy self-referential `gacom_chat_members_select` / `gacom_chats_select` dropped (they also caused "infinite recursion" on `UPDATE chats`, a live functional bug). Tested: A6, S7.

**SEC-18 institution passwords public (Critical).** `institutions` is `select using (true)` and holds `login_code`, which `create-institution-user` uses as the institution account password. Anyone could read it. Fix: codes moved to `institution_secrets` (admin-only, read through `admin_institution_codes()`), column nulled by trigger on every write, existing values migrated, anon sees only non-credential columns, non-admin inserts cannot set `login_email` or raise AI limits. Tested: A9, A9b, S10. Owner step: rotate every institution password (they were exposed).

### High

**SEC-02 private profile data public (High).** `profiles_select using (true)` plus full column SELECT exposed `wallet_balance`, `wallet_locked_balance`, `total_winnings`, `verification_id_url`, `ban_reason`, `is_admin` to everyone, and realtime broadcast every profile change. Fix: anon limited to a public column list; `profiles` removed from the realtime publication. Signed-in users can still read these columns of other users because `profile_screen.dart` does `select('*')` and several screens read `wallet_balance`; revoking them now would crash the app. Residual, see section 5. `my_wallet()` is ready for the app switch. Tested: A18, A22.

**SEC-03 forged ledger (High).** `gacom_wallet_insert` let a user insert any `wallet_transactions` row (fake deposits, `paystack-verify` trusts rows owned by the caller). Fix: policy dropped; client INSERTs are swallowed by a BEFORE trigger (so older builds do not error); UPDATE/DELETE revoked. `reference` is already UNIQUE, which keeps credits idempotent. Tested: A4.

**SEC-05 free paid-competition entry (High).** Entry fee was debited by the client in three separate calls; attacker inserts `competition_participants` with `payment_status='paid'`, `rank=1`, `score=9999` and never pays. Fix (reconciled with the app-sec change): paid entry has one path, the RPC `join_paid_competition(p_competition_id)` (per-user lock, atomic `balance >= fee` debit, ledger row with reference `ENTRY_<competition>_<user>`, participant row, capacity and duplicate checks). `sec_participants_guard` refuses any direct client insert into a paid competition (it never debits, so a double debit is impossible), still lets free competitions be joined by insert, and nulls rank/score/check-in. App builds that insert directly into a paid competition must be updated. Tested: A11, S6, S6b.

**SEC-07 orders (High).** `order_items` had no RLS (anyone, including anon, could read or write any order line); users could insert orders with `status='confirmed'` and any price. Fix: RLS on `order_items` (owner, seller, admin), trigger takes `unit_price` from `products.price`, orders forced to `pending`, payment fields cleared, item prices recomputed. Tested: A13, A21, S8. Residual: the amount sent to Paystack comes from the client (section 5).

**SEC-08 exco and blog (High).** `admins_manage_exco` allowed `auth.uid() = exco_id` for ALL, so any user could insert their own exco assignment (finance_team, blog_editor); `Exco blog editors can manage posts` allowed any author to publish. Fix: self-grant policy dropped, blog policy requires admin, blog_editor exco or `manage_blog`. Tested: A10.

**SEC-12 tables without RLS (High).** `order_items`, `product_reviews`, `product_categories`, `post_comment_likes`, `blog_likes`, `blog_comments`, `reports` (reports include reporter and reported user). Fix: RLS and policies for each; a final check warns about any remaining table without RLS (none now). Tested: A13, A20, sweep.

**SEC-13 client-minted points (High).** `game_scores` INSERT is the points ledger that feeds house points, missions with limited prizes and cosmetics; a user could insert any score. Fix: per-row cap 100,000, 12 inserts per minute, 400 per day, 300,000 points per rolling day; same style guards for streak freezes (one per month), play log dates, quest stars. Tested: A14, X6, S8. Residual: scores are still client-reported (section 5).

**SEC-15 account enumeration (High).** `get_user_id_by_email` was `security definer`, granted to anon, and returned the user id for any email. Fix: admin only, rate limited. Tested: A8, S10.

**SEC-21 storage (High, partly unverified).** Buckets `avatars`, `post-media`, `product-images`, `blog-images`, `community-banners` are created in the dashboard, so their policies are not in the repo. Fix: any storage policy that names none of the known buckets or targets a managed bucket is replaced by owner-folder insert/update/delete policies (first path segment must equal `auth.uid()`); identity-style bucket names are forced private; size and MIME limits are set when none exist. The two repo buckets (`mission-clips`, `support-attachments`) were already private with owner checks. Not testable locally beyond policy creation: see owner steps.

**SEC-22 realtime leaks (High).** Publication carried `profiles` (wallet changes for every user), `tournament_matches` (room passwords), `match_results`, `exco_assignments`. None are subscribed by `lib/`. Removed. The rest (messages, notifications, support, darkom, house chat) is protected by RLS. Tested: A22.

**SEC-24 anonymous RPC surface (High).** 147 SECURITY DEFINER functions were executable by `anon` (default Supabase grants), including writers (`purchase_cosmetic`, `darkom_report_run`, `increment_posts_count`) and admin-named ones. Fix: EXECUTE revoked from PUBLIC and anon on every function in `public` (extension-owned functions skipped), re-granted only to anon for four read-only leaderboard RPCs and for functions an RLS policy needs; internal helpers (`grant_cosmetic`, `identity_notify`, `security_log`, `duel_settle`, `credit_wallet_from_reference`, ...) are service_role only; default privileges changed so new functions are not exposed. Tested: A15, sweep as anon and authenticated (no "permission denied for function").

### Medium

**SEC-10** notifications INSERT `with check (true)` (two policies): spoof any notification to any user (phishing). Fix: both dropped, INSERT revoked; all creators are definer triggers/RPCs. Tested: A7.
**SEC-11** `error_logs` open insert: unlimited storage flood with forged `user_id`. Fix: `user_id` must be null or self, text truncated, 300 per minute anonymous (shared), 30 per user. Tested: A17, S9.
**SEC-14** 12 SECURITY DEFINER functions without `search_path`, and the rest without `pg_temp` last. Fix: all set to `public, pg_temp`; temp-table creation revoked where permitted. Verified 0 remaining.
**SEC-16** `increment_posts_count(user_id)` let anyone change any user's counter; `get_direct_chats_for_user(uid)` listed anyone's contacts. Fix: bound to `auth.uid()` (counter is recomputed, not incremented). Tested: A15, A16.
**SEC-19** no rate limits on expensive RPCs. Fix: `sec_rl` sliding window added inside darkom challenge/report/run/squad/block, journey run, house join/request, equip, wallet-touching RPCs, orders, KYC, withdrawals. Mission code-word guessing limited to 6 tries per hour per mission. Tested: X4, X6.
**SEC-20** races: wallet-touching RPCs ran without per-user serialisation (double purchase charged twice then refunded), mission prize caps were check-then-insert. Fix: per-user advisory lock for purchase_cosmetic, purchase_bundle, purchase_house_item, found_house, duel_join, duel_quick, collection milestones; per-mission lock for submit/claim. Withdrawal and competition entry use their own lock. See residual: `deduct_arena_stake` body must do an atomic `balance >= amount` update.
**SEC-23** anon held INSERT/UPDATE/DELETE and everyone held TRUNCATE/REFERENCES/TRIGGER on every table through default grants. Fix: revoked and default privileges changed. Anon keeps INSERT only on `error_logs`.
**SEC-25** posts, ads, KYC requests, reviews: author-set counters, `is_featured`, ad `status='approved'`/`spend`, KYC `status='approved'`, `is_verified_purchase`. Fix: guard triggers force server values. Tested: A19.

### Low

**SEC-17** `my_mission_code(p_user)` accepted any user id; now ignores the parameter.
**SEC-26** `handle_new_user` failed sign-up on a username clash and trusted metadata length; now falls back to a generated username and truncates.

### Reviewed, no change needed

Dynamic SQL: only `execute format('... %I', col)` in `equip_cosmetic` variants, where `col` comes from a fixed CASE, and the migrations' own DDL loops. `ilike` in `support_admin_find_users` escapes `\ % _`; `darkom` and mission username search escape too. SECURITY DEFINER admin functions from migrations 13 to 19 all check `identity_is_admin()` or the support staff helpers before acting. Support desk (19) and security center (18): tables RLS-protected, helpers service-only, `anon` has no EXECUTE, attachment bucket private with owner/staff read, ticket rate limit present. Views `duel_standings*` read only public duel data.

## 3. Test evidence

Attack script `attacks.sql` (run as `authenticated` alice, `anon`, with forged `request.jwt.claims`), identical before and after. Seed: alice 5000, bob 2000, super admin, a private chat with a message, an institution with a password, a paid and a free competition.

| Id | Attack | Before | After |
|---|---|---|---|
| A1 | alice sets role=super_admin, is_admin=true | `role now: super_admin is_admin=true` | `permission denied for table profiles` |
| A2 | alice sets wallet_balance=1000000 | `balance now: 1000000.00` | `balance now: 5000.00` (write ignored) |
| A3 | self-verify | `verification now: verified` | `permission denied: verification is reviewed by an admin` |
| A4 | forged 50,000 deposit row | `forged rows stored: 1` | `forged rows stored: 0` |
| A5a | `refund_arena_stake(alice, 1000000)` | `alice balance: 1005000.00` | `permission denied for function refund_arena_stake` |
| A5b | `deduct_arena_stake(bob, 1500)` | `bob balance: 500.00` | `permission denied for function deduct_arena_stake` |
| A6 | join bob's chat, read it | `1 -> private: my bank pin is 1234` | `new row violates row-level security policy for table "chat_members"` |
| A7 | notification to bob from "system" | `notifications for bob: 3` | `permission denied for table notifications` |
| A8 | anon email to user id | returned the admin's uuid | `permission denied for function get_user_id_by_email` |
| A9 | anon reads institution passwords | `S3cretPassw0rd!` | `permission denied for table institutions` |
| A9b | signed-in reads institution passwords | `S3cretPassw0rd!` | `(none)` |
| A10 | self-grant exco, publish blog | `exco rows: 1`, `blog posts: 1` | `violates row-level security policy for table "exco_assignments"` |
| A11 | join paid cup free with rank=1 score=9999 | `paid rank=1 score=9999.00`, balance 5000 | `paid rank=null score=null`, balance 4000 |
| A12a | withdraw 900,000 with status=approved | `amount=900000.00 status=approved` | `Insufficient wallet balance` |
| A12b | plain user calls `approve_withdrawal` | `status: approved` | `Not allowed` |
| A13 | anon inserts into `order_items` | `SUCCEEDED` | `permission denied for table order_items` |
| A14 | score of 999,999,999 | `999999999` points | `100000` points (capped) |
| A15 | anon calls writing RPCs | all three `CALL SUCCEEDED` | `permission denied for function ...` x3 |
| A16 | alice lists bob's chats | `1` row | `0` rows |
| A17 | anon floods `error_logs` as bob | 400 rows, 200 MB | `violates row-level security policy` |
| A18 | anon reads wallet balances | `5000.00,2000.00,0.00` | `permission denied for table profiles` |
| A19 | post with likes_count=99999, featured | `likes=99999 featured=true` | `likes=0 featured=false` |
| A21 | order status=confirmed total=1 | `status=confirmed` | `status=pending` (total: see residual) |
| A22 | realtime publication | includes profiles, tournament_matches, match_results, exco_assignments | those four removed |

Extra checks after the migration (`extras.sql`): X1 plain user calling `admin_set_user_role` is refused; X2 trigger-only helpers and `sec_rl` are refused when called directly; X3 `institution_secrets` shows 0 rows to a user; X4/X6 rate limits trip (4th `found_house` in an hour, 13th score in a minute); X7 anon can read the public profile card but not wallet columns; X8 a finance_team exco can approve a withdrawal.

Smoke test of legitimate paths, all passing after the migration (`smoke.sql`, `smoke2.sql`):

| Id | Path | Result |
|---|---|---|
| S1 | profile display_name, bio, location, gamer_tag, is_private, request verification (pending), `select *` of another profile | works |
| S2 | buy a cosmetic (100 deducted, owned, second buy refused) | works |
| S3 | Darkom run report | `accepted: true`, xp 74 |
| S4 | hub join, send, recent, RLS read | works |
| S5 | `support_start_ticket`, `support_my_tickets`, ticket visible by RLS | works |
| S6 | old-client paid entry (insert, wallet update, ledger insert) | one debit of 1000, one ledger row, wallet 1000 |
| S7 | free join, direct chat creation, send, `UPDATE chats`, direct-chat RPC | works |
| S8 | score, play log, freeze, quest, post, order with items (client sent price 1, stored 2500), withdrawal | works |
| S9 | anon error log, leaderboard RPC, institution list, public profile card | works |
| S10 | admin: set role, approve withdrawal, uid by email, institution codes | works |

The migration was applied twice on the same database with no errors. A sweep of `select` on every public table as `anon` and as `authenticated` produced no "permission denied for function".

To re-run: build the schema, apply migrations in order, apply 20261020, then the scripts above.

## 4. App and edge-function changes needed

None are required for the app to keep working today; these finish the job.

1. `competition_detail_screen.dart`: DONE, paid entry calls `join_paid_competition`; wallet reads use `my_wallet()`.
2. `arena_service.dart`: DONE, stakes use `arena_deduct_my_stake(amount, reference)`; `refundStake` no longer calls `refund_arena_stake` (returns false). Draw/cancel/dispute refunds now need a server-side path (edge function), see residual risks.
3. `admin_dashboard_screen.dart`: ban, verify and role changes should call `admin_set_user_ban`, `admin_set_verification`, `admin_set_user_role`. Direct updates of other users already did nothing under RLS, and `role='exco'` is not a valid `user_role` value (roles are user, moderator, admin, super_admin). Institution passwords: read through `admin_institution_codes()`.
4. `store_admin_screen.dart` calls `get_user_id_by_email` with `p_email`, the function parameter is `email`.
5. Phase 2 for SEC-02: read the wallet through `my_wallet()`, replace `select('*')` on `profiles` in `profile_screen.dart` with an explicit public column list, then run `revoke select (wallet_balance, wallet_locked_balance, total_winnings, verification_id_url, ban_reason, is_admin, newsletter_subscribed, newsletter_last_sent_issue_id) on public.profiles from authenticated;`.
6. Tournament rooms: players should read credentials through `get_match_room(match_id)`; then revoke SELECT of `room_id_assigned`, `room_password_assigned` on `tournament_matches` and `room_code`, `room_password` on `game_rooms` from `authenticated` (already done for anon).
7. `paystack-init`: take the amount from the order row on the server (see residual).
8. Client search `.or('username.ilike.%$q%,...')` in `chat_list_screen.dart` and `admin_dashboard_screen.dart` puts user text into a PostgREST filter: strip `,()` and escape `% _ \` like `missions_service.dart` does.

## 5. Residual risks

- Production-only objects were not auditable: bodies of `deduct_arena_stake`, `refund_arena_stake`, `credit_wallet_from_reference`, `approve_withdrawal`, `reject_withdrawal`, `record_edu_session`, `find_or_join_edu_match`, `accept_edu_invite`, `increment_comments_count`, `get_student_rankings`, `arena_leaderboard`, tables `arena_matches`, `edu_compete_*`, `institutions`, and all storage policies. Run `select pg_get_functiondef(oid)` on them and confirm: wallet debits use one `update ... where wallet_balance >= amount`, every function derives the user from `auth.uid()`.
- Signed-in users can still read other users' `wallet_balance`, `total_winnings`, `ban_reason`, `verification_id_url` and room passwords until the app change in section 4 (items 5 and 6). This is the largest open item.
- Points, scores and "win" flags are reported by the client. The caps limit the damage to 300,000 points per user per day, not eliminate it. Real fix: server-verified results for games that award prizes.
- Link-based missions auto-approve any well-formed URL; spot checks are random.
- The Paystack amount for store orders is sent by the client; an attacker can pay less than the cart total. Fix in the edge function.
- Rate limits are per user; an attacker with many accounts is limited only by sign-up throttling.
- Guard-trigger failures raise inside the failing statement, so the security event is rolled back with it; refused escalations are visible in the Postgres log but not in `security_events`.
- Team join (`team_members`), competition registration and house join have no capacity checks beyond what their RPCs do.
- Extensions installed in `public` (as in the local test) leave pgcrypto functions executable by anon; Supabase installs them in `extensions`.

## 6. Owner steps (dashboard and operations)

1. Apply the migration, then check the notices: `sec_patch` lines should show 1 per function, and no `SECURITY: public.x has RLS disabled` warning.
2. Rotate every institution login password; they were world-readable. Rotate any user account that is suspicious: look at `profiles` where `role in ('admin','super_admin')` or `is_admin`, and `exco_assignments`, `admin_permissions`, and wallet balances with no matching ledger rows, for tampering before this fix.
3. Authentication: enable leaked-password protection, minimum length 10, email confirmation required, CAPTCHA on sign-up and sign-in, tighten auth rate limits (sign-ups per hour per IP, OTP and password-reset emails).
4. Require MFA (TOTP) for every admin and finance account; consider enforcing `aal2` in `sec_is_admin()` once enrolled.
5. Restrict the service-role key: keep it only in edge-function secrets, never in the app or CI logs; rotate it now if it was ever shared (anything that read the institution passwords may also have seen other secrets). Rotate the JWT secret and anon key if there is any doubt, and update the web build.
6. Set an allowed-origins list for the API and edge functions; keep the Paystack secret and webhook signature check in edge secrets.
7. Storage: in the dashboard confirm `avatars`, `post-media`, `product-images`, `blog-images`, `community-banners` have only the owner-folder write policies, KYC or ID uploads are in a private bucket, and file size and MIME limits are set.
8. Backups: enable daily backups and Point-in-Time Recovery, test a restore into a scratch project, and keep one copy outside Supabase.
9. Monitoring: schedule `security_scan()` (migration 18) with the service role, watch `security_events`, alert on wallet columns changing without a ledger row, and set Postgres log retention long enough to see refused escalation attempts.
10. Re-run this audit's catalog queries (RLS off, `true` policies, definer without search_path, anon EXECUTE) after every migration that adds tables or functions.
