-- GACOM Customer Care Desk.
--
-- Extends the original support_tickets / support_messages (002_patch_v2.sql) into a
-- team based help desk: teams, members with caps, categories, SLA, knowledge base,
-- macros, assistant feedback, an access log for user-context lookups and rate counters.
--
-- Security model
--   * Nobody writes tickets or messages directly. Every write is a SECURITY DEFINER
--     RPC (signed-in users, staff, admins) or a support_svc_* function that only the
--     service role (the support-assistant edge function) can execute.
--   * Users see only their own tickets and the non-internal messages of those tickets.
--     Staff see tickets of the teams they belong to. Admins see everything.
--   * Functions named support_i_* are internal helpers: nobody can call them over the API.
--
-- Everything here is idempotent. Admin check: public.identity_is_admin().
-- Notifications: public.identity_notify().

-- ---------------------------------------------------------------------------
-- 1. Base tables (no-op when 002_patch_v2.sql already created them)
-- ---------------------------------------------------------------------------
create table if not exists public.support_tickets (
  id uuid primary key default gen_random_uuid(),
  user_id uuid references public.profiles(id) on delete cascade,
  issue text not null,
  status text default 'open',
  assigned_agent_id uuid references public.profiles(id),
  ai_transcript text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

create table if not exists public.support_messages (
  id uuid primary key default gen_random_uuid(),
  ticket_id uuid references public.support_tickets(id) on delete cascade,
  sender_id uuid references public.profiles(id) on delete cascade,
  message text not null,
  is_agent boolean default false,
  created_at timestamptz default now()
);

-- ---------------------------------------------------------------------------
-- 2. Desk tables
-- ---------------------------------------------------------------------------
create table if not exists public.support_teams (
  id uuid primary key default gen_random_uuid(),
  key text not null unique,
  name text not null,
  description text not null default '',
  sort_order int not null default 0,
  is_default boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.support_team_members (
  id uuid primary key default gen_random_uuid(),
  team_id uuid not null references public.support_teams(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  role text not null default 'agent' check (role in ('agent', 'lead')),
  active boolean not null default true,
  cap int not null default 10 check (cap between 1 and 200),
  last_assigned_at timestamptz,
  created_at timestamptz not null default now(),
  unique (team_id, user_id)
);
create index if not exists support_team_members_user_idx on public.support_team_members (user_id) where active;

create table if not exists public.support_categories (
  key text primary key,
  label text not null,
  team_key text not null references public.support_teams(key) on update cascade,
  default_priority text not null default 'normal' check (default_priority in ('low', 'normal', 'high', 'urgent')),
  auto_resolve_allowed boolean not null default false,
  sort_order int not null default 0,
  active boolean not null default true
);

create table if not exists public.support_sla (
  priority text primary key check (priority in ('low', 'normal', 'high', 'urgent')),
  first_response_min int not null check (first_response_min > 0),
  resolution_min int not null check (resolution_min > 0)
);

create table if not exists public.support_kb_articles (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  category_key text references public.support_categories(key) on update cascade on delete set null,
  published boolean not null default false,
  source_ticket_id uuid references public.support_tickets(id) on delete set null,
  created_by uuid references public.profiles(id) on delete set null,
  helpful_count int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  tsv tsvector generated always as (
    setweight(to_tsvector('english', coalesce(title, '')), 'A') || setweight(to_tsvector('english', coalesce(body, '')), 'B')
  ) stored
);
create index if not exists support_kb_tsv_idx on public.support_kb_articles using gin (tsv);

create table if not exists public.support_macros (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  body text not null,
  category_key text references public.support_categories(key) on update cascade on delete set null,
  active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.support_assistant_feedback (
  id uuid primary key default gen_random_uuid(),
  message_id uuid not null references public.support_messages(id) on delete cascade,
  ticket_id uuid not null references public.support_tickets(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  helpful boolean not null,
  correction text not null default '',
  created_at timestamptz not null default now(),
  unique (message_id, user_id)
);

create table if not exists public.support_access_log (
  id uuid primary key default gen_random_uuid(),
  viewer_id uuid not null,
  ticket_id uuid,
  subject_user_id uuid,
  action text not null default 'user_context',
  at timestamptz not null default now()
);
create index if not exists support_access_log_at_idx on public.support_access_log (at desc);

create table if not exists public.support_rate (
  user_id uuid not null,
  bucket text not null check (bucket in ('minute', 'hour')),
  window_start timestamptz not null,
  n int not null default 0,
  primary key (user_id, bucket, window_start)
);

-- ---------------------------------------------------------------------------
-- 3. New columns on the existing tables
-- ---------------------------------------------------------------------------
alter table public.support_tickets
  add column if not exists subject text,
  add column if not exists category text not null default 'other',
  add column if not exists priority text not null default 'normal',
  add column if not exists team_id uuid references public.support_teams(id),
  add column if not exists summary text,
  add column if not exists sentiment text,
  add column if not exists safety_flag boolean not null default false,
  add column if not exists first_response_due timestamptz,
  add column if not exists first_response_at timestamptz,
  add column if not exists resolution_due timestamptz,
  add column if not exists resolved_at timestamptz,
  add column if not exists closed_at timestamptz,
  add column if not exists breached boolean not null default false,
  add column if not exists breached_at timestamptz,
  add column if not exists csat int,
  add column if not exists csat_comment text,
  add column if not exists device_info jsonb not null default '{}'::jsonb,
  add column if not exists diagnostics jsonb not null default '{}'::jsonb,
  add column if not exists last_message_at timestamptz not null default now(),
  add column if not exists last_preview text not null default '',
  add column if not exists unread_for_user boolean not null default false,
  add column if not exists unread_for_staff boolean not null default false,
  add column if not exists assistant_confidence numeric,
  add column if not exists human_requested boolean not null default false,
  add column if not exists escalated_from_team uuid references public.support_teams(id);

alter table public.support_tickets alter column status set default 'new';

alter table public.support_messages
  add column if not exists sender_type text not null default 'user',
  add column if not exists sender_name text,
  add column if not exists internal boolean not null default false,
  add column if not exists attachments text[] not null default '{}',
  add column if not exists meta jsonb not null default '{}'::jsonb;

-- Old rows: map the old status values and message flags onto the new model.
update public.support_tickets set status = 'open'
  where status is null or status not in ('new', 'assistant_replied', 'open', 'pending_user', 'escalated', 'resolved', 'closed');
update public.support_messages set sender_type = 'agent' where is_agent is true and sender_type = 'user';

alter table public.support_tickets drop constraint if exists support_tickets_status_chk;
alter table public.support_tickets add constraint support_tickets_status_chk
  check (status in ('new', 'assistant_replied', 'open', 'pending_user', 'escalated', 'resolved', 'closed'));
alter table public.support_tickets drop constraint if exists support_tickets_priority_chk;
alter table public.support_tickets add constraint support_tickets_priority_chk
  check (priority in ('low', 'normal', 'high', 'urgent'));
alter table public.support_tickets drop constraint if exists support_tickets_csat_chk;
alter table public.support_tickets add constraint support_tickets_csat_chk check (csat is null or csat between 1 and 5);
alter table public.support_messages drop constraint if exists support_messages_sender_type_chk;
alter table public.support_messages add constraint support_messages_sender_type_chk
  check (sender_type in ('user', 'agent', 'assistant', 'system', 'note'));

create index if not exists support_tickets_team_status_idx on public.support_tickets (team_id, status);
create index if not exists support_tickets_assignee_idx on public.support_tickets (assigned_agent_id, status);
create index if not exists support_tickets_user_idx2 on public.support_tickets (user_id, last_message_at desc);
create index if not exists support_tickets_breach_idx on public.support_tickets (status, breached);
create index if not exists support_messages_ticket_created_idx on public.support_messages (ticket_id, created_at);

-- ---------------------------------------------------------------------------
-- 4. Seed data (never overwrites what an admin has edited)
-- ---------------------------------------------------------------------------
insert into public.support_teams (key, name, description, sort_order, is_default) values
  ('accounts',  'Accounts and Verification', 'Sign in problems, account recovery, profile changes and verification.', 1, false),
  ('payments',  'Payments and Wallet',       'Wallet funding, withdrawals, refunds and payment disputes.', 2, false),
  ('shop',      'Orders and Shop',           'Store orders, delivery and product questions.', 3, false),
  ('rewards',   'Competitions and Rewards',  'Competition results, prizes and reward questions.', 4, false),
  ('technical', 'Technical Support',         'App crashes, bugs and login or device problems.', 5, false),
  ('safety',    'Trust and Safety',          'Abuse reports, account security and safety concerns.', 6, false),
  ('care',      'General Care',              'Everything else: game rules, houses, feedback and general questions.', 7, true)
on conflict (key) do nothing;

insert into public.support_categories (key, label, team_key, default_priority, auto_resolve_allowed, sort_order) values
  ('account_access',    'Account access',           'accounts',  'high',   false, 1),
  ('verification',      'Verification',             'accounts',  'normal', true,  2),
  ('wallet_funding',    'Wallet funding',           'payments',  'high',   false, 3),
  ('withdrawal',        'Withdrawal',               'payments',  'high',   false, 4),
  ('refund_dispute',    'Refund or dispute',        'payments',  'high',   false, 5),
  ('shop_order',        'Shop order',               'shop',      'normal', false, 6),
  ('delivery',          'Delivery',                 'shop',      'normal', false, 7),
  ('competition_prize', 'Competition or prize',     'rewards',   'high',   false, 8),
  ('game_rules',        'Game rules',               'care',      'low',    true,  9),
  ('gameplay_bug',      'Gameplay bug',             'technical', 'normal', false, 10),
  ('app_crash',         'App crash',                'technical', 'high',   false, 11),
  ('login_problem',     'Login problem',            'technical', 'normal', false, 12),
  ('report_abuse',      'Report abuse',             'safety',    'high',   false, 13),
  ('security_concern',  'Security concern',         'safety',    'urgent', false, 14),
  ('house_community',   'Houses and community',     'care',      'low',    true,  15),
  ('feedback',          'Feedback',                 'care',      'low',    true,  16),
  ('other',             'Something else',           'care',      'normal', true,  17)
on conflict (key) do nothing;

insert into public.support_sla (priority, first_response_min, resolution_min) values
  ('urgent', 15, 240), ('high', 60, 720), ('normal', 240, 2880), ('low', 720, 7200)
on conflict (priority) do nothing;

-- Existing tickets get a team and a subject so they appear in the desk.
update public.support_tickets set subject = left(regexp_replace(coalesce(issue, 'Support request'), '\s+', ' ', 'g'), 80) where subject is null;
update public.support_tickets set team_id = (select id from public.support_teams where key = 'care') where team_id is null;
update public.support_tickets set last_message_at = coalesce(updated_at, created_at, now()) where last_message_at is null;

-- ---------------------------------------------------------------------------
-- 5. Text helpers (internal)
-- ---------------------------------------------------------------------------
create or replace function public.support_i_clean(p text, p_max int default 2000)
returns text language sql immutable set search_path = public, pg_temp as $$
  select left(btrim(regexp_replace(coalesce(p, ''), '[\x01-\x08\x0B\x0C\x0E-\x1F\x7F]', '', 'g')), greatest(p_max, 0));
$$;

-- Card-like digit runs and "password: xyz" style secrets never get stored.
create or replace function public.support_i_scrub_secrets(p text)
returns text language sql immutable set search_path = public, pg_temp as $$
  select regexp_replace(
    regexp_replace(coalesce(p, ''), '\d(?:[ -]?\d){12,18}', '[number removed]', 'g'),
    '\m(password|passcode|passwd|pin|otp)\M\s*(?::|=|\mis\M)\s*\S+', '\1: [removed]', 'gi');
$$;

-- Used for training exports: also removes emails and phone or account numbers.
create or replace function public.support_i_scrub_pii(p text)
returns text language sql immutable set search_path = public, pg_temp as $$
  select regexp_replace(
    regexp_replace(public.support_i_scrub_secrets(p), '[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}', '[email]', 'g'),
    '\+?\d[\d ()\-]{7,}\d', '[phone]', 'g');
$$;

create or replace function public.support_i_human_minutes(p_min int)
returns text language sql immutable set search_path = public, pg_temp as $$
  select case
    when p_min < 60 then p_min || ' minutes'
    when p_min < 1440 then (p_min / 60) || case when p_min / 60 = 1 then ' hour' else ' hours' end
    else (p_min / 1440) || case when p_min / 1440 = 1 then ' day' else ' days' end end;
$$;

create or replace function public.support_i_prio_rank(p text)
returns int language sql immutable set search_path = public, pg_temp as $$
  select case p when 'urgent' then 4 when 'high' then 3 when 'normal' then 2 when 'low' then 1 else 2 end;
$$;

-- ---------------------------------------------------------------------------
-- 6. Access predicates (usable from RLS policies)
-- ---------------------------------------------------------------------------
create or replace function public.support_staff_of(p_team uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select auth.uid() is not null and (
    public.identity_is_admin()
    or exists (select 1 from public.support_team_members m
               where m.team_id = p_team and m.user_id = auth.uid() and m.active));
$$;

create or replace function public.support_is_lead(p_team uuid)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select auth.uid() is not null and (
    public.identity_is_admin()
    or exists (select 1 from public.support_team_members m
               where m.team_id = p_team and m.user_id = auth.uid() and m.active and m.role = 'lead'));
$$;

create or replace function public.support_is_staff_any()
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select auth.uid() is not null and (
    public.identity_is_admin()
    or exists (select 1 from public.support_team_members m where m.user_id = auth.uid() and m.active));
$$;

-- 'owner' for the ticket's user, 'staff' for the ticket's team or admins, else null.
create or replace function public.support_ticket_access(p_ticket uuid)
returns text language sql stable security definer set search_path = public, pg_temp as $$
  select case
    when t.user_id = auth.uid() then 'owner'
    when public.support_staff_of(t.team_id) then 'staff'
    else null end
  from public.support_tickets t where t.id = p_ticket;
$$;

-- Lets the storage policy decide who may read an attachment: its uploader, the
-- ticket owner, and staff of the ticket's team.
create or replace function public.support_can_read_attachment(p_path text)
returns boolean language sql stable security definer set search_path = public, pg_temp as $$
  select auth.uid() is not null and exists (
    select 1 from public.support_messages m
    where p_path = any (m.attachments)
      and public.support_ticket_access(m.ticket_id) is not null
      and (not m.internal or public.support_ticket_access(m.ticket_id) = 'staff'));
$$;

create or replace function public.support_i_need_admin()
returns void language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if auth.uid() is null or not public.identity_is_admin() then
    raise exception 'support: admins only' using errcode = '42501';
  end if;
end $$;

-- Returns the ticket when the caller is staff for its team (and not its owner, unless admin).
create or replace function public.support_i_need_staff(p_ticket uuid)
returns public.support_tickets language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets;
begin
  if auth.uid() is null then raise exception 'support: sign in required' using errcode = '42501'; end if;
  select * into t from public.support_tickets where id = p_ticket;
  if not found then raise exception 'support: ticket not found' using errcode = 'P0002'; end if;
  if not public.support_staff_of(t.team_id) or (t.user_id = auth.uid() and not public.identity_is_admin()) then
    raise exception 'support: not authorised' using errcode = '42501';
  end if;
  return t;
end $$;

create or replace function public.support_i_need_owner(p_ticket uuid)
returns public.support_tickets language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets;
begin
  if auth.uid() is null then raise exception 'support: sign in required' using errcode = '42501'; end if;
  select * into t from public.support_tickets where id = p_ticket and user_id = auth.uid();
  if not found then raise exception 'support: ticket not found' using errcode = 'P0002'; end if;
  return t;
end $$;

-- ---------------------------------------------------------------------------
-- 7. JSON builders (internal)
-- ---------------------------------------------------------------------------
create or replace function public.support_i_ticket_json(p_id uuid, p_for_user boolean default false)
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'id', t.id,
    'user_id', t.user_id,
    'user_name', coalesce(u.display_name, u.username, 'User'),
    'subject', coalesce(t.subject, left(t.issue, 80)),
    'category', t.category,
    'priority', t.priority,
    'status', t.status,
    'team_key', tm.key,
    'team_name', tm.name,
    'assignee_id', t.assigned_agent_id,
    'assignee_name', coalesce(a.display_name, a.username),
    'summary', case when p_for_user then null else t.summary end,
    'created_at', t.created_at,
    'updated_at', t.updated_at,
    'first_response_due', t.first_response_due,
    'resolution_due', t.resolution_due,
    'first_response_at', t.first_response_at,
    'resolved_at', t.resolved_at,
    'breached', t.breached,
    'unread_for_user', t.unread_for_user,
    'unread_for_staff', t.unread_for_staff,
    'csat', t.csat,
    'last_preview', t.last_preview)
  from public.support_tickets t
  left join public.profiles u on u.id = t.user_id
  left join public.profiles a on a.id = t.assigned_agent_id
  left join public.support_teams tm on tm.id = t.team_id
  where t.id = p_id;
$$;

create or replace function public.support_i_msg_json(m public.support_messages)
returns jsonb language sql immutable set search_path = public, pg_temp as $$
  select jsonb_build_object(
    'id', m.id, 'ticket_id', m.ticket_id, 'sender_type', m.sender_type,
    'sender_name', coalesce(m.sender_name, case m.sender_type when 'assistant' then 'Ryan' when 'system' then 'GACOM Support' else 'Support' end),
    'body', m.message, 'internal', m.internal, 'attachments', to_jsonb(coalesce(m.attachments, '{}'::text[])),
    'created_at', m.created_at, 'meta', coalesce(m.meta, '{}'::jsonb));
$$;

create or replace function public.support_i_name(p_user uuid, p_fallback text default 'Support')
returns text language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce((select coalesce(display_name, username) from public.profiles where id = p_user), p_fallback);
$$;

-- ---------------------------------------------------------------------------
-- 8. Rate limiting (12 per minute, 60 per hour per user), internal
-- ---------------------------------------------------------------------------
create or replace function public.support_i_rate_hit(p_user uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare m int; h int;
begin
  delete from public.support_rate where user_id = p_user and window_start < now() - interval '3 hours';
  insert into public.support_rate (user_id, bucket, window_start, n)
    values (p_user, 'minute', date_trunc('minute', now()), 1)
    on conflict (user_id, bucket, window_start) do update set n = public.support_rate.n + 1
    returning n into m;
  insert into public.support_rate (user_id, bucket, window_start, n)
    values (p_user, 'hour', date_trunc('hour', now()), 1)
    on conflict (user_id, bucket, window_start) do update set n = public.support_rate.n + 1
    returning n into h;
  if m > 12 or h > 60 then
    raise exception 'support: rate limited' using errcode = '54000';
  end if;
end $$;

-- ---------------------------------------------------------------------------
-- 9. Messages, SLA, assignment and routing (internal)
-- ---------------------------------------------------------------------------
create or replace function public.support_i_add_message(
  p_ticket uuid, p_sender uuid, p_type text, p_name text, p_body text,
  p_internal boolean default false, p_atts text[] default '{}', p_meta jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare m public.support_messages;
begin
  insert into public.support_messages (ticket_id, sender_id, message, is_agent, sender_type, sender_name, internal, attachments, meta)
  values (p_ticket, p_sender, p_body, p_type = 'agent', p_type, p_name, coalesce(p_internal, false), coalesce(p_atts, '{}'), coalesce(p_meta, '{}'::jsonb))
  returning * into m;
  update public.support_tickets set
    updated_at = now(),
    last_message_at = now(),
    last_preview = case when m.internal then last_preview else left(regexp_replace(p_body, '\s+', ' ', 'g'), 120) end,
    unread_for_staff = case when p_type = 'user' then true else unread_for_staff end,
    unread_for_user = case when p_type in ('agent', 'assistant', 'system') and not m.internal then true else unread_for_user end
  where id = p_ticket;
  return public.support_i_msg_json(m);
end $$;

create or replace function public.support_i_sla_min(p_priority text, p_kind text)
returns int language sql stable set search_path = public, pg_temp as $$
  select coalesce(
    (select case when p_kind = 'first' then first_response_min else resolution_min end from public.support_sla where priority = p_priority),
    case when p_kind = 'first' then 240 else 2880 end);
$$;

create or replace function public.support_i_set_due(p_ticket uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.support_tickets t set
    first_response_due = case when t.first_response_at is null
      then t.created_at + make_interval(mins => public.support_i_sla_min(t.priority, 'first')) else t.first_response_due end,
    resolution_due = t.created_at + make_interval(mins => public.support_i_sla_min(t.priority, 'res'))
  where t.id = p_ticket;
end $$;

create or replace function public.support_i_notify_leads(p_team uuid, p_title text, p_body text, p_data jsonb)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare r record; n int := 0;
begin
  for r in select user_id from public.support_team_members where team_id = p_team and active and role = 'lead' loop
    perform public.identity_notify(r.user_id, p_title, p_body, p_data);
    n := n + 1;
  end loop;
  if n = 0 then
    for r in select id as user_id from public.profiles where role::text in ('admin', 'super_admin') limit 20 loop
      perform public.identity_notify(r.user_id, p_title, p_body, p_data);
    end loop;
  end if;
end $$;

-- Goes to the active member with the fewest open tickets who is under their cap.
-- Returns the assignee, or null when everybody is full (the ticket then waits in the team queue).
create or replace function public.support_i_auto_assign(p_ticket uuid)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets; pick uuid;
begin
  select * into t from public.support_tickets where id = p_ticket for update;
  if not found or t.team_id is null or t.assigned_agent_id is not null or t.status in ('resolved', 'closed') then
    return t.assigned_agent_id;
  end if;
  select c.user_id into pick from (
    select m.user_id, m.cap, m.last_assigned_at,
      (select count(*) from public.support_tickets x
        where x.assigned_agent_id = m.user_id and x.status in ('new', 'open', 'pending_user', 'escalated')) as open_n
    from public.support_team_members m
    where m.team_id = t.team_id and m.active and m.user_id <> t.user_id
  ) c
  where c.open_n < c.cap
  order by c.open_n asc, c.last_assigned_at asc nulls first
  limit 1;
  if pick is null then return null; end if;
  update public.support_tickets set
    assigned_agent_id = pick,
    status = case when status in ('new', 'assistant_replied') then 'open' else status end,
    updated_at = now()
  where id = p_ticket;
  update public.support_team_members set last_assigned_at = now() where team_id = t.team_id and user_id = pick;
  perform public.identity_notify(pick, 'New support ticket assigned',
    left(coalesce(t.subject, t.issue), 100), jsonb_build_object('type', 'support', 'ticket_id', p_ticket));
  return pick;
end $$;

-- Puts a ticket into its team's queue: team, SLA clock, assignment, urgent alert.
create or replace function public.support_i_route(p_ticket uuid, p_status text default 'open')
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets; tk uuid;
begin
  select * into t from public.support_tickets where id = p_ticket for update;
  if not found then return; end if;
  if t.team_id is null then
    select id into tk from public.support_teams where key = (select team_key from public.support_categories where key = t.category);
    if tk is null then select id into tk from public.support_teams where is_default limit 1; end if;
    update public.support_tickets set team_id = tk where id = p_ticket;
  end if;
  update public.support_tickets set
    status = case when status in ('resolved', 'closed') then status else coalesce(p_status, status) end,
    updated_at = now()
  where id = p_ticket;
  perform public.support_i_set_due(p_ticket);
  perform public.support_i_auto_assign(p_ticket);
  select * into t from public.support_tickets where id = p_ticket;
  if t.priority = 'urgent' then
    perform public.support_i_notify_leads(t.team_id, 'Urgent support ticket',
      left(coalesce(t.subject, t.issue), 100), jsonb_build_object('type', 'support', 'ticket_id', p_ticket));
  end if;
end $$;

-- Gives the oldest waiting ticket of a team to whoever now has room.
create or replace function public.support_i_drain(p_team uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
declare r record; n int := 0;
begin
  for r in select id from public.support_tickets
           where team_id = p_team and assigned_agent_id is null and status in ('new', 'open', 'escalated')
           order by public.support_i_prio_rank(priority) desc, created_at asc limit 5 loop
    exit when public.support_i_auto_assign(r.id) is null;
    n := n + 1;
  end loop;
end $$;

create or replace function public.support_i_ack_text(p_ticket uuid)
returns text language sql stable security definer set search_path = public, pg_temp as $$
  select format('Thanks. I have passed this to our %s team. A person will reply within about %s. You do not need to send it again. '
                'For your safety, never share your password, PIN, one-time code or card number with anyone, including us.',
                tm.name, public.support_i_human_minutes(public.support_i_sla_min(t.priority, 'first')))
  from public.support_tickets t join public.support_teams tm on tm.id = t.team_id where t.id = p_ticket;
$$;

-- Creates the ticket and the user's first message. Category defaults to the hint or 'other'.
create or replace function public.support_i_open_ticket(p_user uuid, p_message text, p_hint text, p_device jsonb)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare body text; cat public.support_categories; tid uuid; tk uuid; subj text;
begin
  perform public.support_i_rate_hit(p_user);
  body := public.support_i_scrub_secrets(public.support_i_clean(p_message, 2000));
  if body = '' then raise exception 'support: message is empty' using errcode = '22023'; end if;
  select * into cat from public.support_categories where key = coalesce(p_hint, '') and active;
  if not found then select * into cat from public.support_categories where key = 'other'; end if;
  select id into tk from public.support_teams where key = cat.team_key;
  subj := left(regexp_replace(split_part(body, E'\n', 1), '\s+', ' ', 'g'), 80);
  if subj = '' then subj := 'Support request'; end if;
  insert into public.support_tickets (user_id, issue, subject, status, category, priority, team_id, device_info)
  values (p_user, subj, subj, 'new', cat.key, cat.default_priority, tk,
          case when jsonb_typeof(p_device) = 'object' then p_device else '{}'::jsonb end)
  returning id into tid;
  perform public.support_i_set_due(tid);
  perform public.support_i_add_message(tid, p_user, 'user', public.support_i_name(p_user, 'You'), body);
  return tid;
end $$;

-- Adds a user message to an existing ticket. Reopens a resolved one. Returns the message.
create or replace function public.support_i_post_user_message(p_user uuid, p_ticket uuid, p_body text, p_atts text[])
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets; body text; atts text[]; a text; msg jsonb;
begin
  select * into t from public.support_tickets where id = p_ticket and user_id = p_user for update;
  if not found then raise exception 'support: ticket not found' using errcode = 'P0002'; end if;
  if t.status = 'closed' then raise exception 'support: this ticket is closed' using errcode = '55000'; end if;
  perform public.support_i_rate_hit(p_user);
  body := public.support_i_scrub_secrets(public.support_i_clean(p_body, 2000));
  atts := '{}';
  foreach a in array coalesce(p_atts, '{}') loop
    if a like p_user::text || '/%' and length(a) <= 300 and a !~ '\.\.' and cardinality(atts) < 5 then
      atts := atts || a;
    end if;
  end loop;
  if body = '' and cardinality(atts) = 0 then raise exception 'support: message is empty' using errcode = '22023'; end if;
  if body = '' then body := '(attachment)'; end if;
  msg := public.support_i_add_message(p_ticket, p_user, 'user', public.support_i_name(p_user, 'You'), body, false, atts);
  if t.status = 'resolved' then
    update public.support_tickets set status = 'open', resolved_at = null, breached = false, breached_at = null,
      first_response_at = null, updated_at = now() where id = p_ticket;
    perform public.support_i_reopen_clock(p_ticket);
    perform public.support_i_auto_assign(p_ticket);
  elsif t.status = 'pending_user' then
    update public.support_tickets set status = 'open' where id = p_ticket;
  end if;
  if t.assigned_agent_id is not null and t.status in ('pending_user', 'resolved') then
    perform public.identity_notify(t.assigned_agent_id, 'Customer replied',
      left(coalesce(t.subject, t.issue), 100), jsonb_build_object('type', 'support', 'ticket_id', p_ticket));
  end if;
  return msg;
end $$;

-- Fresh SLA clock after a reopen (the original dues are in the past).
create or replace function public.support_i_reopen_clock(p_ticket uuid)
returns void language plpgsql security definer set search_path = public, pg_temp as $$
begin
  update public.support_tickets t set
    first_response_due = now() + make_interval(mins => public.support_i_sla_min(t.priority, 'first')),
    resolution_due = now() + make_interval(mins => public.support_i_sla_min(t.priority, 'res'))
  where t.id = p_ticket;
end $$;

-- ---------------------------------------------------------------------------
-- 10. Row level security: reads only, no direct writes
-- ---------------------------------------------------------------------------
do $$
declare r record;
begin
  for r in select schemaname, tablename, policyname from pg_policies
           where schemaname = 'public' and tablename in ('support_tickets', 'support_messages') loop
    execute format('drop policy if exists %I on %I.%I', r.policyname, r.schemaname, r.tablename);
  end loop;
end $$;

alter table public.support_tickets enable row level security;
alter table public.support_messages enable row level security;
alter table public.support_teams enable row level security;
alter table public.support_team_members enable row level security;
alter table public.support_categories enable row level security;
alter table public.support_sla enable row level security;
alter table public.support_kb_articles enable row level security;
alter table public.support_macros enable row level security;
alter table public.support_assistant_feedback enable row level security;
alter table public.support_access_log enable row level security;
alter table public.support_rate enable row level security;

drop policy if exists "support tickets read" on public.support_tickets;
create policy "support tickets read" on public.support_tickets for select to authenticated
  using (user_id = auth.uid() or public.support_staff_of(team_id));

drop policy if exists "support messages read" on public.support_messages;
create policy "support messages read" on public.support_messages for select to authenticated
  using (public.support_ticket_access(ticket_id) = 'staff'
         or (public.support_ticket_access(ticket_id) = 'owner' and not internal));

drop policy if exists "support teams read" on public.support_teams;
create policy "support teams read" on public.support_teams for select to authenticated using (true);
drop policy if exists "support categories read" on public.support_categories;
create policy "support categories read" on public.support_categories for select to authenticated using (true);
drop policy if exists "support sla read" on public.support_sla;
create policy "support sla read" on public.support_sla for select to authenticated using (true);
drop policy if exists "support members read own" on public.support_team_members;
create policy "support members read own" on public.support_team_members for select to authenticated
  using (user_id = auth.uid() or public.support_is_lead(team_id));
drop policy if exists "support kb read published" on public.support_kb_articles;
create policy "support kb read published" on public.support_kb_articles for select to authenticated
  using (published or public.support_is_staff_any());
drop policy if exists "support macros read staff" on public.support_macros;
create policy "support macros read staff" on public.support_macros for select to authenticated
  using (public.support_is_staff_any());
drop policy if exists "support feedback read admin" on public.support_assistant_feedback;
create policy "support feedback read admin" on public.support_assistant_feedback for select to authenticated
  using (public.identity_is_admin());
drop policy if exists "support access log read admin" on public.support_access_log;
create policy "support access log read admin" on public.support_access_log for select to authenticated
  using (public.identity_is_admin());
-- support_rate has no policy on purpose: only the SECURITY DEFINER limiter touches it.

revoke all on public.support_tickets, public.support_messages, public.support_teams, public.support_team_members,
  public.support_categories, public.support_sla, public.support_kb_articles, public.support_macros,
  public.support_assistant_feedback, public.support_access_log, public.support_rate from anon, authenticated;
grant select on public.support_tickets, public.support_messages, public.support_teams, public.support_team_members,
  public.support_categories, public.support_sla, public.support_kb_articles, public.support_macros,
  public.support_assistant_feedback, public.support_access_log to authenticated;

-- ---------------------------------------------------------------------------
-- 11. User RPCs
-- ---------------------------------------------------------------------------
create or replace function public.support_start_ticket(p_message text, p_category_hint text default null, p_device jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid(); tid uuid;
begin
  if uid is null then raise exception 'support: sign in required' using errcode = '42501'; end if;
  tid := public.support_i_open_ticket(uid, p_message, p_category_hint, p_device);
  perform public.support_i_route(tid, 'open');
  perform public.support_i_add_message(tid, null, 'system', 'GACOM Support', public.support_i_ack_text(tid));
  return public.support_i_ticket_json(tid, true);
end $$;

create or replace function public.support_my_tickets()
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(public.support_i_ticket_json(x.id, true) order by x.last_message_at desc), '[]'::jsonb)
  from (select id, last_message_at from public.support_tickets where user_id = auth.uid()
        order by last_message_at desc limit 100) x;
$$;

create or replace function public.support_ticket_get(p_ticket uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare acc text := public.support_ticket_access(p_ticket);
begin
  if acc is null then raise exception 'support: ticket not found' using errcode = 'P0002'; end if;
  return public.support_i_ticket_json(p_ticket, acc = 'owner');
end $$;

create or replace function public.support_messages_for(p_ticket uuid, p_after timestamptz default null, p_limit int default 300)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare acc text := public.support_ticket_access(p_ticket); out jsonb;
begin
  if acc is null then raise exception 'support: ticket not found' using errcode = 'P0002'; end if;
  select coalesce(jsonb_agg(public.support_i_msg_json(m) order by m.created_at), '[]'::jsonb) into out
  from (select * from public.support_messages
        where ticket_id = p_ticket and (acc = 'staff' or not internal)
          and (p_after is null or created_at > p_after)
        order by created_at asc limit least(greatest(coalesce(p_limit, 300), 1), 500)) m;
  if acc = 'owner' then
    update public.support_tickets set unread_for_user = false where id = p_ticket and unread_for_user;
  else
    update public.support_tickets set unread_for_staff = false where id = p_ticket and unread_for_staff;
  end if;
  return out;
end $$;

create or replace function public.support_send_user_message(p_ticket uuid, p_body text, p_attachments text[] default '{}')
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid();
begin
  if uid is null then raise exception 'support: sign in required' using errcode = '42501'; end if;
  return public.support_i_post_user_message(uid, p_ticket, p_body, p_attachments);
end $$;

create or replace function public.support_request_human(p_ticket uuid)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets;
begin
  t := public.support_i_need_owner(p_ticket);
  if t.status = 'closed' then raise exception 'support: this ticket is closed' using errcode = '55000'; end if;
  if t.human_requested and t.assigned_agent_id is not null and t.status not in ('resolved') then return true; end if;
  if t.status = 'resolved' then
    update public.support_tickets set status = 'open', resolved_at = null, first_response_at = null, breached = false, breached_at = null where id = p_ticket;
    perform public.support_i_reopen_clock(p_ticket);
  end if;
  update public.support_tickets set human_requested = true where id = p_ticket;
  perform public.support_i_route(p_ticket, 'escalated');
  perform public.support_i_add_message(p_ticket, null, 'system', 'GACOM Support',
    'I have asked a member of our team to join this conversation. A person will reply within about '
    || public.support_i_human_minutes(public.support_i_sla_min((select priority from public.support_tickets where id = p_ticket), 'first')) || '.');
  return true;
end $$;

create or replace function public.support_rate_ticket(p_ticket uuid, p_stars int, p_comment text default '')
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets;
begin
  t := public.support_i_need_owner(p_ticket);
  if p_stars is null or p_stars < 1 or p_stars > 5 then raise exception 'support: rating must be 1 to 5' using errcode = '22023'; end if;
  if t.status not in ('resolved', 'closed') then raise exception 'support: ticket is not resolved yet' using errcode = '55000'; end if;
  update public.support_tickets set csat = p_stars, csat_comment = public.support_i_clean(p_comment, 500), updated_at = now() where id = p_ticket;
  return true;
end $$;

create or replace function public.support_reopen(p_ticket uuid)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets;
begin
  t := public.support_i_need_owner(p_ticket);
  if t.status not in ('resolved', 'closed') then return false; end if;
  if coalesce(t.resolved_at, t.updated_at) < now() - interval '14 days' then
    raise exception 'support: this ticket is too old to reopen, please start a new one' using errcode = '55000';
  end if;
  perform public.support_i_rate_hit(t.user_id);
  update public.support_tickets set status = 'open', resolved_at = null, closed_at = null, first_response_at = null,
    breached = false, breached_at = null, updated_at = now() where id = p_ticket;
  perform public.support_i_reopen_clock(p_ticket);
  perform public.support_i_add_message(p_ticket, null, 'system', 'GACOM Support', 'This conversation was reopened. Our team will pick it up.');
  perform public.support_i_auto_assign(p_ticket);
  select * into t from public.support_tickets where id = p_ticket;
  if t.assigned_agent_id is not null then
    perform public.identity_notify(t.assigned_agent_id, 'Ticket reopened', left(coalesce(t.subject, t.issue), 100),
      jsonb_build_object('type', 'support', 'ticket_id', p_ticket));
  end if;
  return true;
end $$;

-- Thumbs up or down on an assistant message (the owner or staff of the ticket).
create or replace function public.support_rate_assistant(p_message uuid, p_helpful boolean, p_correction text default '')
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare m public.support_messages; uid uuid := auth.uid();
begin
  if uid is null then raise exception 'support: sign in required' using errcode = '42501'; end if;
  select * into m from public.support_messages where id = p_message and sender_type = 'assistant';
  if not found or public.support_ticket_access(m.ticket_id) is null then
    raise exception 'support: message not found' using errcode = 'P0002';
  end if;
  insert into public.support_assistant_feedback (message_id, ticket_id, user_id, helpful, correction)
  values (p_message, m.ticket_id, uid, coalesce(p_helpful, false), public.support_i_scrub_secrets(public.support_i_clean(p_correction, 1000)))
  on conflict (message_id, user_id) do update set helpful = excluded.helpful, correction = excluded.correction, created_at = now();
  return true;
end $$;

-- ---------------------------------------------------------------------------
-- 12. Staff RPCs
-- ---------------------------------------------------------------------------
create or replace function public.support_my_teams()
returns jsonb language sql stable security definer set search_path = public, pg_temp as $$
  select coalesce(jsonb_agg(jsonb_build_object('key', tm.key, 'name', tm.name, 'description', tm.description) order by tm.sort_order), '[]'::jsonb)
  from public.support_teams tm
  where auth.uid() is not null and (public.identity_is_admin()
    or exists (select 1 from public.support_team_members m where m.team_id = tm.id and m.user_id = auth.uid() and m.active));
$$;

create or replace function public.support_desk_queue(
  p_team text default null, p_status text default null, p_mine boolean default false,
  p_breached boolean default false, p_limit int default 50, p_offset int default 0)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare uid uuid := auth.uid(); admin boolean;
begin
  if not public.support_is_staff_any() then raise exception 'support: not authorised' using errcode = '42501'; end if;
  admin := public.identity_is_admin();
  return (
    select coalesce(jsonb_agg(public.support_i_ticket_json(x.id, false) order by x.ord1 desc, x.ord2 desc, x.created_at asc), '[]'::jsonb)
    from (
      select t.id, t.created_at,
             (case when t.breached then 1 else 0 end) as ord1,
             public.support_i_prio_rank(t.priority) as ord2
      from public.support_tickets t
      join public.support_teams tm on tm.id = t.team_id
      where (admin or exists (select 1 from public.support_team_members m
                              where m.team_id = t.team_id and m.user_id = uid and m.active))
        and (t.user_id <> uid or admin)
        and (p_team is null or tm.key = p_team)
        and case when p_status is null then t.status not in ('resolved', 'closed')
                 when p_status = 'all' then true
                 else t.status = p_status end
        and (not coalesce(p_mine, false) or t.assigned_agent_id = uid)
        and (not coalesce(p_breached, false) or t.breached)
      order by ord1 desc, ord2 desc, t.created_at asc
      limit least(greatest(coalesce(p_limit, 50), 1), 200) offset greatest(coalesce(p_offset, 0), 0)
    ) x);
end $$;

create or replace function public.support_claim(p_ticket uuid)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets; uid uuid := auth.uid();
begin
  t := public.support_i_need_staff(p_ticket);
  if t.status in ('resolved', 'closed') then raise exception 'support: ticket is already resolved' using errcode = '55000'; end if;
  if t.assigned_agent_id is not null and t.assigned_agent_id <> uid and not public.support_is_lead(t.team_id) then
    raise exception 'support: already assigned to someone else' using errcode = '55000';
  end if;
  update public.support_tickets set assigned_agent_id = uid, updated_at = now(),
    status = case when status in ('new', 'assistant_replied') then 'open' else status end where id = p_ticket;
  if t.assigned_agent_id is not null and t.assigned_agent_id <> uid then
    perform public.identity_notify(t.assigned_agent_id, 'Ticket reassigned', left(coalesce(t.subject, t.issue), 100),
      jsonb_build_object('type', 'support', 'ticket_id', p_ticket));
  end if;
  return true;
end $$;

create or replace function public.support_assign(p_ticket uuid, p_user uuid)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets;
begin
  t := public.support_i_need_staff(p_ticket);
  if not public.support_is_lead(t.team_id) then raise exception 'support: only team leads can assign' using errcode = '42501'; end if;
  if t.status in ('resolved', 'closed') then raise exception 'support: ticket is already resolved' using errcode = '55000'; end if;
  if p_user is null or not exists (select 1 from public.support_team_members m where m.team_id = t.team_id and m.user_id = p_user and m.active) then
    raise exception 'support: that person is not an active member of this team' using errcode = '22023';
  end if;
  if p_user = t.user_id then raise exception 'support: cannot assign a ticket to its owner' using errcode = '22023'; end if;
  update public.support_tickets set assigned_agent_id = p_user, updated_at = now(),
    status = case when status in ('new', 'assistant_replied') then 'open' else status end where id = p_ticket;
  if p_user <> auth.uid() then
    perform public.identity_notify(p_user, 'New support ticket assigned', left(coalesce(t.subject, t.issue), 100),
      jsonb_build_object('type', 'support', 'ticket_id', p_ticket));
  end if;
  return true;
end $$;

create or replace function public.support_set_routing(p_ticket uuid, p_category text default null, p_team text default null, p_priority text default null)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets; cat public.support_categories; newteam uuid; newprio text;
begin
  t := public.support_i_need_staff(p_ticket);
  if t.status = 'closed' then raise exception 'support: ticket is closed' using errcode = '55000'; end if;
  if p_priority is not null and p_priority not in ('low', 'normal', 'high', 'urgent') then
    raise exception 'support: invalid priority' using errcode = '22023';
  end if;
  newteam := t.team_id;
  if p_category is not null then
    select * into cat from public.support_categories where key = p_category;
    if not found then raise exception 'support: unknown category' using errcode = '22023'; end if;
    if p_team is null then select id into newteam from public.support_teams where key = cat.team_key; end if;
  end if;
  if p_team is not null then
    select id into newteam from public.support_teams where key = p_team;
    if newteam is null then raise exception 'support: unknown team' using errcode = '22023'; end if;
  end if;
  newprio := coalesce(p_priority, t.priority);
  update public.support_tickets set
    category = coalesce(p_category, category),
    priority = newprio,
    team_id = newteam,
    assigned_agent_id = case when newteam is distinct from t.team_id then null else assigned_agent_id end,
    escalated_from_team = case when newteam is distinct from t.team_id then t.team_id else escalated_from_team end,
    updated_at = now()
  where id = p_ticket;
  perform public.support_i_set_due(p_ticket);
  if newteam is distinct from t.team_id then
    perform public.support_i_auto_assign(p_ticket);
  end if;
  if newprio = 'urgent' and t.priority <> 'urgent' then
    perform public.support_i_notify_leads(newteam, 'Urgent support ticket', left(coalesce(t.subject, t.issue), 100),
      jsonb_build_object('type', 'support', 'ticket_id', p_ticket));
  end if;
  return true;
end $$;

create or replace function public.support_reply(p_ticket uuid, p_body text, p_attachments text[] default '{}', p_macro uuid default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets; uid uuid := auth.uid(); body text; atts text[] := '{}'; a text; msg jsonb; mb text;
begin
  t := public.support_i_need_staff(p_ticket);
  if t.status = 'closed' then raise exception 'support: ticket is closed' using errcode = '55000'; end if;
  body := public.support_i_clean(p_body, 4000);
  if body = '' and p_macro is not null then
    select m.body into mb from public.support_macros m where m.id = p_macro and m.active;
    body := public.support_i_clean(replace(replace(coalesce(mb, ''), '{{name}}', public.support_i_name(t.user_id, 'there')),
                                           '{{agent}}', public.support_i_name(uid)), 4000);
  end if;
  foreach a in array coalesce(p_attachments, '{}') loop
    if a like uid::text || '/%' and length(a) <= 300 and a !~ '\.\.' and cardinality(atts) < 5 then atts := atts || a; end if;
  end loop;
  if body = '' and cardinality(atts) = 0 then raise exception 'support: reply is empty' using errcode = '22023'; end if;
  if body = '' then body := '(attachment)'; end if;
  msg := public.support_i_add_message(p_ticket, uid, 'agent', public.support_i_name(uid), body, false, atts,
           case when p_macro is null then '{}'::jsonb else jsonb_build_object('macro_id', p_macro) end);
  update public.support_tickets set
    first_response_at = coalesce(first_response_at, now()),
    assigned_agent_id = coalesce(assigned_agent_id, uid),
    status = case when status in ('resolved') then status else 'pending_user' end,
    updated_at = now()
  where id = p_ticket;
  perform public.identity_notify(t.user_id, 'Reply from GACOM Support', left(body, 120),
    jsonb_build_object('type', 'support', 'ticket_id', p_ticket));
  return msg;
end $$;

create or replace function public.support_add_note(p_ticket uuid, p_body text)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets; body text;
begin
  t := public.support_i_need_staff(p_ticket);
  body := public.support_i_clean(p_body, 4000);
  if body = '' then raise exception 'support: note is empty' using errcode = '22023'; end if;
  perform public.support_i_add_message(p_ticket, auth.uid(), 'note', public.support_i_name(auth.uid()), body, true);
  return true;
end $$;

create or replace function public.support_resolve(p_ticket uuid, p_note text default '')
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets; uid uuid := auth.uid(); note text;
begin
  t := public.support_i_need_staff(p_ticket);
  if t.status in ('resolved', 'closed') then return true; end if;
  note := public.support_i_clean(p_note, 2000);
  if note <> '' then
    perform public.support_i_add_message(p_ticket, uid, 'note', public.support_i_name(uid), 'Resolution note: ' || note, true);
  end if;
  update public.support_tickets set status = 'resolved', resolved_at = now(),
    first_response_at = coalesce(first_response_at, now()),
    assigned_agent_id = coalesce(assigned_agent_id, uid), updated_at = now() where id = p_ticket;
  perform public.support_i_add_message(p_ticket, null, 'system', 'GACOM Support',
    'This conversation was marked resolved. If something is still wrong you can reopen it within 14 days. Please rate your experience.');
  perform public.identity_notify(t.user_id, 'Your support request was resolved', left(coalesce(t.subject, t.issue), 100),
    jsonb_build_object('type', 'support', 'ticket_id', p_ticket));
  perform public.support_i_drain(t.team_id);
  return true;
end $$;

create or replace function public.support_escalate_technical(p_ticket uuid, p_note text)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets; tk uuid; note text;
begin
  t := public.support_i_need_staff(p_ticket);
  if t.status in ('resolved', 'closed') then raise exception 'support: ticket is already resolved' using errcode = '55000'; end if;
  select id into tk from public.support_teams where key = 'technical';
  note := public.support_i_clean(p_note, 2000);
  if note = '' then raise exception 'support: please add a note for the technical team' using errcode = '22023'; end if;
  perform public.support_i_add_message(p_ticket, auth.uid(), 'note', public.support_i_name(auth.uid()), 'Escalated to Technical Support: ' || note, true);
  update public.support_tickets set
    escalated_from_team = case when team_id is distinct from tk then team_id else escalated_from_team end,
    team_id = tk, assigned_agent_id = null, status = 'escalated', updated_at = now()
  where id = p_ticket;
  perform public.support_i_set_due(p_ticket);
  perform public.support_i_auto_assign(p_ticket);
  perform public.support_i_add_message(p_ticket, null, 'system', 'GACOM Support',
    'We have passed this to our Technical Support team for a closer look. We will update you here.');
  perform public.identity_notify(t.user_id, 'Your support request is with our technical team', left(coalesce(t.subject, t.issue), 100),
    jsonb_build_object('type', 'support', 'ticket_id', p_ticket));
  perform public.support_i_notify_leads(tk, 'Ticket escalated to Technical Support', left(coalesce(t.subject, t.issue), 100),
    jsonb_build_object('type', 'support', 'ticket_id', p_ticket));
  return true;
end $$;

-- Account snapshot for an agent. Every lookup is written to support_access_log.
create or replace function public.support_user_context(p_ticket uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets; prof jsonb; w jsonb := '[]'; o jsonb := '[]'; e jsonb := '[]'; rt jsonb := '[]';
begin
  t := public.support_i_need_staff(p_ticket);
  insert into public.support_access_log (viewer_id, ticket_id, subject_user_id, action) values (auth.uid(), p_ticket, t.user_id, 'user_context');
  select coalesce(jsonb_object_agg(k, v), '{}'::jsonb) into prof
  from public.profiles p, lateral jsonb_each(to_jsonb(p)) as kv(k, v)
  where p.id = t.user_id and k = any (array['id', 'username', 'display_name', 'role', 'verification_status', 'wallet_balance',
    'wallet_locked_balance', 'is_banned', 'ban_reason', 'created_at', 'last_seen', 'location']);
  begin
    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into w from (
      select id, type::text as type, amount, status::text as status, reference, left(coalesce(description, ''), 120) as description, created_at
      from public.wallet_transactions where user_id = t.user_id order by created_at desc limit 10) x;
  exception when others then w := '[]'; end;
  begin
    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into o from (
      select id, reference, status, total, created_at from public.orders where user_id = t.user_id order by created_at desc limit 5) x;
  exception when others then o := '[]'; end;
  begin
    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into e from (
      select id, left(error, 300) as error, route, created_at from public.error_logs where user_id = t.user_id order by created_at desc limit 5) x;
  exception when others then e := '[]'; end;
  select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into rt from (
    select id, coalesce(subject, left(issue, 80)) as subject, category, status, created_at
    from public.support_tickets where user_id = t.user_id and id <> p_ticket order by created_at desc limit 5) x;
  return jsonb_build_object('profile', prof, 'recent_wallet', w, 'recent_orders', o, 'recent_errors', e, 'recent_tickets', rt);
end $$;

create or replace function public.support_team_stats(p_team text)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare tm public.support_teams; r jsonb;
begin
  select * into tm from public.support_teams where key = p_team;
  if not found or not public.support_staff_of(tm.id) then raise exception 'support: not authorised' using errcode = '42501'; end if;
  select jsonb_build_object(
    'open', count(*) filter (where status not in ('resolved', 'closed')),
    'breached', count(*) filter (where breached and status not in ('resolved', 'closed')),
    'unassigned', count(*) filter (where assigned_agent_id is null and status not in ('resolved', 'closed')),
    'resolved_today', count(*) filter (where status in ('resolved', 'closed') and resolved_at >= date_trunc('day', now() at time zone 'Africa/Lagos') at time zone 'Africa/Lagos'),
    'avg_first_response_min', coalesce(round((avg(extract(epoch from (first_response_at - created_at)) / 60.0)
        filter (where first_response_at is not null and created_at > now() - interval '30 days'))::numeric, 1), 0),
    'csat_avg', coalesce(round((avg(csat) filter (where csat is not null and created_at > now() - interval '90 days'))::numeric, 2), 0))
  into r from public.support_tickets where team_id = tm.id;
  return r;
end $$;

create or replace function public.support_macros_list(p_category text default null)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public.support_is_staff_any() then raise exception 'support: not authorised' using errcode = '42501'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id', m.id, 'title', m.title, 'body', m.body, 'category_key', m.category_key)
            order by (m.category_key is null), m.title), '[]'::jsonb)
          from public.support_macros m
          where m.active and (p_category is null or m.category_key is null or m.category_key = p_category));
end $$;

create or replace function public.support_categories_list()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not public.support_is_staff_any() then raise exception 'support: not authorised' using errcode = '42501'; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('key', c.key, 'label', c.label, 'team_key', c.team_key,
            'default_priority', c.default_priority, 'auto_resolve_allowed', c.auto_resolve_allowed) order by c.sort_order), '[]'::jsonb)
          from public.support_categories c where c.active);
end $$;

-- Saves an agent's answer as a draft knowledge article (an admin publishes it).
create or replace function public.support_save_kb(p_ticket uuid, p_title text, p_answer text, p_category text default null)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare t public.support_tickets; rid uuid; v_title text; ans text; cat text;
begin
  t := public.support_i_need_staff(p_ticket);
  v_title := public.support_i_clean(p_title, 160);
  ans := public.support_i_scrub_pii(public.support_i_clean(p_answer, 4000));
  if v_title = '' or ans = '' then raise exception 'support: title and answer are required' using errcode = '22023'; end if;
  select key into cat from public.support_categories where key = coalesce(p_category, t.category);
  insert into public.support_kb_articles (title, body, category_key, published, source_ticket_id, created_by)
  values (v_title, ans, cat, false, p_ticket, auth.uid()) returning id into rid;
  return rid;
end $$;

-- ---------------------------------------------------------------------------
-- 13. Admin RPCs
-- ---------------------------------------------------------------------------
create or replace function public.support_admin_teams()
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public.support_i_need_admin();
  return (select coalesce(jsonb_agg(jsonb_build_object('key', key, 'name', name, 'description', description) order by sort_order), '[]'::jsonb)
          from public.support_teams);
end $$;

create or replace function public.support_admin_team_members(p_team text)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare tid uuid;
begin
  -- Admins, and the leads of this team (the desk uses this to assign tickets).
  select id into tid from public.support_teams where key = p_team;
  if auth.uid() is null or not (public.identity_is_admin() or (tid is not null and public.support_is_lead(tid))) then
    raise exception 'support: not authorised' using errcode = '42501';
  end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('userId', m.user_id, 'name', coalesce(p.display_name, p.username, 'Unknown'),
            'username', p.username, 'role', m.role, 'active', m.active, 'cap', m.cap,
            'open', (select count(*) from public.support_tickets x where x.assigned_agent_id = m.user_id
                      and x.status in ('new', 'open', 'pending_user', 'escalated'))) order by m.role desc, p.display_name), '[]'::jsonb)
          from public.support_team_members m join public.support_teams tm on tm.id = m.team_id
          left join public.profiles p on p.id = m.user_id where tm.key = p_team);
end $$;

create or replace function public.support_admin_set_member(p_team text, p_user uuid, p_role text, p_active boolean default true, p_cap int default null)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare tk uuid;
begin
  perform public.support_i_need_admin();
  if p_role not in ('agent', 'lead') then raise exception 'support: role must be agent or lead' using errcode = '22023'; end if;
  select id into tk from public.support_teams where key = p_team;
  if tk is null then raise exception 'support: unknown team' using errcode = '22023'; end if;
  if not exists (select 1 from public.profiles where id = p_user) then raise exception 'support: unknown user' using errcode = '22023'; end if;
  insert into public.support_team_members (team_id, user_id, role, active, cap)
  values (tk, p_user, p_role, coalesce(p_active, true), coalesce(p_cap, 10))
  on conflict (team_id, user_id) do update set role = excluded.role, active = excluded.active,
    cap = case when p_cap is null then public.support_team_members.cap else excluded.cap end;
  if coalesce(p_active, true) then perform public.support_i_drain(tk); end if;
  return true;
end $$;

create or replace function public.support_admin_remove_member(p_team text, p_user uuid)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
declare tk uuid;
begin
  perform public.support_i_need_admin();
  select id into tk from public.support_teams where key = p_team;
  if tk is null then raise exception 'support: unknown team' using errcode = '22023'; end if;
  delete from public.support_team_members where team_id = tk and user_id = p_user;
  -- their open tickets go back to the queue
  update public.support_tickets set assigned_agent_id = null, updated_at = now()
    where team_id = tk and assigned_agent_id = p_user and status not in ('resolved', 'closed');
  perform public.support_i_drain(tk);
  return true;
end $$;

create or replace function public.support_admin_find_users(p_query text)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare q text;
begin
  perform public.support_i_need_admin();
  q := public.support_i_clean(p_query, 60);
  if length(q) < 2 then return '[]'::jsonb; end if;
  q := '%' || replace(replace(replace(q, '\', '\\'), '%', '\%'), '_', '\_') || '%';
  return (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'name', coalesce(display_name, username), 'username', username)), '[]'::jsonb)
          from (select id, display_name, username from public.profiles
                where username ilike q or display_name ilike q order by username limit 20) x);
end $$;

create or replace function public.support_admin_set_category_team(p_category text, p_team text)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public.support_i_need_admin();
  if not exists (select 1 from public.support_teams where key = p_team) then raise exception 'support: unknown team' using errcode = '22023'; end if;
  update public.support_categories set team_key = p_team where key = p_category;
  if not found then raise exception 'support: unknown category' using errcode = '22023'; end if;
  return true;
end $$;

create or replace function public.support_admin_set_sla(p_priority text, p_first int, p_resolution int)
returns boolean language plpgsql security definer set search_path = public, pg_temp as $$
begin
  perform public.support_i_need_admin();
  if p_first is null or p_resolution is null or p_first < 1 or p_resolution < p_first then
    raise exception 'support: invalid SLA minutes' using errcode = '22023';
  end if;
  insert into public.support_sla (priority, first_response_min, resolution_min) values (p_priority, p_first, p_resolution)
  on conflict (priority) do update set first_response_min = excluded.first_response_min, resolution_min = excluded.resolution_min;
  return true;
end $$;

create or replace function public.support_admin_kb_list(p_drafts_only boolean default false)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public.support_i_need_admin();
  return (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'title', title, 'body', body, 'category_key', category_key,
            'published', published, 'source_ticket_id', source_ticket_id, 'created_at', created_at, 'updated_at', updated_at)
            order by updated_at desc), '[]'::jsonb)
          from public.support_kb_articles where (not coalesce(p_drafts_only, false)) or not published);
end $$;

create or replace function public.support_admin_save_kb(p_id uuid, p_title text, p_body text, p_category text, p_published boolean)
returns uuid language plpgsql security definer set search_path = public, pg_temp as $$
declare v_title text; v_body text; cat text; rid uuid;
begin
  perform public.support_i_need_admin();
  v_title := public.support_i_clean(p_title, 160);
  v_body := public.support_i_clean(p_body, 4000);
  if v_title = '' or v_body = '' then raise exception 'support: title and body are required' using errcode = '22023'; end if;
  select key into cat from public.support_categories where key = p_category;
  if p_id is null then
    insert into public.support_kb_articles (title, body, category_key, published, created_by)
    values (v_title, v_body, cat, coalesce(p_published, false), auth.uid()) returning id into rid;
  else
    update public.support_kb_articles set title = v_title, body = v_body,
      category_key = cat, published = coalesce(p_published, false), updated_at = now()
    where id = p_id returning id into rid;
    if rid is null then raise exception 'support: article not found' using errcode = 'P0002'; end if;
  end if;
  return rid;
end $$;

-- Resolved conversations with agent answers, ratings and corrections.
-- Emails, phone numbers, card-like numbers and passwords are scrubbed. Internal notes are left out.
create or replace function public.support_admin_training_export(p_limit int default 200)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  perform public.support_i_need_admin();
  return (
    select coalesce(jsonb_agg(row_j order by resolved_at desc), '[]'::jsonb) from (
      select t.resolved_at, jsonb_build_object(
        'ticket_id', t.id, 'category', t.category, 'priority', t.priority, 'csat', t.csat,
        'summary', public.support_i_scrub_pii(t.summary),
        'messages', (select coalesce(jsonb_agg(jsonb_build_object('sender_type', m.sender_type,
                        'body', public.support_i_scrub_pii(m.message), 'at', m.created_at) order by m.created_at), '[]'::jsonb)
                     from public.support_messages m where m.ticket_id = t.id and not m.internal and m.sender_type <> 'system'),
        'assistant_feedback', (select coalesce(jsonb_agg(jsonb_build_object('message_id', f.message_id, 'helpful', f.helpful,
                        'correction', public.support_i_scrub_pii(f.correction))), '[]'::jsonb)
                     from public.support_assistant_feedback f where f.ticket_id = t.id)) as row_j
      from public.support_tickets t
      where t.status in ('resolved', 'closed')
      order by t.resolved_at desc nulls last
      limit least(greatest(coalesce(p_limit, 200), 1), 1000)) z);
end $$;

-- ---------------------------------------------------------------------------
-- 14. Assistant (service role only): the edge function calls these
-- ---------------------------------------------------------------------------
create or replace function public.support_svc_open_ticket(p_user uuid, p_message text, p_hint text default null, p_device jsonb default '{}'::jsonb)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare tid uuid;
begin
  tid := public.support_i_open_ticket(p_user, p_message, p_hint, p_device);
  return jsonb_build_object('ticket_id', tid, 'message', (
    select public.support_i_msg_json(m) from public.support_messages m where m.ticket_id = tid and m.sender_type = 'user' order by m.created_at limit 1));
end $$;

create or replace function public.support_svc_post_user_message(p_user uuid, p_ticket uuid, p_body text, p_attachments text[] default '{}')
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare msg jsonb; t public.support_tickets;
begin
  msg := public.support_i_post_user_message(p_user, p_ticket, p_body, p_attachments);
  select * into t from public.support_tickets where id = p_ticket;
  return jsonb_build_object('ticket_id', p_ticket, 'message', msg, 'status', t.status, 'category', t.category,
    'auto_resolve_allowed', coalesce((select c.auto_resolve_allowed from public.support_categories c where c.key = t.category), false)
                            and not t.safety_flag,
    'human_involved', t.assigned_agent_id is not null or t.human_requested
                      or exists (select 1 from public.support_messages m where m.ticket_id = p_ticket and m.sender_type = 'agent'),
    'routed', t.status in ('open', 'pending_user', 'escalated') or t.assigned_agent_id is not null);
end $$;

-- Recent non-internal messages of a ticket the user owns (for the model's context).
create or replace function public.support_svc_conversation(p_user uuid, p_ticket uuid, p_limit int default 10)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
begin
  if not exists (select 1 from public.support_tickets where id = p_ticket and user_id = p_user) then
    raise exception 'support: ticket not found' using errcode = 'P0002';
  end if;
  return (select coalesce(jsonb_agg(j order by at), '[]'::jsonb) from (
    select m.created_at as at, jsonb_build_object('sender_type', m.sender_type, 'body', left(m.message, 1200)) as j
    from public.support_messages m where m.ticket_id = p_ticket and not m.internal and m.sender_type <> 'system'
    order by m.created_at desc limit least(greatest(coalesce(p_limit, 10), 1), 30)) z);
end $$;

create or replace function public.support_svc_kb_search(p_query text, p_category text default null, p_limit int default 3)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare terms text; q tsquery;
begin
  select string_agg(w, ' | ') into terms from (
    select distinct w from regexp_split_to_table(lower(coalesce(p_query, '')), '[^a-z0-9]+') as w where length(w) >= 3 limit 25) s;
  if terms is null then return '[]'::jsonb; end if;
  q := to_tsquery('english', terms);
  if numnode(q) = 0 then return '[]'::jsonb; end if;
  return (select coalesce(jsonb_agg(jsonb_build_object('id', id, 'title', title, 'body', body, 'category_key', category_key) order by rk desc), '[]'::jsonb)
          from (select a.id, a.title, a.body, a.category_key,
                       ts_rank(a.tsv, q) + case when a.category_key is not distinct from p_category then 0.2 else 0 end as rk
                from public.support_kb_articles a where a.published and a.tsv @@ q
                order by rk desc limit least(greatest(coalesce(p_limit, 3), 1), 5)) z);
end $$;

create or replace function public.support_svc_diagnostics(p_user uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare e jsonb := '[]';
begin
  begin
    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb) into e from (
      select left(error, 200) as error, route, created_at from public.error_logs
      where user_id = p_user order by created_at desc limit 5) x;
  exception when others then e := '[]'; end;
  return jsonb_build_object('recent_errors', e);
end $$;

create or replace function public.support_svc_ticket_info(p_user uuid, p_ticket uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare t public.support_tickets;
begin
  select * into t from public.support_tickets where id = p_ticket and user_id = p_user;
  if not found then raise exception 'support: ticket not found' using errcode = 'P0002'; end if;
  return jsonb_build_object('ticket_id', t.id, 'category', t.category, 'status', t.status, 'device_info', t.device_info,
    'human_involved', t.assigned_agent_id is not null or t.human_requested
                      or exists (select 1 from public.support_messages m where m.ticket_id = t.id and m.sender_type = 'agent'));
end $$;

-- Applies the assistant's decision to a ticket.
--   p_mode 'answer'   : the assistant answered from the knowledge base; only for categories that allow it
--   p_mode 'route'    : immediate acknowledgement and routing to the team
--   p_mode 'escalate' : same as route but flagged escalated (human asked for, or assistant unsure)
-- p_class (optional): category, priority, sentiment, is_technical, safety_flag, summary, confidence
-- p_diag (optional): app_version, platform, recent_errors
-- The database re-checks the rules, so a faulty model answer can never auto-resolve a money,
-- account, security or safety ticket.
create or replace function public.support_svc_apply(p_ticket uuid, p_class jsonb, p_reply text, p_meta jsonb, p_mode text, p_diag jsonb default null)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  t public.support_tickets; cat public.support_categories; mode text := p_mode; cls jsonb := coalesce(p_class, '{}'::jsonb);
  newcat text; newprio text; safety boolean; tech boolean; conf numeric; tk uuid; reply text; ack text; msgs jsonb := '[]'::jsonb;
  diag text; e jsonb; sensitive boolean;
begin
  select * into t from public.support_tickets where id = p_ticket for update;
  if not found then raise exception 'support: ticket not found' using errcode = 'P0002'; end if;
  if t.status in ('resolved', 'closed') then return jsonb_build_object('ticket_id', p_ticket, 'messages', '[]'::jsonb, 'status', t.status); end if;
  if mode not in ('answer', 'route', 'escalate') then mode := 'route'; end if;

  if p_class is not null then
    newcat := coalesce(cls->>'category', t.category);
    select * into cat from public.support_categories where key = newcat and active;
    if not found then select * into cat from public.support_categories where key = 'other'; end if;
    newcat := cat.key;
    newprio := case when cls->>'priority' in ('low', 'normal', 'high', 'urgent') then cls->>'priority' else cat.default_priority end;
    if public.support_i_prio_rank(newprio) < public.support_i_prio_rank(cat.default_priority) then newprio := cat.default_priority; end if;
    safety := coalesce((cls->>'safety_flag')::boolean, false);
    tech := coalesce((cls->>'is_technical')::boolean, false);
    conf := case when (cls->>'confidence') ~ '^[0-9]*\.?[0-9]+$' then least((cls->>'confidence')::numeric, 1) else 0 end;
    if safety and public.support_i_prio_rank(newprio) < 3 then newprio := 'high'; end if;
    select id into tk from public.support_teams where key = (case when tech and cat.team_key <> 'technical' and newcat in ('other', 'feedback', 'game_rules', 'house_community') then 'technical' else cat.team_key end);
    update public.support_tickets set category = newcat, priority = newprio, team_id = coalesce(tk, team_id),
      summary = left(public.support_i_scrub_pii(public.support_i_clean(cls->>'summary', 600)), 600),
      sentiment = case when cls->>'sentiment' in ('positive', 'neutral', 'negative', 'angry') then cls->>'sentiment' else null end,
      safety_flag = safety, assistant_confidence = conf where id = p_ticket;
  else
    select * into cat from public.support_categories where key = t.category;
    conf := coalesce(t.assistant_confidence, 0); safety := t.safety_flag;
  end if;

  select * into t from public.support_tickets where id = p_ticket;
  select * into cat from public.support_categories where key = t.category;
  sensitive := not coalesce(cat.auto_resolve_allowed, false) or safety or t.priority = 'urgent';
  if mode = 'answer' and (sensitive or conf < 0.6 or coalesce(btrim(p_reply), '') = '') then
    mode := case when conf < 0.6 and not sensitive then 'escalate' else 'route' end;
  end if;

  if p_diag is not null and jsonb_typeof(p_diag) = 'object' then
    update public.support_tickets set diagnostics = p_diag where id = p_ticket;
    diag := 'Diagnostics' || E'\nApp version: ' || left(coalesce(p_diag->>'app_version', 'unknown'), 40)
         || E'\nPlatform: ' || left(coalesce(p_diag->>'platform', 'unknown'), 40) || E'\nLast errors:';
    if jsonb_typeof(p_diag->'recent_errors') = 'array' and jsonb_array_length(p_diag->'recent_errors') > 0 then
      for e in select * from jsonb_array_elements(p_diag->'recent_errors') loop
        diag := diag || E'\n- ' || left(coalesce(e->>'created_at', ''), 19) || ' ' || coalesce(e->>'route', '') || ' ' || left(coalesce(e->>'error', ''), 160);
      end loop;
    else
      diag := diag || ' none recorded';
    end if;
    perform public.support_i_add_message(p_ticket, null, 'note', 'Ryan', diag, true);
  end if;

  if coalesce(p_meta->>'human_requested', '') = 'true' then
    update public.support_tickets set human_requested = true where id = p_ticket;
  end if;

  reply := public.support_i_clean(p_reply, 1500);
  if mode = 'answer' then
    msgs := msgs || public.support_i_add_message(p_ticket, null, 'assistant', 'Ryan', reply, false, '{}',
              coalesce(p_meta, '{}'::jsonb) || jsonb_build_object('category', t.category, 'confidence', conf));
    update public.support_tickets set status = 'assistant_replied', updated_at = now() where id = p_ticket;
  else
    perform public.support_i_route(p_ticket, case when mode = 'escalate' then 'escalated' else 'open' end);
    ack := public.support_i_ack_text(p_ticket);
    msgs := msgs || public.support_i_add_message(p_ticket, null, 'assistant', 'Ryan',
              case when reply <> '' and not sensitive then reply || E'\n\n' || ack else ack end, false, '{}',
              coalesce(p_meta, '{}'::jsonb) || jsonb_build_object('category', t.category, 'confidence', conf, 'routed', true));
  end if;
  return jsonb_build_object('ticket_id', p_ticket, 'messages', msgs, 'mode', mode,
    'status', (select status from public.support_tickets where id = p_ticket));
end $$;

-- ---------------------------------------------------------------------------
-- 15. SLA breaches and housekeeping (cron)
-- ---------------------------------------------------------------------------
create or replace function public.support_mark_breaches()
returns int language plpgsql security definer set search_path = public, pg_temp as $$
declare r record; n int := 0;
begin
  for r in
    select t.id, t.team_id, t.assigned_agent_id, coalesce(t.subject, left(t.issue, 80)) as subj,
           (t.first_response_at is null and t.first_response_due < now()) as late_first
    from public.support_tickets t
    where not t.breached and t.team_id is not null and t.status in ('new', 'open', 'escalated')
      and ((t.first_response_at is null and t.first_response_due < now()) or t.resolution_due < now())
    for update skip locked
  loop
    update public.support_tickets set breached = true, breached_at = now() where id = r.id;
    n := n + 1;
    if r.assigned_agent_id is not null then
      perform public.identity_notify(r.assigned_agent_id, 'Support ticket past its deadline', r.subj,
        jsonb_build_object('type', 'support', 'ticket_id', r.id));
    end if;
    perform public.support_i_notify_leads(r.team_id, 'Support ticket breached its SLA',
      r.subj || case when r.late_first then ' (first response overdue)' else ' (resolution overdue)' end,
      jsonb_build_object('type', 'support', 'ticket_id', r.id));
  end loop;
  -- a resolved ticket that nobody reopened for 14 days becomes closed
  update public.support_tickets set status = 'closed', closed_at = now()
    where status = 'resolved' and resolved_at < now() - interval '14 days';
  return n;
end $$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('support-sla-breaches', '*/10 * * * *', 'select public.support_mark_breaches()');
  end if;
exception when others then
  raise notice 'could not schedule support_mark_breaches; run it from the SQL editor or an edge cron';
end $$;

-- ---------------------------------------------------------------------------
-- 16. Function privileges
-- ---------------------------------------------------------------------------
do $$
declare r record;
begin
  for r in select p.oid::regprocedure as sig, p.proname from pg_proc p join pg_namespace n on n.oid = p.pronamespace
           where n.nspname = 'public' and p.proname like 'support\_%' loop
    execute format('revoke all on function %s from public, anon, authenticated', r.sig);
    if r.proname like 'support\_svc\_%' or r.proname = 'support_mark_breaches' then
      begin execute format('grant execute on function %s to service_role', r.sig); exception when undefined_object then null; end;
    elsif r.proname like 'support\_i\_%' then
      null; -- internal: only other SECURITY DEFINER functions (running as owner) use these
    else
      execute format('grant execute on function %s to authenticated', r.sig);
      begin execute format('grant execute on function %s to service_role', r.sig); exception when undefined_object then null; end;
    end if;
  end loop;
end $$;

-- ---------------------------------------------------------------------------
-- 17. Realtime and storage
-- ---------------------------------------------------------------------------
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'support_messages') then
    alter publication supabase_realtime add table public.support_messages;
  end if;
exception when others then
  raise notice 'could not add support_messages to supabase_realtime: %', sqlerrm;
end $$;

-- Private bucket: owners upload into their own folder (5 MB, png/jpg/webp/pdf). Reading is
-- limited to the uploader, the ticket owner and staff of the ticket's team.
do $$
begin
  if exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    begin
      insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
      values ('support-attachments', 'support-attachments', false, 5242880,
              array['image/png', 'image/jpeg', 'image/webp', 'application/pdf'])
      on conflict (id) do update set public = false, file_size_limit = 5242880,
        allowed_mime_types = array['image/png', 'image/jpeg', 'image/webp', 'application/pdf'];
    exception when undefined_column then
      insert into storage.buckets (id, name, public) values ('support-attachments', 'support-attachments', false)
      on conflict (id) do update set public = false;
    end;
    execute 'drop policy if exists "support attachments upload" on storage.objects';
    execute $p$create policy "support attachments upload" on storage.objects for insert to authenticated
      with check (bucket_id = 'support-attachments' and (storage.foldername(name))[1] = auth.uid()::text)$p$;
    execute 'drop policy if exists "support attachments read" on storage.objects';
    execute $p$create policy "support attachments read" on storage.objects for select to authenticated
      using (bucket_id = 'support-attachments'
             and ((storage.foldername(name))[1] = auth.uid()::text or public.support_can_read_attachment(name)))$p$;
  end if;
exception when others then
  raise notice 'could not create the support-attachments bucket policies: %', sqlerrm;
end $$;

-- ---------------------------------------------------------------------------
-- 18. Knowledge base seed (facts taken from the app itself)
-- ---------------------------------------------------------------------------
insert into public.support_kb_articles (title, body, category_key, published)
select v.title, v.body, v.cat, true from (values
  ('How do I fund my wallet?',
   $kb$Go to Wallet, then Fund Wallet. Choose an amount or enter your own. The minimum is N500. Payment is handled by Paystack on a secure page. After a successful payment your balance updates within minutes. On iPhone you can also top up through Apple in-app purchase.$kb$, 'wallet_funding'),
  ('My wallet was debited but the balance did not change',
   $kb$A balance normally updates within a few minutes after Paystack confirms the payment. Wait about 10 minutes, then pull down to refresh the Wallet screen. If it still has not updated, our Payments team will check the payment reference with Paystack. Keep your bank alert or Paystack receipt ready. Never send your card number, PIN or OTP to anyone.$kb$, 'wallet_funding'),
  ('How do withdrawals work?',
   $kb$Go to Wallet, then Withdraw. Enter your bank details and the amount. The minimum withdrawal is N1,000. The finance team processes withdrawals within 24 hours on business days. Check that your account number and bank are correct before you submit.$kb$, 'withdrawal'),
  ('My withdrawal is taking long',
   $kb$Withdrawals are processed within 24 hours on business days, so requests made on a weekend or public holiday wait for the next business day. If more than one business day has passed, our Payments team will look into it. Please keep the amount, date and the last four digits of the bank account ready. Do not share your full card number, PIN or OTP.$kb$, 'withdrawal'),
  ('How do I get verified?',
   $kb$Go to Settings, then Verification, then Apply. A N2,000 fee applies. The admin team reviews applications within 48 hours. Verified users get a badge and can create sub-communities.$kb$, 'verification'),
  ('Why was my verification not approved?',
   $kb$Verification is reviewed by the admin team within 48 hours. Applications can be declined when the ID photo is unclear or the name does not match the profile. A person on our Accounts team can tell you the exact reason for your case.$kb$, 'verification'),
  ('How do I join a competition?',
   $kb$Go to Competitions and tap any competition. Read the details, then tap Enter Competition. For paid competitions the entry fee is taken from your wallet, so make sure you have enough balance first.$kb$, 'game_rules'),
  ('I won a competition but have not received my prize',
   $kb$Prizes are credited after the results are confirmed by the organisers. Check the competition page for its status and the announced result date. If the competition is finished and your prize is missing, our Competitions and Rewards team will check it. Tell us the competition name and when it ended.$kb$, 'competition_prize'),
  ('How do Arena duels and stakes work?',
   $kb$In an Arena duel each player stakes the same amount from the wallet. The winner takes the pooled stakes minus the platform fee. A draw refunds both players. Tap a game to be matched with someone at the same stake.$kb$, 'game_rules'),
  ('What is the platform fee?',
   $kb$GACOM keeps a platform fee from competition and duel pots. The percentage is set by the administrators and is applied automatically when a result is settled. Entry fees and stakes are shown before you confirm.$kb$, 'game_rules'),
  ('I cannot log in',
   $kb$Check that you are using the correct email and password. On the login screen tap Forgot Password and follow the link sent to your email, and look in your spam folder too. Make sure the app is updated to the latest version. If you are still stuck, tell us what message you see.$kb$, 'login_problem'),
  ('How do I reset my password?',
   $kb$On the login screen tap Forgot Password and enter your email. We send you a link that opens the reset page. The link works once, so request a new one if it has expired. GACOM staff will never ask you for your password.$kb$, 'login_problem'),
  ('How do I change my username or Gamer Tag?',
   $kb$For your username go to Settings, then Change Username. Usernames must be at least 3 characters, with letters and numbers only. Your Gamer Tag is your in-game identity and is separate from your username. Update it in Settings, then Gamer Tag.$kb$, 'account_access'),
  ('Someone else is using my account',
   $kb$Change your password straight away from Settings, and sign out of other devices if you can. Never share your password, PIN or OTP with anyone. Tell us what you noticed and when. Our Trust and Safety team will review the activity on your account.$kb$, 'security_concern'),
  ('How do I report abuse or a user?',
   $kb$Open the profile, post or chat and use the report option, or tell us here with the username and what happened. Screenshots help. Our Trust and Safety team reviews every report and may remove content or restrict accounts. If someone is in danger, contact your local emergency services first.$kb$, 'report_abuse'),
  ('How do I contact support?',
   $kb$Go to Settings, then Contact Support. Ryan, GACOM's support assistant, answers common questions straight away. For anything that needs a person, your conversation is passed to the right team, and the team can see your chat history.$kb$, 'other'),
  ('How do I create a post?',
   $kb$Tap the plus button on the home feed or go to Create Post. Add text, images or video, add tags so others can find it, then tap POST to publish.$kb$, 'other'),
  ('Can I create a community?',
   $kb$Any verified user can create sub-communities under an existing community. Admins create top-level communities. Go to Communities and tap the plus button, which is visible if you are eligible.$kb$, 'house_community'),
  ('How do Houses work?',
   $kb$Houses are teams you can join. A house can be open, where you join straight away, or closed, where the captain approves your request. Houses compete in weekly house wars and win trophies. Captains can also buy emblems and banners for the house.$kb$, 'house_community'),
  ('What does GACOM Edu cost?',
   $kb$Edu Gaming is N3,500 per month for full access to all 24 subjects. On iPhone the subscription is handled by Apple and renews automatically unless you cancel at least 24 hours before the end of the current period.$kb$, 'other'),
  ('How do store orders and delivery work?',
   $kb$When you check out, the delivery fee and the estimated delivery days for your state are shown before you pay. Delivery time starts after your order is confirmed. You can see the status of an order in your order history.$kb$, 'delivery'),
  ('My order has not arrived',
   $kb$Check the estimated delivery days that were shown at checkout for your state, and your order status in the order history. If that time has passed, our Orders and Shop team will trace it. Please share your order reference.$kb$, 'shop_order'),
  ('I want a refund',
   $kb$Refund requests are reviewed by our Payments team case by case, and we cannot promise an outcome in advance. Tell us what you paid for, the date, the amount and your payment reference. Do not send card numbers, PINs or OTPs.$kb$, 'refund_dispute'),
  ('The app keeps crashing',
   $kb$Update the app to the latest version, restart your phone and make sure you have free storage and a stable connection. If it still crashes, tell us your phone model and what you were doing when it happened. Our Technical team can see the error details the app recorded for your account.$kb$, 'app_crash'),
  ('How do I become a game developer on GACOM?',
   $kb$Use the Game Developer Application in the Arena section. GACOM reviews your game within 7 business days and you receive feedback or an approval at the email you provided.$kb$, 'other'),
  ('Is it safe to share my details with support?',
   $kb$GACOM staff will never ask for your password, PIN, one-time code or full card number. Do not send these to anyone, in chat or in screenshots. Share only what we ask for, such as a payment reference, an order reference or a description of the problem.$kb$, 'security_concern'),
  ('Where can I send feedback or ideas?',
   $kb$Send them here in Contact Support. Tell us what you like, what annoys you and what you want added. Our team reads every message and passes ideas to the product team.$kb$, 'feedback')
) as v(title, body, cat)
where not exists (select 1 from public.support_kb_articles a where a.title = v.title);

-- ---------------------------------------------------------------------------
-- 19. Macros seed
-- ---------------------------------------------------------------------------
insert into public.support_macros (title, body, category_key)
select v.title, v.body, v.cat from (values
  ('Greeting', E'Hello {{name}}, thanks for contacting GACOM Support. My name is {{agent}} and I will be looking into this for you.', null),
  ('Need more details', E'Hello {{name}}, to help you faster, please tell us exactly what happened, when it happened, and send a screenshot if you can. Please do not send your password, PIN, OTP or card number.', null),
  ('Wallet funding check', E'Hello {{name}}, we are checking your payment with Paystack. Please send the payment reference or the date, time and amount. We will update you here as soon as we have confirmed it.', 'wallet_funding'),
  ('Withdrawal timing', E'Hello {{name}}, withdrawals are processed within 24 hours on business days. Requests made on weekends or public holidays are processed on the next business day. We are checking yours now and will update you here.', 'withdrawal'),
  ('Refund review', E'Hello {{name}}, we have received your refund request and our Payments team is reviewing it. We will tell you the outcome here. Please send the payment reference and the date if you have not done so.', 'refund_dispute'),
  ('Verification status', E'Hello {{name}}, verification applications are reviewed within 48 hours. We are checking your application and will update you here.', 'verification'),
  ('Account security steps', E'Hello {{name}}, for your safety please change your password now and make sure no one else has your login details. GACOM staff will never ask for your password, PIN or OTP. We are reviewing your account activity.', 'security_concern'),
  ('Delivery follow-up', E'Hello {{name}}, we are tracing your order. Please send your order reference. Delivery times depend on your state and are shown at checkout.', 'delivery'),
  ('Prize check', E'Hello {{name}}, we are confirming the result of your competition with the organisers. Please tell us the competition name and the date it ended. We will update you here.', 'competition_prize'),
  ('Technical details request', E'Hello {{name}}, please tell us your phone model, your Android or iOS version and the steps that lead to the problem. Updating the app to the latest version first may also help.', 'app_crash'),
  ('Passed to technical team', E'Hello {{name}}, we have passed this to our Technical Support team for a closer look. We will update you here as soon as we have news.', 'gameplay_bug'),
  ('Closing, anything else', E'Hello {{name}}, we believe this is now sorted. If something is still wrong, reply here and we will pick it up again. Please take a moment to rate your experience. Thank you for playing GACOM.', null)
) as v(title, body, cat)
where not exists (select 1 from public.support_macros m where m.title = v.title);
