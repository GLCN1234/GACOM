-- Arena duels: head-to-head score races for every Arena game.
-- Both players get the same seed and play on their own device; the server
-- decides the winner from the two submitted scores (higher score wins, ties
-- go to the faster finish, otherwise a draw). All writes go through the
-- security definer functions below, so clients cannot edit a match directly.

create table if not exists public.duel_matches (
  id uuid primary key default gen_random_uuid(),
  game_key text not null,
  game_name text not null,
  creator_id uuid not null references public.profiles(id) on delete cascade,
  opponent_id uuid references public.profiles(id) on delete set null,
  seed integer not null default floor(random() * 2000000000)::integer,
  status text not null default 'waiting'
    check (status in ('waiting', 'active', 'completed', 'cancelled')),
  creator_score integer,
  creator_ms integer,
  opponent_score integer,
  opponent_ms integer,
  winner_id uuid references public.profiles(id) on delete set null,
  is_draw boolean not null default false,
  end_reason text,
  deadline timestamptz,
  created_at timestamptz not null default now(),
  started_at timestamptz,
  ended_at timestamptz
);

create index if not exists duel_matches_lobby_idx
  on public.duel_matches (status, game_key, created_at);
create index if not exists duel_matches_creator_idx on public.duel_matches (creator_id);
create index if not exists duel_matches_opponent_idx on public.duel_matches (opponent_id);

alter table public.duel_matches enable row level security;

drop policy if exists duel_matches_read on public.duel_matches;
create policy duel_matches_read on public.duel_matches
  for select to authenticated using (true);

revoke insert, update, delete on public.duel_matches from authenticated, anon;
grant select on public.duel_matches to authenticated;

do $$
begin
  alter publication supabase_realtime add table public.duel_matches;
exception when others then
  null;
end $$;

-- Decide the result once both scores are in.
create or replace function public.duel_resolve(p_id uuid)
returns public.duel_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  m public.duel_matches;
  w uuid;
  d boolean := false;
begin
  select * into m from public.duel_matches where id = p_id for update;
  if m.status <> 'active' then
    return m;
  end if;
  if m.creator_score is null or m.opponent_score is null then
    return m;
  end if;

  if m.creator_score > m.opponent_score then
    w := m.creator_id;
  elsif m.opponent_score > m.creator_score then
    w := m.opponent_id;
  else
    if coalesce(m.creator_ms, 0) < coalesce(m.opponent_ms, 0) then
      w := m.creator_id;
    elsif coalesce(m.opponent_ms, 0) < coalesce(m.creator_ms, 0) then
      w := m.opponent_id;
    else
      w := null;
      d := true;
    end if;
  end if;

  update public.duel_matches
     set status = 'completed', winner_id = w, is_draw = d,
         end_reason = 'scores', ended_at = now()
   where id = p_id
   returning * into m;
  return m;
end;
$$;

-- Find an opponent for this game, or open a new waiting duel.
create or replace function public.duel_quick(p_key text, p_name text)
returns public.duel_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  m public.duel_matches;
begin
  if uid is null then
    raise exception 'not signed in';
  end if;

  update public.duel_matches
     set status = 'cancelled', end_reason = 'expired', ended_at = now()
   where status = 'waiting' and created_at < now() - interval '10 minutes';

  select * into m from public.duel_matches
   where status = 'waiting' and game_key = p_key and creator_id <> uid
   order by created_at
   limit 1
   for update skip locked;

  if found then
    update public.duel_matches
       set opponent_id = uid, status = 'active', started_at = now(),
           deadline = now() + interval '20 minutes'
     where id = m.id
     returning * into m;
    return m;
  end if;

  select * into m from public.duel_matches
   where status = 'waiting' and game_key = p_key and creator_id = uid
   order by created_at desc
   limit 1;
  if found then
    return m;
  end if;

  insert into public.duel_matches (game_key, game_name, creator_id)
  values (p_key, p_name, uid)
  returning * into m;
  return m;
end;
$$;

-- Join a specific waiting duel from the open list.
create or replace function public.duel_join(p_id uuid)
returns public.duel_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  m public.duel_matches;
begin
  if uid is null then
    raise exception 'not signed in';
  end if;
  select * into m from public.duel_matches where id = p_id for update;
  if not found then
    raise exception 'duel not found';
  end if;
  if m.status <> 'waiting' then
    raise exception 'duel already taken';
  end if;
  if m.creator_id = uid then
    raise exception 'cannot join your own duel';
  end if;
  update public.duel_matches
     set opponent_id = uid, status = 'active', started_at = now(),
         deadline = now() + interval '20 minutes'
   where id = p_id
   returning * into m;
  return m;
end;
$$;

create or replace function public.duel_cancel(p_id uuid)
returns public.duel_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  m public.duel_matches;
begin
  select * into m from public.duel_matches where id = p_id for update;
  if not found then
    raise exception 'duel not found';
  end if;
  if m.creator_id = uid and m.status = 'waiting' then
    update public.duel_matches
       set status = 'cancelled', end_reason = 'cancelled', ended_at = now()
     where id = p_id
     returning * into m;
  end if;
  return m;
end;
$$;

-- Record my score. Safe to call twice; only the first score counts.
create or replace function public.duel_submit(p_id uuid, p_score integer, p_ms integer)
returns public.duel_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  m public.duel_matches;
  s integer := greatest(coalesce(p_score, 0), 0);
  t integer := greatest(coalesce(p_ms, 0), 0);
begin
  if uid is null then
    raise exception 'not signed in';
  end if;
  select * into m from public.duel_matches where id = p_id for update;
  if not found then
    raise exception 'duel not found';
  end if;
  if m.status <> 'active' then
    return m;
  end if;

  if uid = m.creator_id then
    if m.creator_score is not null then
      return m;
    end if;
    update public.duel_matches
       set creator_score = s, creator_ms = t,
           deadline = now() + interval '10 minutes'
     where id = p_id;
  elsif uid = m.opponent_id then
    if m.opponent_score is not null then
      return m;
    end if;
    update public.duel_matches
       set opponent_score = s, opponent_ms = t,
           deadline = now() + interval '10 minutes'
     where id = p_id;
  else
    raise exception 'not a player in this duel';
  end if;

  return public.duel_resolve(p_id);
end;
$$;

-- Leaving an active duel before finishing hands the win to the other player.
create or replace function public.duel_forfeit(p_id uuid)
returns public.duel_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  m public.duel_matches;
  other uuid;
  mine integer;
begin
  select * into m from public.duel_matches where id = p_id for update;
  if not found then
    raise exception 'duel not found';
  end if;

  if m.status = 'waiting' and m.creator_id = uid then
    update public.duel_matches
       set status = 'cancelled', end_reason = 'cancelled', ended_at = now()
     where id = p_id
     returning * into m;
    return m;
  end if;

  if m.status <> 'active' then
    return m;
  end if;

  if uid = m.creator_id then
    other := m.opponent_id;
    mine := m.creator_score;
  elsif uid = m.opponent_id then
    other := m.creator_id;
    mine := m.opponent_score;
  else
    raise exception 'not a player in this duel';
  end if;

  if mine is not null then
    return m;
  end if;

  update public.duel_matches
     set status = 'completed', winner_id = other, is_draw = false,
         end_reason = 'forfeit', ended_at = now()
   where id = p_id
   returning * into m;
  return m;
end;
$$;

-- If I have finished and the opponent has gone quiet past the deadline, I win.
create or replace function public.duel_claim(p_id uuid)
returns public.duel_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  m public.duel_matches;
  mine integer;
  theirs integer;
begin
  select * into m from public.duel_matches where id = p_id for update;
  if not found then
    raise exception 'duel not found';
  end if;
  if m.status <> 'active' then
    return m;
  end if;

  if uid = m.creator_id then
    mine := m.creator_score;
    theirs := m.opponent_score;
  elsif uid = m.opponent_id then
    mine := m.opponent_score;
    theirs := m.creator_score;
  else
    raise exception 'not a player in this duel';
  end if;

  if mine is not null and theirs is null and m.deadline is not null and now() > m.deadline then
    update public.duel_matches
       set status = 'completed', winner_id = uid, is_draw = false,
           end_reason = 'timeout', ended_at = now()
     where id = p_id
     returning * into m;
  end if;
  return m;
end;
$$;

grant execute on function public.duel_quick(text, text) to authenticated;
grant execute on function public.duel_join(uuid) to authenticated;
grant execute on function public.duel_cancel(uuid) to authenticated;
grant execute on function public.duel_submit(uuid, integer, integer) to authenticated;
grant execute on function public.duel_forfeit(uuid) to authenticated;
grant execute on function public.duel_claim(uuid) to authenticated;
revoke execute on function public.duel_resolve(uuid) from public, authenticated, anon;

-- Win/loss standings, overall and per game.
create or replace view public.duel_standings as
select u.user_id,
       count(*) filter (where m.winner_id = u.user_id) as wins,
       count(*) filter (where m.winner_id is not null and m.winner_id <> u.user_id) as losses,
       count(*) filter (where m.is_draw) as draws,
       count(*) as played
  from public.duel_matches m
  cross join lateral (values (m.creator_id), (m.opponent_id)) as u(user_id)
 where m.status = 'completed' and u.user_id is not null
 group by u.user_id;

create or replace view public.duel_standings_by_game as
select m.game_key,
       u.user_id,
       count(*) filter (where m.winner_id = u.user_id) as wins,
       count(*) filter (where m.winner_id is not null and m.winner_id <> u.user_id) as losses,
       count(*) filter (where m.is_draw) as draws,
       count(*) as played
  from public.duel_matches m
  cross join lateral (values (m.creator_id), (m.opponent_id)) as u(user_id)
 where m.status = 'completed' and u.user_id is not null
 group by m.game_key, u.user_id;

grant select on public.duel_standings to authenticated;
grant select on public.duel_standings_by_game to authenticated;


notify pgrst, 'reload schema';
