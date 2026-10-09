-- DARKOM CITY step 2: open hub, filtered chat, blocks and reports, challenges,
-- house squads. Depends on 20261011 (houses) and 20261016 (Darkom City).
-- All writes go through security definer RPCs; every RPC returns
-- jsonb {success, error?, ...}. Safe to run more than once.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------
create table if not exists public.darkom_banned_words (
  word text primary key check (word ~ '^[a-z0-9]{2,30}$')
);

create table if not exists public.darkom_hub_members (
  user_id uuid primary key references auth.users(id) on delete cascade,
  instance integer not null check (instance >= 1),
  last_seen timestamptz not null default now()
);
create index if not exists darkom_hub_members_instance_idx on public.darkom_hub_members (instance, last_seen desc);

create table if not exists public.darkom_chat_messages (
  id uuid primary key default gen_random_uuid(),
  room text not null check (char_length(room) <= 60),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'Player',
  body text not null check (char_length(body) between 1 and 140),
  created_at timestamptz not null default clock_timestamp()
);
create index if not exists darkom_chat_room_idx on public.darkom_chat_messages (room, created_at desc);
create index if not exists darkom_chat_user_idx on public.darkom_chat_messages (user_id, created_at desc);
create index if not exists darkom_chat_created_idx on public.darkom_chat_messages (created_at);

create table if not exists public.darkom_blocks (
  blocker_id uuid not null references auth.users(id) on delete cascade,
  blocked_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (blocker_id, blocked_id),
  check (blocker_id <> blocked_id)
);
create index if not exists darkom_blocks_blocked_idx on public.darkom_blocks (blocked_id);

create table if not exists public.darkom_reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references auth.users(id) on delete cascade,
  target_id uuid not null references auth.users(id) on delete cascade,
  reason text not null check (reason in ('abuse', 'spam', 'cheating', 'other')),
  room text not null default '',
  message_id uuid,
  created_at timestamptz not null default now()
);
create index if not exists darkom_reports_target_idx on public.darkom_reports (target_id, created_at desc);
create index if not exists darkom_reports_pair_idx on public.darkom_reports (reporter_id, target_id, created_at desc);

create table if not exists public.darkom_mutes (
  user_id uuid primary key references auth.users(id) on delete cascade,
  until timestamptz not null,
  level integer not null default 1,
  muted_at timestamptz not null default now()
);

create table if not exists public.darkom_challenges (
  id uuid primary key default gen_random_uuid(),
  from_id uuid not null references auth.users(id) on delete cascade,
  from_name text not null default 'Player',
  to_id uuid not null references auth.users(id) on delete cascade,
  to_name text not null default 'Player',
  instance integer,
  status text not null default 'pending' check (status in ('pending', 'accepted', 'declined', 'expired', 'done')),
  code text not null,
  created_at timestamptz not null default now(),
  accepted_at timestamptz,
  from_result text check (from_result in ('won', 'lost')),
  to_result text check (to_result in ('won', 'lost')),
  winner_id uuid,
  agreed boolean,
  from_xp integer not null default 0,
  to_xp integer not null default 0,
  check (from_id <> to_id)
);
create index if not exists darkom_challenges_from_idx on public.darkom_challenges (from_id, created_at desc);
create index if not exists darkom_challenges_to_idx on public.darkom_challenges (to_id, created_at desc);

create table if not exists public.darkom_squads (
  id uuid primary key default gen_random_uuid(),
  house_id uuid not null references public.houses(id) on delete cascade,
  host_id uuid not null references auth.users(id) on delete cascade,
  host_name text not null default 'Player',
  mode text not null default 'arena',
  max_players integer not null default 4 check (max_players between 2 and 4),
  status text not null default 'open' check (status in ('open', 'started', 'closed')),
  member_ids uuid[] not null default '{}',
  member_names text[] not null default '{}',
  started_count integer not null default 0,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  updated_at timestamptz not null default now()
);
create index if not exists darkom_squads_house_idx on public.darkom_squads (house_id, status, created_at desc);

create table if not exists public.darkom_squad_members (
  squad_id uuid not null references public.darkom_squads(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null default 'Player',
  joined_at timestamptz not null default now(),
  reported boolean not null default false,
  primary key (squad_id, user_id)
);
create index if not exists darkom_squad_members_user_idx on public.darkom_squad_members (user_id);

-- Reward ledger: caps per day for duels and squad matches.
create table if not exists public.darkom_rewards (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  kind text not null check (kind in ('duel', 'squad')),
  ref_id uuid,
  xp integer not null default 0,
  day date not null default ((now() at time zone 'utc')::date),
  created_at timestamptz not null default now()
);
create index if not exists darkom_rewards_user_day_idx on public.darkom_rewards (user_id, kind, day);

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
create or replace function public.darkom_name(p_user uuid)
returns text language sql stable security definer set search_path = public as $$
  select coalesce(nullif(btrim(p.display_name), ''), nullif(btrim(p.username), ''), 'Player')
  from public.profiles p where p.id = p_user
  union all select 'Player' limit 1;
$$;

create or replace function public.darkom_is_house_member(p_house uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.house_members hm where hm.house_id = p_house and hm.user_id = p_user);
$$;

create or replace function public.darkom_is_squad_member(p_squad uuid, p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.darkom_squad_members m where m.squad_id = p_squad and m.user_id = p_user);
$$;

create or replace function public.darkom_squad_house(p_squad uuid)
returns uuid language sql stable security definer set search_path = public as $$
  select house_id from public.darkom_squads where id = p_squad;
$$;

-- Can this user read/write this chat room? hub rooms: any signed in user.
create or replace function public.darkom_can_read_room(p_room text, p_user uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
begin
  if p_user is null or p_room is null then return false; end if;
  if p_room ~ '^hub:[0-9]{1,6}$' then return true; end if;
  if p_room ~ '^house:[0-9a-fA-F-]{36}$' then
    return public.darkom_is_house_member(substr(p_room, 7)::uuid, p_user);
  end if;
  if p_room ~ '^squad:[0-9a-fA-F-]{36}$' then
    return public.darkom_is_squad_member(substr(p_room, 7)::uuid, p_user);
  end if;
  return false;
exception when others then
  return false;
end;
$$;

create or replace function public.darkom_blocked_either(p_a uuid, p_b uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.darkom_blocks b
                 where (b.blocker_id = p_a and b.blocked_id = p_b) or (b.blocker_id = p_b and b.blocked_id = p_a));
$$;

-- Returns {ok, text, error}. Cleans and checks one chat line.
create or replace function public.darkom_clean_text(p_text text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  t text := coalesce(p_text, '');
  w text;
  low text;
  digits text;
begin
  t := regexp_replace(t, '[​-‏‪-‮⁠﻿]', '', 'g');
  t := regexp_replace(t, '[[:cntrl:]]', ' ', 'g');
  t := btrim(regexp_replace(t, '\s+', ' ', 'g'));
  if t = '' then
    return jsonb_build_object('ok', false, 'error', 'Type something first');
  end if;
  if char_length(t) > 140 then
    return jsonb_build_object('ok', false, 'error', 'Messages can be at most 140 characters');
  end if;
  low := lower(t);
  if low ~ '(https?:|www\.|ftp:)'
     or low ~ '[a-z0-9-]+\s?(\.|\(dot\)|\[dot\]|\sdot\s)\s?(com|net|org|io|ng|co|me|ly|gg|xyz|app|dev|info|biz|tv|link|site|online|store|shop|club|top|live|chat|gl)\M'
     or low ~ '[a-z0-9._-]+@[a-z0-9-]+' then
    return jsonb_build_object('ok', false, 'error', 'Links and contact details cannot be shared here');
  end if;
  -- phone numbers: 8 or more digits once separators are ignored
  digits := regexp_replace(low, '[^0-9]', '', 'g');
  if char_length(digits) >= 8 then
    return jsonb_build_object('ok', false, 'error', 'Links and contact details cannot be shared here');
  end if;
  for w in select word from public.darkom_banned_words loop
    t := regexp_replace(t, '\m' || w || '\M', repeat('*', char_length(w)), 'gi');
  end loop;
  return jsonb_build_object('ok', true, 'text', t);
end;
$$;

create or replace function public.darkom_mute_minutes(p_user uuid)
returns integer language sql stable security definer set search_path = public as $$
  select coalesce((select ceil(extract(epoch from (m.until - clock_timestamp())) / 60.0)::integer
                   from public.darkom_mutes m where m.user_id = p_user and m.until > clock_timestamp()), 0);
$$;

create or replace function public.darkom_close_stale_squads()
returns void language sql security definer set search_path = public as $$
  update public.darkom_squads set status = 'closed', updated_at = now()
  where status in ('open', 'started') and created_at < now() - interval '30 minutes';
$$;

create or replace function public.darkom_squad_json(p_squad uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('id', s.id, 'house_id', s.house_id, 'host_id', s.host_id, 'host_name', s.host_name,
    'mode', s.mode, 'max_players', s.max_players, 'status', s.status,
    'member_ids', to_jsonb(s.member_ids), 'member_names', to_jsonb(s.member_names))
  from public.darkom_squads s where s.id = p_squad;
$$;

create or replace function public.darkom_challenge_json(c public.darkom_challenges)
returns jsonb language sql immutable as $$
  select jsonb_build_object('id', c.id, 'from_id', c.from_id, 'from_name', c.from_name, 'to_id', c.to_id,
    'to_name', c.to_name, 'status', c.status, 'code', c.code, 'created_at', c.created_at);
$$;

create or replace function public.darkom_refresh_squad_arrays(p_squad uuid)
returns void language sql security definer set search_path = public as $$
  update public.darkom_squads s set
    member_ids = coalesce((select array_agg(m.user_id order by m.joined_at) from public.darkom_squad_members m where m.squad_id = s.id), '{}'),
    member_names = coalesce((select array_agg(m.name order by m.joined_at) from public.darkom_squad_members m where m.squad_id = s.id), '{}'),
    updated_at = now()
  where s.id = p_squad;
$$;

-- ---------------------------------------------------------------------------
-- Row level security (reads only; all writes are RPCs)
-- ---------------------------------------------------------------------------
alter table public.darkom_banned_words enable row level security;
alter table public.darkom_hub_members enable row level security;
alter table public.darkom_chat_messages enable row level security;
alter table public.darkom_blocks enable row level security;
alter table public.darkom_reports enable row level security;
alter table public.darkom_mutes enable row level security;
alter table public.darkom_challenges enable row level security;
alter table public.darkom_squads enable row level security;
alter table public.darkom_squad_members enable row level security;
alter table public.darkom_rewards enable row level security;

drop policy if exists "admin banned words" on public.darkom_banned_words;
create policy "admin banned words" on public.darkom_banned_words for all to authenticated
  using (public.identity_is_admin()) with check (public.identity_is_admin());

drop policy if exists "own hub row" on public.darkom_hub_members;
create policy "own hub row" on public.darkom_hub_members for select to authenticated using (user_id = auth.uid());

drop policy if exists "read room chat" on public.darkom_chat_messages;
create policy "read room chat" on public.darkom_chat_messages for select to authenticated
  using (public.darkom_can_read_room(room, auth.uid()));

drop policy if exists "own blocks" on public.darkom_blocks;
create policy "own blocks" on public.darkom_blocks for select to authenticated using (blocker_id = auth.uid());

drop policy if exists "admin reads reports" on public.darkom_reports;
create policy "admin reads reports" on public.darkom_reports for select to authenticated using (public.identity_is_admin());

drop policy if exists "own mute" on public.darkom_mutes;
create policy "own mute" on public.darkom_mutes for select to authenticated
  using (user_id = auth.uid() or public.identity_is_admin());

drop policy if exists "own challenges" on public.darkom_challenges;
create policy "own challenges" on public.darkom_challenges for select to authenticated
  using (from_id = auth.uid() or to_id = auth.uid());

drop policy if exists "house reads squads" on public.darkom_squads;
create policy "house reads squads" on public.darkom_squads for select to authenticated
  using (public.darkom_is_house_member(house_id, auth.uid()) or public.darkom_is_squad_member(id, auth.uid()));

drop policy if exists "squad reads members" on public.darkom_squad_members;
create policy "squad reads members" on public.darkom_squad_members for select to authenticated
  using (user_id = auth.uid() or public.darkom_is_squad_member(squad_id, auth.uid()));

drop policy if exists "own rewards" on public.darkom_rewards;
create policy "own rewards" on public.darkom_rewards for select to authenticated using (user_id = auth.uid());

revoke all on public.darkom_banned_words, public.darkom_hub_members, public.darkom_chat_messages,
  public.darkom_blocks, public.darkom_reports, public.darkom_mutes, public.darkom_challenges,
  public.darkom_squads, public.darkom_squad_members, public.darkom_rewards from anon, authenticated;
grant select on public.darkom_hub_members, public.darkom_chat_messages, public.darkom_blocks,
  public.darkom_reports, public.darkom_mutes, public.darkom_challenges, public.darkom_squads,
  public.darkom_squad_members, public.darkom_rewards to authenticated;
grant select, insert, update, delete on public.darkom_banned_words to authenticated;

-- Helpers are internal; only the RPCs below are the public surface.
revoke execute on function public.darkom_clean_text(text), public.darkom_close_stale_squads(),
  public.darkom_refresh_squad_arrays(uuid), public.darkom_squad_json(uuid), public.darkom_mute_minutes(uuid),
  public.darkom_name(uuid) from public, anon, authenticated;
grant execute on function public.darkom_can_read_room(text, uuid), public.darkom_is_house_member(uuid, uuid),
  public.darkom_is_squad_member(uuid, uuid), public.darkom_squad_house(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Ban word seed (admins can edit the table)
-- ---------------------------------------------------------------------------
insert into public.darkom_banned_words (word) values
  ('fuck'), ('fucker'), ('fucking'), ('fvck'), ('shit'), ('bitch'), ('bastard'), ('asshole'), ('dickhead'),
  ('cunt'), ('pussy'), ('whore'), ('slut'), ('nigger'), ('faggot'), ('retard'), ('kys'),
  ('mumu'), ('olodo'), ('ashawo'), ('oloshi'), ('yeye'), ('oloriburuku'), ('ndiya'), ('idiot'), ('stupid')
on conflict (word) do nothing;

-- ---------------------------------------------------------------------------
-- Hub
-- ---------------------------------------------------------------------------
create or replace function public.darkom_join_hub()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  inst integer;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  perform pg_advisory_xact_lock(hashtext('darkom_hub_assign'));
  delete from public.darkom_hub_members where user_id = uid or last_seen < clock_timestamp() - interval '5 minutes';

  select m.instance into inst
  from public.darkom_hub_members m
  where m.last_seen > clock_timestamp() - interval '60 seconds'
  group by m.instance
  having count(*) < 20
  order by count(*) desc, m.instance asc
  limit 1;

  if inst is null then
    -- smallest instance number that has no live members
    select g into inst from generate_series(1, (select coalesce(max(instance), 0) + 1 from public.darkom_hub_members)) g
    where not exists (select 1 from public.darkom_hub_members m
                      where m.instance = g and m.last_seen > clock_timestamp() - interval '60 seconds')
    order by g limit 1;
  end if;

  insert into public.darkom_hub_members (user_id, instance, last_seen) values (uid, inst, clock_timestamp());
  return jsonb_build_object('success', true, 'instance', inst::text, 'room', 'hub:' || inst);
end;
$$;

create or replace function public.darkom_hub_heartbeat(p_instance text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  inst integer;
  n integer;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_instance is null or p_instance !~ '^[0-9]{1,6}$' then
    return jsonb_build_object('success', false, 'error', 'Unknown hub');
  end if;
  inst := p_instance::integer;
  update public.darkom_hub_members set last_seen = clock_timestamp() where user_id = uid and instance = inst;
  if found then return jsonb_build_object('success', true); end if;
  -- we were dropped (for example a long pause): come back if there is room
  perform pg_advisory_xact_lock(hashtext('darkom_hub_assign'));
  select count(*) into n from public.darkom_hub_members
    where instance = inst and last_seen > clock_timestamp() - interval '60 seconds';
  if n >= 20 then return jsonb_build_object('success', false, 'error', 'This hub is full, please rejoin'); end if;
  insert into public.darkom_hub_members (user_id, instance, last_seen) values (uid, inst, clock_timestamp())
    on conflict (user_id) do update set instance = excluded.instance, last_seen = excluded.last_seen;
  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.darkom_leave_hub(p_instance text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  delete from public.darkom_hub_members where user_id = uid;
  return jsonb_build_object('success', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Chat
-- ---------------------------------------------------------------------------
create or replace function public.darkom_recent_messages(p_room text, p_limit integer default 40)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  lim integer := least(greatest(coalesce(p_limit, 40), 1), 100);
  out jsonb;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if not public.darkom_can_read_room(p_room, uid) then
    return jsonb_build_object('success', false, 'error', 'You cannot read this chat');
  end if;
  select coalesce(jsonb_agg(jsonb_build_object('id', r.id, 'room', r.room, 'user_id', r.user_id,
           'name', r.name, 'body', r.body, 'created_at', r.created_at) order by r.created_at asc), '[]'::jsonb)
    into out
  from (
    select * from public.darkom_chat_messages m
    where m.room = p_room
      and not exists (select 1 from public.darkom_blocks b where b.blocker_id = uid and b.blocked_id = m.user_id)
    order by m.created_at desc limit lim
  ) r;
  return jsonb_build_object('success', true, 'messages', out);
end;
$$;

create or replace function public.darkom_send_message(p_room text, p_body text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  mins integer;
  cl jsonb;
  last_at timestamptz;
  cnt integer;
  nm text;
  msg public.darkom_chat_messages;
  inst integer;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_room is null or not public.darkom_can_read_room(p_room, uid) then
    return jsonb_build_object('success', false, 'error', 'You cannot chat in this room');
  end if;
  if p_room ~ '^hub:' then
    inst := substr(p_room, 5)::integer;
    if not exists (select 1 from public.darkom_hub_members m where m.user_id = uid and m.instance = inst
                   and m.last_seen > clock_timestamp() - interval '5 minutes') then
      return jsonb_build_object('success', false, 'error', 'Join the hub to chat');
    end if;
  end if;

  mins := public.darkom_mute_minutes(uid);
  if mins > 0 then
    return jsonb_build_object('success', false,
      'error', 'You are muted for ' || mins || ' more minute' || case when mins = 1 then '' else 's' end);
  end if;

  cl := public.darkom_clean_text(p_body);
  if (cl ->> 'ok')::boolean is not true then
    return jsonb_build_object('success', false, 'error', cl ->> 'error');
  end if;

  select max(created_at), count(*) filter (where created_at > clock_timestamp() - interval '60 seconds')
    into last_at, cnt
  from public.darkom_chat_messages
  where user_id = uid and created_at > clock_timestamp() - interval '60 seconds';
  if (last_at is not null and last_at > clock_timestamp() - interval '2 seconds') or cnt >= 20 then
    return jsonb_build_object('success', false, 'error', 'You are sending messages too fast');
  end if;

  nm := public.darkom_name(uid);
  insert into public.darkom_chat_messages (room, user_id, name, body, created_at)
    values (p_room, uid, nm, cl ->> 'text', clock_timestamp())
    returning * into msg;

  if random() < 0.01 then
    delete from public.darkom_chat_messages where created_at < now() - interval '7 days';
  end if;

  return jsonb_build_object('success', true, 'message', jsonb_build_object('id', msg.id, 'room', msg.room,
    'user_id', msg.user_id, 'name', msg.name, 'body', msg.body, 'created_at', msg.created_at));
end;
$$;

-- ---------------------------------------------------------------------------
-- Blocks and reports
-- ---------------------------------------------------------------------------
create or replace function public.darkom_block_user(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_user is null or p_user = uid then return jsonb_build_object('success', false, 'error', 'You cannot block yourself'); end if;
  if not exists (select 1 from auth.users u where u.id = p_user) then
    return jsonb_build_object('success', false, 'error', 'Player not found');
  end if;
  insert into public.darkom_blocks (blocker_id, blocked_id) values (uid, p_user) on conflict do nothing;
  update public.darkom_challenges set status = 'declined'
    where status = 'pending' and ((from_id = uid and to_id = p_user) or (from_id = p_user and to_id = uid));
  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.darkom_unblock_user(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  delete from public.darkom_blocks where blocker_id = uid and blocked_id = p_user;
  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.darkom_blocked_ids()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in', 'ids', '[]'::jsonb); end if;
  return jsonb_build_object('success', true,
    'ids', coalesce((select jsonb_agg(blocked_id) from public.darkom_blocks where blocker_id = uid), '[]'::jsonb));
end;
$$;

create or replace function public.darkom_report_user(p_user uuid, p_reason text, p_room text default '', p_message_id uuid default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  since timestamptz;
  m public.darkom_mutes;
  reporters integer;
  lvl integer;
  mins integer;
  has_mute boolean;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_user is null or p_user = uid then return jsonb_build_object('success', false, 'error', 'You cannot report yourself'); end if;
  if p_reason is null or p_reason not in ('abuse', 'spam', 'cheating', 'other') then
    return jsonb_build_object('success', false, 'error', 'Please pick a reason');
  end if;
  if not exists (select 1 from auth.users u where u.id = p_user) then
    return jsonb_build_object('success', false, 'error', 'Player not found');
  end if;
  if exists (select 1 from public.darkom_reports r where r.reporter_id = uid and r.target_id = p_user
             and r.created_at > now() - interval '10 minutes') then
    return jsonb_build_object('success', false, 'error', 'You already reported this player a moment ago. Thank you');
  end if;

  insert into public.darkom_reports (reporter_id, target_id, reason, room, message_id)
    values (uid, p_user, p_reason, left(coalesce(p_room, ''), 60), p_message_id);

  select * into m from public.darkom_mutes where user_id = p_user;
  has_mute := found;
  since := now() - interval '24 hours';
  if has_mute and m.muted_at > since then since := m.muted_at; end if;
  select count(distinct reporter_id) into reporters from public.darkom_reports
    where target_id = p_user and created_at > since;

  if reporters >= 3 and not (has_mute and m.until > clock_timestamp()) then
    lvl := case when has_mute and m.muted_at > now() - interval '7 days' then m.level + 1 else 1 end;
    lvl := least(lvl, 10);
    mins := least(30 * (2 ^ (lvl - 1))::integer, 1440);
    insert into public.darkom_mutes (user_id, until, level, muted_at)
      values (p_user, clock_timestamp() + make_interval(mins => mins), lvl, now())
      on conflict (user_id) do update set until = excluded.until, level = excluded.level, muted_at = excluded.muted_at;
  end if;
  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.darkom_admin_reports()
returns jsonb language plpgsql stable security definer set search_path = public as $$
begin
  if not public.identity_is_admin() then return jsonb_build_object('success', false, 'error', 'Not allowed'); end if;
  return jsonb_build_object('success', true,
    'reports', coalesce((select jsonb_agg(x) from (
        select jsonb_build_object('id', r.id, 'reporter_id', r.reporter_id, 'reporter_name', public.darkom_name(r.reporter_id),
               'target_id', r.target_id, 'target_name', public.darkom_name(r.target_id), 'reason', r.reason,
               'room', r.room, 'message_id', r.message_id,
               'message_body', (select body from public.darkom_chat_messages cm where cm.id = r.message_id),
               'created_at', r.created_at) as x
        from public.darkom_reports r order by r.created_at desc limit 100) q), '[]'::jsonb),
    'mutes', coalesce((select jsonb_agg(jsonb_build_object('user_id', mu.user_id, 'name', public.darkom_name(mu.user_id),
               'until', mu.until, 'level', mu.level))
        from public.darkom_mutes mu where mu.until > clock_timestamp()), '[]'::jsonb));
end;
$$;

create or replace function public.darkom_admin_clear_mute(p_user uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.identity_is_admin() then return jsonb_build_object('success', false, 'error', 'Not allowed'); end if;
  update public.darkom_mutes set until = clock_timestamp(), level = 0, muted_at = now() where user_id = p_user;
  return jsonb_build_object('success', true);
end;
$$;

-- ---------------------------------------------------------------------------
-- Challenges and duels
-- ---------------------------------------------------------------------------
create or replace function public.darkom_challenge(p_to uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  mi integer;
  ti integer;
  c public.darkom_challenges;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_to is null or p_to = uid then return jsonb_build_object('success', false, 'error', 'Pick another player'); end if;
  update public.darkom_challenges set status = 'expired'
    where status = 'pending' and created_at < now() - interval '60 seconds';
  if public.darkom_blocked_either(uid, p_to) then
    return jsonb_build_object('success', false, 'error', 'You cannot challenge this player');
  end if;
  select instance into mi from public.darkom_hub_members where user_id = uid and last_seen > clock_timestamp() - interval '90 seconds';
  select instance into ti from public.darkom_hub_members where user_id = p_to and last_seen > clock_timestamp() - interval '90 seconds';
  if mi is null or ti is null or mi <> ti then
    return jsonb_build_object('success', false, 'error', 'That player is not in your hub right now');
  end if;
  if exists (select 1 from public.darkom_challenges x where x.status = 'pending'
             and ((x.from_id = uid and x.to_id = p_to) or (x.from_id = p_to and x.to_id = uid))) then
    return jsonb_build_object('success', false, 'error', 'A challenge between you two is already waiting');
  end if;
  if (select count(*) from public.darkom_challenges x where x.status = 'pending' and x.from_id = uid) >= 3 then
    return jsonb_build_object('success', false, 'error', 'You have too many challenges waiting');
  end if;
  insert into public.darkom_challenges (from_id, from_name, to_id, to_name, instance, code)
    values (uid, public.darkom_name(uid), p_to, public.darkom_name(p_to), mi,
            upper(substr(md5(random()::text || clock_timestamp()::text), 1, 6)))
    returning * into c;
  return jsonb_build_object('success', true, 'challenge', public.darkom_challenge_json(c));
end;
$$;

create or replace function public.darkom_respond_challenge(p_id uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  c public.darkom_challenges;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into c from public.darkom_challenges where id = p_id for update;
  if not found or c.to_id <> uid then
    return jsonb_build_object('success', false, 'error', 'Challenge not found');
  end if;
  if c.status <> 'pending' then
    return jsonb_build_object('success', false, 'error', 'This challenge is no longer open');
  end if;
  if c.created_at < now() - interval '60 seconds' then
    update public.darkom_challenges set status = 'expired' where id = p_id returning * into c;
    return jsonb_build_object('success', false, 'error', 'This challenge ran out of time');
  end if;
  if coalesce(p_accept, false) and public.darkom_blocked_either(c.from_id, c.to_id) then
    update public.darkom_challenges set status = 'declined' where id = p_id returning * into c;
    return jsonb_build_object('success', false, 'error', 'You cannot accept this challenge');
  end if;
  update public.darkom_challenges
    set status = case when coalesce(p_accept, false) then 'accepted' else 'declined' end,
        accepted_at = case when coalesce(p_accept, false) then now() else null end
    where id = p_id returning * into c;
  return jsonb_build_object('success', true, 'challenge', public.darkom_challenge_json(c));
end;
$$;

-- Both players report; XP only when both agree. Re-calling after the match is
-- settled returns this player's result.
create or replace function public.darkom_report_duel(p_challenge uuid, p_won boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  c public.darkom_challenges;
  today date := (now() at time zone 'utc')::date;
  mine text := case when coalesce(p_won, false) then 'won' else 'lost' end;
  theirs text;
  winner uuid;
  loser uuid;
  pair_wins integer;
  uxp integer;
  lxp integer;
  w_cnt integer;
  l_cnt integer;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into c from public.darkom_challenges where id = p_challenge for update;
  if not found or (c.from_id <> uid and c.to_id <> uid) then
    return jsonb_build_object('success', false, 'error', 'Challenge not found');
  end if;
  if c.status = 'done' then
    return jsonb_build_object('success', true, 'accepted', coalesce(c.agreed, false),
      'xp', case when c.from_id = uid then c.from_xp else c.to_xp end,
      'error', case when coalesce(c.agreed, false) then null else 'The two results did not match, so there is no XP this time' end);
  end if;
  if c.status <> 'accepted' then
    return jsonb_build_object('success', false, 'error', 'This duel is not active');
  end if;
  if c.accepted_at > now() - interval '10 seconds' then
    return jsonb_build_object('success', false, 'error', 'That was too quick to count');
  end if;

  if c.from_id = uid then
    if c.from_result is not null then
      return jsonb_build_object('success', true, 'accepted', false, 'xp', 0, 'pending', true,
        'error', 'Waiting for your opponent to confirm');
    end if;
    update public.darkom_challenges set from_result = mine where id = c.id returning * into c;
    theirs := c.to_result;
  else
    if c.to_result is not null then
      return jsonb_build_object('success', true, 'accepted', false, 'xp', 0, 'pending', true,
        'error', 'Waiting for your opponent to confirm');
    end if;
    update public.darkom_challenges set to_result = mine where id = c.id returning * into c;
    theirs := c.from_result;
  end if;

  if theirs is null then
    return jsonb_build_object('success', true, 'accepted', false, 'xp', 0, 'pending', true,
      'error', 'Waiting for your opponent to confirm');
  end if;

  if c.from_result = c.to_result then
    update public.darkom_challenges set status = 'done', agreed = false where id = c.id;
    return jsonb_build_object('success', true, 'accepted', false, 'xp', 0,
      'error', 'The two results did not match, so there is no XP this time');
  end if;

  winner := case when c.from_result = 'won' then c.from_id else c.to_id end;
  loser := case when winner = c.from_id then c.to_id else c.from_id end;
  update public.darkom_challenges set status = 'done', agreed = true, winner_id = winner where id = c.id;

  -- same opponent beaten more than 3 times today: nothing for either side
  select count(*) into pair_wins from public.darkom_challenges x
    where x.status = 'done' and x.agreed and x.winner_id = winner
      and ((x.from_id = winner and x.to_id = loser) or (x.to_id = winner and x.from_id = loser))
      and (x.created_at at time zone 'utc')::date = today;
  uxp := case when pair_wins > 3 then 0 else 30 end;
  lxp := case when pair_wins > 3 then 0 else 10 end;

  select count(*) into w_cnt from public.darkom_rewards where user_id = winner and kind = 'duel' and day = today and xp > 0;
  select count(*) into l_cnt from public.darkom_rewards where user_id = loser and kind = 'duel' and day = today and xp > 0;
  if w_cnt >= 10 then uxp := 0; end if;
  if l_cnt >= 10 then lxp := 0; end if;

  if uxp > 0 then
    insert into public.game_scores (user_id, game_name, score, won) values (winner, 'Darkom Arena', uxp, true);
    insert into public.daily_play_log (user_id, play_date) values (winner, today) on conflict do nothing;
  end if;
  if lxp > 0 then
    insert into public.game_scores (user_id, game_name, score, won) values (loser, 'Darkom Arena', lxp, false);
    insert into public.daily_play_log (user_id, play_date) values (loser, today) on conflict do nothing;
  end if;
  insert into public.darkom_rewards (user_id, kind, ref_id, xp) values (winner, 'duel', c.id, uxp), (loser, 'duel', c.id, lxp);

  update public.darkom_challenges set
    from_xp = case when from_id = winner then uxp else lxp end,
    to_xp = case when to_id = winner then uxp else lxp end
  where id = c.id;

  return jsonb_build_object('success', true, 'accepted', true, 'xp', case when uid = winner then uxp else lxp end);
end;
$$;

-- ---------------------------------------------------------------------------
-- House squads
-- ---------------------------------------------------------------------------
create or replace function public.darkom_create_squad(p_house uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.darkom_squads;
  nm text;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_house is null or not public.darkom_is_house_member(p_house, uid) then
    return jsonb_build_object('success', false, 'error', 'Only house members can start a squad');
  end if;
  perform public.darkom_close_stale_squads();
  if exists (select 1 from public.darkom_squad_members m join public.darkom_squads q on q.id = m.squad_id
             where m.user_id = uid and q.status in ('open', 'started')) then
    return jsonb_build_object('success', false, 'error', 'Leave your current squad first');
  end if;
  nm := public.darkom_name(uid);
  insert into public.darkom_squads (house_id, host_id, host_name) values (p_house, uid, nm) returning * into s;
  insert into public.darkom_squad_members (squad_id, user_id, name) values (s.id, uid, nm);
  perform public.darkom_refresh_squad_arrays(s.id);
  return jsonb_build_object('success', true, 'squad', public.darkom_squad_json(s.id));
end;
$$;

create or replace function public.darkom_join_squad(p_squad uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.darkom_squads;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  perform public.darkom_close_stale_squads();
  select * into s from public.darkom_squads where id = p_squad for update;
  if not found then return jsonb_build_object('success', false, 'error', 'Squad not found'); end if;
  if not public.darkom_is_house_member(s.house_id, uid) then
    return jsonb_build_object('success', false, 'error', 'Only members of this house can join');
  end if;
  if public.darkom_is_squad_member(s.id, uid) then
    return jsonb_build_object('success', true, 'squad', public.darkom_squad_json(s.id));
  end if;
  if s.status <> 'open' then return jsonb_build_object('success', false, 'error', 'This squad is no longer open'); end if;
  if cardinality(s.member_ids) >= s.max_players then
    return jsonb_build_object('success', false, 'error', 'This squad is full');
  end if;
  if exists (select 1 from public.darkom_squad_members m join public.darkom_squads q on q.id = m.squad_id
             where m.user_id = uid and q.status in ('open', 'started')) then
    return jsonb_build_object('success', false, 'error', 'Leave your current squad first');
  end if;
  insert into public.darkom_squad_members (squad_id, user_id, name) values (s.id, uid, public.darkom_name(uid));
  perform public.darkom_refresh_squad_arrays(s.id);
  return jsonb_build_object('success', true, 'squad', public.darkom_squad_json(s.id));
end;
$$;

create or replace function public.darkom_leave_squad(p_squad uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.darkom_squads;
  nxt uuid;
  nxt_name text;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into s from public.darkom_squads where id = p_squad for update;
  if not found or not public.darkom_is_squad_member(p_squad, uid) then
    return jsonb_build_object('success', true);
  end if;
  delete from public.darkom_squad_members where squad_id = p_squad and user_id = uid;
  select user_id, name into nxt, nxt_name from public.darkom_squad_members where squad_id = p_squad order by joined_at limit 1;
  if nxt is null then
    update public.darkom_squads set status = 'closed', updated_at = now() where id = p_squad;
  elsif s.host_id = uid then
    update public.darkom_squads set host_id = nxt, host_name = nxt_name where id = p_squad;
  end if;
  perform public.darkom_refresh_squad_arrays(p_squad);
  return jsonb_build_object('success', true);
end;
$$;

create or replace function public.darkom_start_squad(p_squad uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.darkom_squads;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  perform public.darkom_close_stale_squads();
  select * into s from public.darkom_squads where id = p_squad for update;
  if not found then return jsonb_build_object('success', false, 'error', 'Squad not found'); end if;
  if s.host_id <> uid then return jsonb_build_object('success', false, 'error', 'Only the host can start the squad'); end if;
  if s.status <> 'open' then return jsonb_build_object('success', false, 'error', 'This squad already started or closed'); end if;
  if cardinality(s.member_ids) < 2 then
    return jsonb_build_object('success', false, 'error', 'Wait for at least one more member to join');
  end if;
  update public.darkom_squads set status = 'started', started_at = now(), started_count = cardinality(member_ids), updated_at = now()
    where id = p_squad;
  return jsonb_build_object('success', true, 'squad', public.darkom_squad_json(p_squad));
end;
$$;

create or replace function public.darkom_open_squads(p_house uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in', 'squads', '[]'::jsonb); end if;
  if p_house is null or not public.darkom_is_house_member(p_house, uid) then
    return jsonb_build_object('success', false, 'error', 'Only house members can see squads', 'squads', '[]'::jsonb);
  end if;
  perform public.darkom_close_stale_squads();
  return jsonb_build_object('success', true, 'squads', coalesce((
    select jsonb_agg(public.darkom_squad_json(q.id) order by q.created_at desc)
    from public.darkom_squads q where q.house_id = p_house and q.status = 'open'), '[]'::jsonb));
end;
$$;

create or replace function public.darkom_report_squad_match(p_squad uuid, p_placement integer, p_players integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.darkom_squads;
  today date := (now() at time zone 'utc')::date;
  players integer;
  place integer := coalesce(p_placement, 0);
  gain integer;
  cnt integer;
  m public.darkom_squad_members;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into s from public.darkom_squads where id = p_squad for update;
  if not found or not public.darkom_is_squad_member(p_squad, uid) then
    return jsonb_build_object('success', false, 'error', 'Squad not found');
  end if;
  if s.status <> 'started' then
    return jsonb_build_object('success', false, 'error', 'This squad match is not active');
  end if;
  if s.started_at > now() - interval '20 seconds' then
    return jsonb_build_object('success', false, 'error', 'That was too quick to count');
  end if;
  select * into m from public.darkom_squad_members where squad_id = p_squad and user_id = uid for update;
  if m.reported then
    return jsonb_build_object('success', true, 'accepted', false, 'xp', 0, 'error', 'Your result is already in');
  end if;
  players := least(greatest(coalesce(p_players, 2), 2), greatest(s.started_count, 2));
  if place < 1 or place > players then
    return jsonb_build_object('success', false, 'error', 'That result does not look right');
  end if;
  update public.darkom_squad_members set reported = true where squad_id = p_squad and user_id = uid;

  select count(*) into cnt from public.darkom_rewards r where r.user_id = uid and r.kind = 'squad' and r.day = today and r.xp > 0;
  gain := case when cnt >= 10 then 0 else 8 + (players - place) * 8 + (case when place = 1 then 12 else 0 end) end;
  if gain > 0 then
    insert into public.game_scores (user_id, game_name, score, won) values (uid, 'Darkom Arena', gain, place = 1);
    insert into public.daily_play_log (user_id, play_date) values (uid, today) on conflict do nothing;
  end if;
  insert into public.darkom_rewards (user_id, kind, ref_id, xp) values (uid, 'squad', p_squad, gain);

  if not exists (select 1 from public.darkom_squad_members where squad_id = p_squad and not reported) then
    update public.darkom_squads set status = 'closed', updated_at = now() where id = p_squad;
  end if;
  return jsonb_build_object('success', true, 'accepted', true, 'xp', gain);
end;
$$;

grant execute on function
  public.darkom_join_hub(), public.darkom_hub_heartbeat(text), public.darkom_leave_hub(text),
  public.darkom_recent_messages(text, integer), public.darkom_send_message(text, text),
  public.darkom_block_user(uuid), public.darkom_unblock_user(uuid), public.darkom_blocked_ids(),
  public.darkom_report_user(uuid, text, text, uuid),
  public.darkom_challenge(uuid), public.darkom_respond_challenge(uuid, boolean), public.darkom_report_duel(uuid, boolean),
  public.darkom_create_squad(uuid), public.darkom_join_squad(uuid), public.darkom_leave_squad(uuid),
  public.darkom_start_squad(uuid), public.darkom_open_squads(uuid),
  public.darkom_report_squad_match(uuid, integer, integer),
  public.darkom_admin_reports(), public.darkom_admin_clear_mute(uuid)
to authenticated;

-- ---------------------------------------------------------------------------
-- Realtime (only if the publication exists)
-- ---------------------------------------------------------------------------
do $$
declare t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['darkom_chat_messages', 'darkom_challenges', 'darkom_squads'] loop
      if not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end $$;

notify pgrst, 'reload schema';
