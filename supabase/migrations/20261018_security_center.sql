-- Security Center (admin side of platform security).
--
-- Adds:
--   1. security_events     append-only feed of security-relevant events
--   2. security_log()      INTERNAL writer (service role / triggers / pg_cron only)
--      security_client_report()  heavily rate limited, allow-listed client signals
--   3. audit triggers      who changed what on sensitive tables (source = 'audit')
--   4. security_scan()     detectors, scheduled every 5 minutes through pg_cron
--   5. admin RPCs          overview, events, ack, audit trail, admin logins,
--                          posture checklist, scan now
--
-- Everything is idempotent. Admin check: public.identity_is_admin().
-- Audit rows live in security_events with source = 'audit' (details.table says which
-- table), so there is one feed, one retention rule and one place to look.

-- ---------------------------------------------------------------------------
-- 0. Helpers: admin gate, scrubber
-- ---------------------------------------------------------------------------
create or replace function public.security_require_admin()
returns void language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or not public.identity_is_admin() then
    raise exception 'forbidden' using errcode = '42501';
  end if;
end;
$$;

-- Removes secrets and bounds size before anything is stored in security_events.
-- Keys that look like credentials are replaced with "[redacted]"; long strings are cut.
create or replace function public.security_scrub(j jsonb, depth integer default 0)
returns jsonb language plpgsql immutable set search_path = public, pg_temp as $$
declare
  k text; v jsonb; out jsonb; elem jsonb; i integer := 0; t text;
begin
  if j is null then return null; end if;
  if depth > 4 then return to_jsonb('[deep]'::text); end if;
  case jsonb_typeof(j)
    when 'object' then
      out := '{}'::jsonb;
      for k, v in select * from jsonb_each(j) loop
        i := i + 1;
        exit when i > 40;
        if k ~* '(pass|secret|token|api_?key|authorization|cookie|otp|cvv|card_?num|private|credential|jwt|refresh|signature|^code$|^pin$|verification_id)' then
          out := out || jsonb_build_object(k, '[redacted]');
        else
          out := out || jsonb_build_object(k, public.security_scrub(v, depth + 1));
        end if;
      end loop;
      t := out::text;
      if length(t) > 8000 then
        return jsonb_build_object('truncated', true, 'preview', left(t, 2000));
      end if;
      return out;
    when 'array' then
      out := '[]'::jsonb;
      for elem in select * from jsonb_array_elements(j) loop
        i := i + 1;
        exit when i > 20;
        out := out || jsonb_build_array(public.security_scrub(elem, depth + 1));
      end loop;
      return out;
    when 'string' then
      t := j #>> '{}';
      if length(t) > 300 then return to_jsonb(left(t, 300) || '...'); end if;
      return j;
    else
      return j;
  end case;
end;
$$;

-- ---------------------------------------------------------------------------
-- 1. security_events
-- ---------------------------------------------------------------------------
create table if not exists public.security_events (
  id uuid primary key default gen_random_uuid(),
  created_at timestamptz not null default now(),
  severity text not null default 'info' check (severity in ('info', 'low', 'medium', 'high', 'critical')),
  kind text not null,
  actor_id uuid,
  subject_id uuid,
  source text not null default 'system',   -- system | audit | detector | client
  details jsonb not null default '{}'::jsonb,
  ip_hash text,
  status text not null default 'open' check (status in ('open', 'acknowledged', 'resolved')),
  handled_by uuid,
  handled_at timestamptz,
  note text,
  dedupe_key text
);
create index if not exists security_events_created_idx on public.security_events (created_at desc);
create index if not exists security_events_status_sev_idx on public.security_events (status, severity, created_at desc);
create index if not exists security_events_kind_idx on public.security_events (kind, created_at desc);
create index if not exists security_events_actor_idx on public.security_events (actor_id, created_at desc) where actor_id is not null;
create index if not exists security_events_source_idx on public.security_events (source, created_at desc);
create unique index if not exists security_events_dedupe_uq on public.security_events (dedupe_key) where dedupe_key is not null;

alter table public.security_events enable row level security;
drop policy if exists "admins read security events" on public.security_events;
create policy "admins read security events" on public.security_events
  for select to authenticated using (public.identity_is_admin());
-- No insert / update / delete policies: writes happen only through the functions below.
revoke all on public.security_events from anon, authenticated;
grant select on public.security_events to authenticated;

-- Small key/value store for detectors (e.g. admin roster fingerprint). No client access.
create table if not exists public.security_state (
  key text primary key,
  value text,
  updated_at timestamptz not null default now()
);
alter table public.security_state enable row level security;
revoke all on public.security_state from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2a. security_log: INTERNAL. Called by triggers, detectors, edge functions using the
--     service role, or other SECURITY DEFINER code. Never raises. Not executable by
--     anon or authenticated, so a client can never forge an event with it.
-- ---------------------------------------------------------------------------
create or replace function public.security_log(
  p_kind text,
  p_severity text,
  p_actor uuid,
  p_subject uuid,
  p_details jsonb default '{}'::jsonb,
  p_source text default 'system',
  p_dedupe text default null,
  p_ip_hash text default null
) returns uuid
language plpgsql security definer set search_path = public, pg_temp as $$
declare
  new_id uuid;
  sev text := case when p_severity in ('info', 'low', 'medium', 'high', 'critical') then p_severity else 'info' end;
  a record; n integer := 0;
begin
  insert into public.security_events (severity, kind, actor_id, subject_id, source, details, ip_hash, dedupe_key)
  values (sev, left(coalesce(nullif(p_kind, ''), 'unknown'), 80), p_actor, p_subject,
          coalesce(nullif(p_source, ''), 'system'),
          coalesce(public.security_scrub(p_details), '{}'::jsonb), left(p_ip_hash, 32), p_dedupe)
  on conflict (dedupe_key) where dedupe_key is not null do nothing
  returning id into new_id;

  -- Critical events ping every admin once (bounded).
  if new_id is not null and sev = 'critical' then
    begin
      for a in select id from public.profiles where role::text in ('admin', 'super_admin') limit 20 loop
        perform public.identity_notify(a.id, 'Security alert', 'A critical security event was raised: ' || left(p_kind, 60),
          jsonb_build_object('kind', 'security_event', 'event_id', new_id));
        n := n + 1;
      end loop;
    exception when others then null;
    end;
  end if;
  return new_id;
exception when others then
  return null;
end;
$$;
comment on function public.security_log(text, text, uuid, uuid, jsonb, text, text, text) is
  'INTERNAL. Writes a scrubbed security event. Executable only by postgres / service_role / SECURITY DEFINER callers. Never raises (returns null on failure). Pass p_dedupe to collapse repeats into one row.';
revoke all on function public.security_log(text, text, uuid, uuid, jsonb, text, text, text) from public, anon, authenticated;
grant execute on function public.security_log(text, text, uuid, uuid, jsonb, text, text, text) to service_role;

-- ---------------------------------------------------------------------------
-- 2b. security_client_report: suspicious signals detected on the device.
--     Signed-in users only, fixed allow-list, 5 per hour per user.
-- ---------------------------------------------------------------------------
create or replace function public.security_client_report(p_kind text, p_details jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  sev text;
  recent integer;
  ip text;
  iph text;
  det jsonb;
begin
  if uid is null then
    raise exception 'sign in required' using errcode = '42501';
  end if;
  sev := case p_kind
    when 'tamper_detected' then 'high'
    when 'jailbreak_detected' then 'medium'
    when 'root_detected' then 'medium'
    when 'debugger_attached' then 'medium'
    when 'repeated_auth_failure' then 'low'
    when 'emulator_detected' then 'low'
    when 'clock_tamper' then 'low'
    else null end;
  if sev is null then
    return jsonb_build_object('ok', false, 'reason', 'unknown_kind');
  end if;

  select count(*) into recent from public.security_events
   where source = 'client' and actor_id = uid and created_at > now() - interval '1 hour';
  if recent >= 5 then
    return jsonb_build_object('ok', false, 'reason', 'rate_limited');
  end if;

  det := coalesce(public.security_scrub(p_details), '{}'::jsonb);
  if length(det::text) > 2000 then det := jsonb_build_object('truncated', true); end if;

  begin
    ip := split_part(coalesce((current_setting('request.headers', true))::jsonb ->> 'x-forwarded-for', ''), ',', 1);
    if ip <> '' then iph := left(encode(sha256(convert_to(trim(ip) || ':gacom-sec', 'UTF8')), 'hex'), 16); end if;
  exception when others then iph := null;
  end;

  perform public.security_log(p_kind, sev, uid, uid, det, 'client', null, iph);
  return jsonb_build_object('ok', true);
end;
$$;
revoke all on function public.security_client_report(text, jsonb) from public, anon;
grant execute on function public.security_client_report(text, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Audit triggers: who changed what. AFTER triggers, never block the write.
-- ---------------------------------------------------------------------------
create or replace function public.security_audit_trg()
returns trigger language plpgsql security definer set search_path = public, pg_temp as $$
declare
  o jsonb := case when TG_OP = 'INSERT' then null else to_jsonb(OLD) end;
  n jsonb := case when TG_OP = 'DELETE' then null else to_jsonb(NEW) end;
  r jsonb := coalesce(n, o);
  actor uuid := auth.uid();
  subj uuid; kind text; sev text; col text; cols text[];
  changes jsonb := '{}'::jsonb;
  delta numeric;
  self boolean;
begin
  case TG_TABLE_NAME
    when 'profiles' then
      subj := (r ->> 'id')::uuid;
      if TG_OP = 'INSERT' then
        kind := 'admin_role_granted'; sev := 'critical'; cols := array['role'];
      else
        cols := array['role', 'verification_status', 'is_banned', 'wallet_balance', 'wallet_locked_balance'];
        if o ->> 'role' is distinct from n ->> 'role' then
          if n ->> 'role' in ('admin', 'super_admin') then kind := 'admin_role_granted'; sev := 'critical';
          elsif o ->> 'role' in ('admin', 'super_admin') then kind := 'admin_role_revoked'; sev := 'high';
          else kind := 'role_changed'; sev := 'high'; end if;
        elsif o ->> 'verification_status' is distinct from n ->> 'verification_status' then
          kind := 'verification_changed'; sev := 'low';
        elsif o ->> 'is_banned' is distinct from n ->> 'is_banned' then
          kind := 'ban_changed'; sev := 'medium';
        elsif o ->> 'wallet_balance' is distinct from n ->> 'wallet_balance'
           or o ->> 'wallet_locked_balance' is distinct from n ->> 'wallet_locked_balance' then
          delta := abs(coalesce((n ->> 'wallet_balance')::numeric, 0) - coalesce((o ->> 'wallet_balance')::numeric, 0));
          -- Ordinary entries and payouts are small; only large movements are audit-worthy.
          if delta < 50000 then return null; end if;
          kind := 'wallet_adjusted'; sev := 'high';
        else
          return null;
        end if;
      end if;
    when 'cosmetic_items' then
      if TG_OP = 'DELETE' then
        kind := 'cosmetic_deleted'; sev := 'low'; cols := array['name', 'price'];
      else
        if o ->> 'price' is not distinct from n ->> 'price' then return null; end if;
        kind := 'price_changed'; cols := array['price', 'name'];
        sev := case when coalesce((n ->> 'price')::numeric, 0) = 0 and coalesce((o ->> 'price')::numeric, 0) > 0 then 'medium' else 'low' end;
      end if;
    when 'missions' then
      if o ->> 'reward_item_id' is not distinct from n ->> 'reward_item_id'
         and o ->> 'reward_house_points' is not distinct from n ->> 'reward_house_points'
         and o ->> 'reward_trophy_key' is not distinct from n ->> 'reward_trophy_key'
         and o ->> 'max_winners' is not distinct from n ->> 'max_winners' then return null; end if;
      kind := 'mission_reward_changed'; sev := 'medium';
      cols := array['title', 'reward_item_id', 'reward_house_points', 'reward_trophy_key', 'max_winners'];
    when 'mission_submissions' then
      if o ->> 'status' is not distinct from n ->> 'status' or coalesce((n ->> 'auto_approved')::boolean, false)
         or n ->> 'status' not in ('approved', 'rejected') then return null; end if;
      subj := (n ->> 'user_id')::uuid;
      kind := case n ->> 'status' when 'approved' then 'mission_approved' else 'mission_rejected' end;
      sev := 'info';
      if (n ->> 'reviewer_id') is not null and (n ->> 'reviewer_id') = (n ->> 'user_id') then
        kind := 'mission_self_review'; sev := 'high';
      end if;
      cols := array['status', 'mission_id', 'reviewer_id', 'reject_reason'];
    when 'exco_assignments' then
      subj := (r ->> 'exco_id')::uuid;
      kind := case TG_OP when 'INSERT' then 'exco_assigned' when 'DELETE' then 'exco_removed' else 'exco_changed' end;
      sev := 'high'; cols := array['exco_id', 'exco_role', 'assigned_by'];
    when 'darkom_mutes' then
      subj := (r ->> 'user_id')::uuid;
      kind := case TG_OP when 'INSERT' then 'darkom_mute_added' when 'DELETE' then 'darkom_mute_removed' else 'darkom_mute_changed' end;
      sev := case when actor is null then 'info' else 'low' end;
      cols := array['user_id', 'until', 'level'];
    when 'houses' then
      subj := (r ->> 'captain_id')::uuid;
      if TG_OP = 'DELETE' then kind := 'house_deleted'; sev := 'medium'; cols := array['name', 'captain_id'];
      else
        if o ->> 'captain_id' is not distinct from n ->> 'captain_id' then return null; end if;
        kind := 'house_ownership_changed'; sev := 'high'; cols := array['name', 'captain_id'];
      end if;
    when 'admin_permissions' then
      subj := (r ->> 'admin_id')::uuid;
      kind := case TG_OP when 'INSERT' then 'admin_permission_granted' else 'admin_permission_revoked' end;
      sev := 'high'; cols := array['admin_id', 'permission', 'granted_by'];
    when 'user_cosmetic_inventory' then
      subj := (r ->> 'user_id')::uuid;
      kind := 'admin_item_grant'; sev := 'low'; cols := array['user_id', 'item_id', 'source'];
    else
      return null;
  end case;

  subj := coalesce(subj, case when r ? 'id' and (r ->> 'id') ~ '^[0-9a-f-]{36}$' then (r ->> 'id')::uuid end);
  self := actor is not null and subj is not null and actor = subj;
  -- A user changing their own privileged fields is always worse than an admin doing it.
  if self and kind in ('admin_role_granted', 'role_changed', 'wallet_adjusted', 'verification_changed') then
    sev := case when kind = 'admin_role_granted' then 'critical' else 'high' end;
  end if;

  foreach col in array cols loop
    if TG_OP = 'UPDATE' then
      if o -> col is distinct from n -> col then
        changes := changes || jsonb_build_object(col, jsonb_build_object('old', o -> col, 'new', n -> col));
      end if;
    elsif TG_OP = 'INSERT' then
      changes := changes || jsonb_build_object(col, jsonb_build_object('new', n -> col));
    else
      changes := changes || jsonb_build_object(col, jsonb_build_object('old', o -> col));
    end if;
  end loop;

  perform public.security_log(kind, sev, actor, subj,
    jsonb_build_object('table', TG_TABLE_NAME, 'op', TG_OP, 'pk', coalesce(r ->> 'id', r ->> 'user_id'),
                       'self_change', self, 'changes', changes),
    'audit');
  return null;
exception when others then
  return null; -- auditing must never block the underlying write
end;
$$;
revoke all on function public.security_audit_trg() from public, anon, authenticated;

-- Install triggers only for tables that exist in this database.
do $$
declare
  s record;
begin
  for s in
    select * from (values
      ('profiles',               'profiles_sec_audit_upd',  'after update of role, verification_status, is_banned, wallet_balance, wallet_locked_balance on public.profiles for each row'),
      ('profiles',               'profiles_sec_audit_ins',  'after insert on public.profiles for each row when (new.role::text in (''admin'', ''super_admin''))'),
      ('cosmetic_items',         'cosmetic_items_sec_audit','after update of price or delete on public.cosmetic_items for each row'),
      ('missions',               'missions_sec_audit',      'after update of reward_item_id, reward_house_points, reward_trophy_key, max_winners on public.missions for each row'),
      ('mission_submissions',    'mission_subs_sec_audit',  'after update of status on public.mission_submissions for each row when (old.status is distinct from new.status)'),
      ('exco_assignments',       'exco_sec_audit',          'after insert or update or delete on public.exco_assignments for each row'),
      ('darkom_mutes',           'darkom_mutes_sec_audit',  'after insert or update or delete on public.darkom_mutes for each row'),
      ('houses',                 'houses_sec_audit',        'after update of captain_id or delete on public.houses for each row'),
      ('admin_permissions',      'admin_perms_sec_audit',   'after insert or delete on public.admin_permissions for each row'),
      ('user_cosmetic_inventory','inventory_sec_audit',     'after insert on public.user_cosmetic_inventory for each row when (new.source = ''admin'')')
    ) as t(tbl, trg, spec)
  loop
    if to_regclass('public.' || s.tbl) is not null then
      begin
        execute format('drop trigger if exists %I on public.%I', s.trg, s.tbl);
        execute format('create trigger %I %s execute function public.security_audit_trg()', s.trg, s.spec);
      exception when others then
        raise notice 'security audit trigger % skipped: %', s.trg, sqlerrm;
      end;
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 4. Detectors. One issue creates one event per day (dedupe key carries the date).
-- ---------------------------------------------------------------------------
create or replace function public.security_scan()
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  r record; day text := to_char(now() at time zone 'utc', 'YYYYMMDD');
  hour text := to_char(now() at time zone 'utc', 'YYYYMMDDHH24');
  raised integer := 0; errs integer := 0; eid uuid;
  fp text; prev text;
begin
  -- 1. Rejected Darkom runs per user per day
  begin
    if to_regclass('public.darkom_runs') is not null then
      for r in select user_id, count(*) n from public.darkom_runs
                where accepted = false and created_at > now() - interval '24 hours'
                group by user_id having count(*) > 10 loop
        eid := public.security_log('darkom_rejected_runs', case when r.n >= 40 then 'high' else 'medium' end, null, r.user_id,
              jsonb_build_object('rejected_runs_24h', r.n), 'detector', 'darkom_rejected_runs:' || r.user_id || ':' || day);
        if eid is not null then raised := raised + 1; end if;
      end loop;
    end if;
  exception when others then errs := errs + 1; raise warning 'security_scan darkom_runs: %', sqlerrm;
  end;

  -- 2. Wallet credit velocity (credits in the last hour)
  begin
    if to_regclass('public.wallet_transactions') is not null then
      for r in select user_id, count(*) n, sum(amount) total from public.wallet_transactions
                where created_at > now() - interval '1 hour' and amount > 0
                  and type::text in ('deposit', 'competition_win', 'refund') and status::text = 'success'
                group by user_id having count(*) >= 15 or sum(amount) >= 200000 loop
        eid := public.security_log('wallet_credit_velocity', 'high', null, r.user_id,
              jsonb_build_object('credits_1h', r.n, 'total_1h', r.total), 'detector', 'wallet_credit_velocity:' || r.user_id || ':' || day);
        if eid is not null then raised := raised + 1; end if;
      end loop;
    end if;
  exception when others then errs := errs + 1; raise warning 'security_scan wallet: %', sqlerrm;
  end;

  -- 3. Users reported by 3+ different people in 24 h
  begin
    if to_regclass('public.darkom_reports') is not null then
      for r in select target_id, count(distinct reporter_id) n,
                      jsonb_object_agg(reason, c) filter (where reason is not null) reasons
                 from (select target_id, reporter_id, reason, count(*) over (partition by target_id, reason) c
                         from public.darkom_reports where created_at > now() - interval '24 hours') q
                group by target_id having count(distinct reporter_id) >= 3 loop
        eid := public.security_log('multiple_reports', case when r.n >= 6 then 'high' else 'medium' end, null, r.target_id,
              jsonb_build_object('reporters_24h', r.n, 'reasons', r.reasons), 'detector', 'multiple_reports:' || r.target_id || ':' || day);
        if eid is not null then raised := raised + 1; end if;
      end loop;
    end if;
  exception when others then errs := errs + 1; raise warning 'security_scan reports: %', sqlerrm;
  end;

  -- 4. error_logs insert spike (open insert policy makes this an abuse vector)
  begin
    if to_regclass('public.error_logs') is not null then
      select count(*) into r from public.error_logs where created_at > now() - interval '5 minutes';
      if r.count > 200 then
        eid := public.security_log('error_log_spike', 'high', null, null,
              jsonb_build_object('inserts_5m', r.count), 'detector', 'error_log_spike:' || hour);
        if eid is not null then raised := raised + 1; end if;
      end if;
    end if;
  exception when others then errs := errs + 1; raise warning 'security_scan error_logs: %', sqlerrm;
  end;

  -- 5. Admin roster changed outside the audit triggers (direct SQL, triggers disabled)
  begin
    select md5(coalesce(string_agg(id::text, ',' order by id), '')) into fp
      from public.profiles where role::text in ('admin', 'super_admin');
    select value into prev from public.security_state where key = 'admin_roster';
    if prev is null then
      insert into public.security_state (key, value) values ('admin_roster', fp) on conflict (key) do nothing;
    elsif prev <> fp then
      eid := public.security_log('admin_roster_changed', 'critical', null, null,
            jsonb_build_object('previous', prev, 'current', fp), 'detector', 'admin_roster_changed:' || fp);
      if eid is not null then raised := raised + 1; end if;
      update public.security_state set value = fp, updated_at = now() where key = 'admin_roster';
    end if;
  exception when others then errs := errs + 1; raise warning 'security_scan roster: %', sqlerrm;
  end;

  -- 6. Repeated rejected mission claims (duplicate proofs, forged links)
  begin
    if to_regclass('public.mission_submissions') is not null then
      for r in select user_id, count(*) n,
                      count(*) filter (where reject_reason ilike '%duplicate%' or reject_reason ilike '%already%') dups
                 from public.mission_submissions
                where status = 'rejected' and created_at > now() - interval '24 hours'
                group by user_id having count(*) >= 5 loop
        eid := public.security_log('repeated_rejected_claims', case when r.dups >= 3 then 'medium' else 'low' end, null, r.user_id,
              jsonb_build_object('rejected_24h', r.n, 'duplicates', r.dups), 'detector', 'repeated_rejected_claims:' || r.user_id || ':' || day);
        if eid is not null then raised := raised + 1; end if;
      end loop;
    end if;
  exception when others then errs := errs + 1; raise warning 'security_scan claims: %', sqlerrm;
  end;

  -- 7. Several device-side signals from the same user
  begin
    for r in select actor_id, count(*) n, array_agg(distinct kind) kinds from public.security_events
              where source = 'client' and actor_id is not null and created_at > now() - interval '24 hours'
              group by actor_id having count(*) >= 3 loop
      eid := public.security_log('client_signal_burst', 'high', r.actor_id, r.actor_id,
            jsonb_build_object('signals_24h', r.n, 'kinds', to_jsonb(r.kinds)), 'detector', 'client_signal_burst:' || r.actor_id || ':' || day);
      if eid is not null then raised := raised + 1; end if;
    end loop;
  exception when others then errs := errs + 1; raise warning 'security_scan client: %', sqlerrm;
  end;

  -- Retention: resolved events older than a year
  begin
    delete from public.security_events where status = 'resolved' and created_at < now() - interval '365 days';
  exception when others then null;
  end;

  return jsonb_build_object('raised', raised, 'errors', errs, 'ran_at', now());
end;
$$;
revoke all on function public.security_scan() from public, anon, authenticated;
grant execute on function public.security_scan() to service_role;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('security-scan', '*/5 * * * *', 'select public.security_scan()');
  end if;
exception when others then
  raise notice 'could not schedule security_scan; admins can run it from the Security Center';
end $$;

-- ---------------------------------------------------------------------------
-- 5. Posture (internal) and admin RPCs (admin_security_posture is the live checklist)
-- ---------------------------------------------------------------------------
create or replace function public.security_posture()
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  checks jsonb := '[]'::jsonb;
  score integer := 100;
  tot integer; nrls integer; norls text[];
  fn_tot integer; fn_nosp integer; fn_names text[];
  w_true integer; w_names text[]; s_true integer;
  anon_def integer;
  audit_trg integer;
  cron_ok boolean := false;
  open_crit integer; open_high integer;
  ok boolean;
begin
  select count(*), count(*) filter (where c.relrowsecurity),
         coalesce((array_agg(c.relname order by c.relname) filter (where not c.relrowsecurity))[1:25], '{}')
    into tot, nrls, norls
    from pg_class c join pg_namespace n on n.oid = c.relnamespace
   where n.nspname = 'public' and c.relkind in ('r', 'p');
  ok := tot = nrls;
  if not ok then score := score - least(30, 5 * (tot - nrls)); end if;
  checks := checks || jsonb_build_object('key', 'rls_all_tables', 'label', 'Row level security on every public table',
    'ok', ok, 'value', nrls || ' / ' || tot, 'detail', to_jsonb(norls), 'weight', 30);

  select count(*), count(*) filter (where p.proconfig is null or not exists (select 1 from unnest(p.proconfig) x where x like 'search_path=%')),
         coalesce((array_agg(p.proname order by p.proname) filter (where p.proconfig is null or not exists (select 1 from unnest(p.proconfig) x where x like 'search_path=%')))[1:25], '{}')
    into fn_tot, fn_nosp, fn_names
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e');
  ok := fn_nosp = 0;
  if not ok then score := score - least(20, 2 * fn_nosp); end if;
  checks := checks || jsonb_build_object('key', 'definer_search_path', 'label', 'SECURITY DEFINER functions pin search_path',
    'ok', ok, 'value', fn_nosp || ' unpinned of ' || fn_tot, 'detail', to_jsonb(fn_names), 'weight', 20);

  select count(*) filter (where cmd <> 'SELECT'),
         coalesce((array_agg(distinct tablename order by tablename) filter (where cmd <> 'SELECT'))[1:25], '{}'),
         count(*) filter (where cmd = 'SELECT')
    into w_true, w_names, s_true
    from pg_policies
   where schemaname = 'public' and permissive = 'PERMISSIVE'
     and (lower(trim(coalesce(qual, ''))) in ('true', '(true)') or lower(trim(coalesce(with_check, ''))) in ('true', '(true)'))
     and not (cmd <> 'SELECT' and coalesce(qual, 'x') <> 'true' and with_check is null and roles = '{service_role}');
  ok := w_true = 0;
  if not ok then score := score - least(20, 3 * w_true); end if;
  checks := checks || jsonb_build_object('key', 'permissive_true_write_policies', 'label', 'No always-true write policies',
    'ok', ok, 'value', w_true || ' write policies (' || s_true || ' public read)', 'detail', to_jsonb(w_names), 'weight', 20);

  select count(*) into anon_def
    from pg_proc p join pg_namespace n on n.oid = p.pronamespace
   where n.nspname = 'public' and p.prosecdef and has_function_privilege('anon', p.oid, 'execute')
     and not exists (select 1 from pg_depend d where d.objid = p.oid and d.deptype = 'e');
  ok := anon_def <= 10;
  if not ok then score := score - least(10, anon_def / 5); end if;
  checks := checks || jsonb_build_object('key', 'anon_definer_exec', 'label', 'Few privileged functions callable while signed out',
    'ok', ok, 'value', anon_def::text, 'detail', '[]'::jsonb, 'weight', 10);

  select count(*) into audit_trg from pg_trigger t where not t.tgisinternal and t.tgname like '%\_sec\_audit%';
  ok := audit_trg >= 5;
  if not ok then score := score - 10; end if;
  checks := checks || jsonb_build_object('key', 'audit_triggers', 'label', 'Audit triggers installed on sensitive tables',
    'ok', ok, 'value', audit_trg::text, 'detail', '[]'::jsonb, 'weight', 10);

  begin
    execute $q$select exists (select 1 from cron.job where jobname = 'security-scan' and active)$q$ into cron_ok;
  exception when others then cron_ok := false;
  end;
  if not cron_ok then score := score - 5; end if;
  checks := checks || jsonb_build_object('key', 'scan_scheduled', 'label', 'Security scan scheduled every 5 minutes',
    'ok', cron_ok, 'value', case when cron_ok then 'active' else 'not scheduled' end, 'detail', '[]'::jsonb, 'weight', 5);

  select count(*) filter (where severity = 'critical'), count(*) filter (where severity = 'high')
    into open_crit, open_high from public.security_events where status = 'open';
  ok := open_crit = 0 and open_high = 0;
  if open_crit > 0 then score := score - least(15, 5 * open_crit); end if;
  if open_high > 0 then score := score - least(5, open_high); end if;
  checks := checks || jsonb_build_object('key', 'open_urgent_events', 'label', 'No unhandled high or critical events',
    'ok', ok, 'value', open_crit || ' critical, ' || open_high || ' high', 'detail', '[]'::jsonb, 'weight', 15);

  score := greatest(0, least(100, score));
  return jsonb_build_object('score', score,
    'grade', case when score >= 90 then 'A' when score >= 75 then 'B' when score >= 60 then 'C' when score >= 40 then 'D' else 'F' end,
    'checks', checks);
end;
$$;
revoke all on function public.security_posture() from public, anon, authenticated;
grant execute on function public.security_posture() to service_role;

create or replace function public.admin_security_posture()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public.security_require_admin();
  return public.security_posture();
end;
$$;

create or replace function public.admin_security_overview()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  sev text[] := array['critical', 'high', 'medium', 'low', 'info'];
  s text; open_now jsonb := '{}'::jsonb; d24 jsonb := '{}'::jsonb; d7 jsonb := '{}'::jsonb;
  kinds jsonb; trend jsonb; staff integer; inactive jsonb; posture jsonb;
begin
  perform public.security_require_admin();
  foreach s in array sev loop
    open_now := open_now || jsonb_build_object(s, (select count(*) from public.security_events where severity = s and status = 'open'));
    d24 := d24 || jsonb_build_object(s, (select count(*) from public.security_events where severity = s and created_at > now() - interval '24 hours'));
    d7 := d7 || jsonb_build_object(s, (select count(*) from public.security_events where severity = s and created_at > now() - interval '7 days'));
  end loop;

  select coalesce(jsonb_agg(jsonb_build_object('kind', kind, 'count', c) order by c desc), '[]'::jsonb) into kinds
    from (select kind, count(*) c from public.security_events where created_at > now() - interval '7 days'
           group by kind order by count(*) desc limit 8) q;

  select jsonb_agg(jsonb_build_object('day', to_char(g.d, 'YYYY-MM-DD'),
           'total', coalesce(e.total, 0), 'urgent', coalesce(e.urgent, 0)) order by g.d) into trend
    from generate_series((now() at time zone 'utc')::date - 6, (now() at time zone 'utc')::date, interval '1 day') g(d)
    left join (select (created_at at time zone 'utc')::date d, count(*) total,
                      count(*) filter (where severity in ('high', 'critical')) urgent
                 from public.security_events where created_at > now() - interval '8 days' group by 1) e on e.d = g.d::date;

  select count(*) into staff from public.profiles where role::text in ('admin', 'super_admin', 'moderator');
  select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', coalesce(display_name, username, 'Admin'),
           'role', role::text, 'last_seen', last_seen) order by last_seen nulls first), '[]'::jsonb) into inactive
    from public.profiles
   where role::text in ('admin', 'super_admin') and (last_seen is null or last_seen < now() - interval '30 days');

  posture := public.security_posture();
  return jsonb_build_object('open_now', open_now, 'last_24h', d24, 'last_7d', d7, 'top_kinds', kinds,
    'trend', coalesce(trend, '[]'::jsonb), 'staff_accounts', staff, 'inactive_admins', inactive,
    'posture_score', posture -> 'score', 'posture_grade', posture -> 'grade', 'generated_at', now());
end;
$$;

create or replace function public.admin_security_events(
  p_severity text default null, p_status text default null, p_kind text default null,
  p_limit integer default 50, p_offset integer default 0
) returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare total integer; items jsonb; lim integer := greatest(1, least(coalesce(p_limit, 50), 200)); off integer := greatest(0, coalesce(p_offset, 0));
begin
  perform public.security_require_admin();
  select count(*) into total from public.security_events e
   where (p_severity is null or p_severity in ('', 'all') or e.severity = p_severity)
     and (p_status is null or p_status in ('', 'all') or e.status = p_status)
     and (p_kind is null or p_kind in ('', 'all') or e.kind = p_kind);
  select coalesce(jsonb_agg(row_to_json(q)::jsonb order by q.created_at desc), '[]'::jsonb) into items from (
    select e.id, e.created_at, e.severity, e.kind, e.actor_id, e.subject_id, e.source, e.details, e.ip_hash,
           e.status, e.handled_by, e.handled_at, e.note,
           (select coalesce(display_name, username) from public.profiles where id = e.actor_id) as actor_name,
           (select coalesce(display_name, username) from public.profiles where id = e.subject_id) as subject_name,
           (select coalesce(display_name, username) from public.profiles where id = e.handled_by) as handled_by_name
      from public.security_events e
     where (p_severity is null or p_severity in ('', 'all') or e.severity = p_severity)
       and (p_status is null or p_status in ('', 'all') or e.status = p_status)
       and (p_kind is null or p_kind in ('', 'all') or e.kind = p_kind)
     order by e.created_at desc limit lim offset off) q;
  return jsonb_build_object('total', total, 'items', items,
    'kinds', (select coalesce(jsonb_agg(kind order by kind), '[]'::jsonb) from (select distinct kind from public.security_events) k));
end;
$$;

create or replace function public.admin_security_ack(p_id uuid, p_status text, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare row public.security_events;
begin
  perform public.security_require_admin();
  if p_status not in ('open', 'acknowledged', 'resolved') then
    raise exception 'invalid status' using errcode = '22023';
  end if;
  update public.security_events
     set status = p_status,
         handled_by = case when p_status = 'open' then null else auth.uid() end,
         handled_at = case when p_status = 'open' then null else now() end,
         note = nullif(left(coalesce(p_note, note, ''), 1000), '')
   where id = p_id returning * into row;
  if row.id is null then raise exception 'event not found' using errcode = 'P0002'; end if;
  return jsonb_build_object('id', row.id, 'status', row.status, 'handled_at', row.handled_at, 'note', row.note);
end;
$$;

create or replace function public.admin_audit_trail(p_table text default null, p_actor uuid default null, p_limit integer default 100)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare items jsonb; lim integer := greatest(1, least(coalesce(p_limit, 100), 500));
begin
  perform public.security_require_admin();
  select coalesce(jsonb_agg(row_to_json(q)::jsonb order by q.created_at desc), '[]'::jsonb) into items from (
    select e.id, e.created_at, e.severity, e.kind, e.actor_id, e.subject_id, e.details, e.status,
           e.details ->> 'table' as table_name,
           (select coalesce(display_name, username) from public.profiles where id = e.actor_id) as actor_name,
           (select coalesce(display_name, username) from public.profiles where id = e.subject_id) as subject_name
      from public.security_events e
     where e.source = 'audit'
       and (p_table is null or p_table in ('', 'all') or e.details ->> 'table' = p_table)
       and (p_actor is null or e.actor_id = p_actor)
     order by e.created_at desc limit lim) q;
  return jsonb_build_object('items', items,
    'tables', (select coalesce(jsonb_agg(t order by t), '[]'::jsonb) from (select distinct details ->> 'table' t from public.security_events where source = 'audit') x where t is not null));
end;
$$;

create or replace function public.admin_recent_admin_logins()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare items jsonb;
begin
  perform public.security_require_admin();
  begin
    execute $q$
      select coalesce(jsonb_agg(jsonb_build_object(
               'id', p.id, 'name', coalesce(p.display_name, p.username, 'Admin'), 'role', p.role::text,
               'email', case when u.email is null then null
                             else left(split_part(u.email, '@', 1), 1) || '***@' || split_part(u.email, '@', 2) end,
               'last_sign_in_at', u.last_sign_in_at, 'last_seen', p.last_seen)
             order by u.last_sign_in_at desc nulls last), '[]'::jsonb)
        from public.profiles p join auth.users u on u.id = p.id
       where p.role::text in ('admin', 'super_admin')$q$ into items;
    return jsonb_build_object('source', 'auth', 'items', items);
  exception when others then
    -- auth schema restricted: fall back to the activity the app records itself
    select coalesce(jsonb_agg(jsonb_build_object('id', p.id, 'name', coalesce(p.display_name, p.username, 'Admin'),
             'role', p.role::text, 'email', null, 'last_sign_in_at', null, 'last_seen', p.last_seen)
             order by p.last_seen desc nulls last), '[]'::jsonb) into items
      from public.profiles p where p.role::text in ('admin', 'super_admin');
    return jsonb_build_object('source', 'profiles', 'items', items);
  end;
end;
$$;

create or replace function public.admin_security_scan_now()
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public.security_require_admin();
  return public.security_scan();
end;
$$;

do $$
declare f text;
begin
  foreach f in array array[
    'admin_security_posture()', 'admin_security_overview()',
    'admin_security_events(text, text, text, integer, integer)', 'admin_security_ack(uuid, text, text)',
    'admin_audit_trail(text, uuid, integer)', 'admin_recent_admin_logins()', 'admin_security_scan_now()',
    'security_require_admin()'] loop
    execute format('revoke all on function public.%s from public, anon', f);
    execute format('grant execute on function public.%s to authenticated', f);
  end loop;
  -- helper must not be a general-purpose oracle for clients beyond its own gate; scrub is pure and safe.
  revoke all on function public.security_scrub(jsonb, integer) from public, anon, authenticated;
  grant execute on function public.security_scrub(jsonb, integer) to service_role;
end $$;
