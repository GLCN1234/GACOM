-- Stakes for Arena duels. Both players put the same stake into the pot when a
-- duel starts; the winner is paid the pot minus the platform fee, a draw or a
-- cancelled duel refunds everyone. Money moves through the same wallet
-- functions the Arena already uses (deduct_arena_stake / refund_arena_stake).
-- Free duels (stake 0) behave exactly as before.

alter table public.duel_matches add column if not exists stake_amount integer not null default 0;
alter table public.duel_matches add column if not exists payout integer;
alter table public.duel_matches add column if not exists fee integer;
alter table public.duel_matches add column if not exists settled boolean not null default false;

create index if not exists duel_matches_unsettled_idx
  on public.duel_matches (status) where settled = false and stake_amount > 0;

-- Pay out or refund a finished duel. Never throws: if the wallet call fails
-- the duel stays unsettled and duel_settle_mine() retries it later.
create or replace function public.duel_settle(p_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  m public.duel_matches;
  pct numeric := 15;
  pot integer;
  f integer;
  pay integer;
  r jsonb;
begin
  select * into m from public.duel_matches where id = p_id for update;
  if not found or m.settled or m.stake_amount <= 0 then
    return;
  end if;
  if m.status not in ('completed', 'cancelled') then
    return;
  end if;

  begin
    select coalesce(platform_fee_percent, 15) into pct from public.arena_settings limit 1;
  exception when others then
    pct := 15;
  end;
  if pct is null then pct := 15; end if;

  begin
    if m.status = 'cancelled' then
      -- Only the creator ever paid into a duel that never started.
      if m.opponent_id is null then
        r := public.refund_arena_stake(m.creator_id, m.stake_amount, 'DUEL_REFUND_' || m.id::text);
        if coalesce((r ->> 'success')::boolean, false) is not true then
          raise exception 'refund failed';
        end if;
      end if;
    elsif m.is_draw or m.winner_id is null then
      r := public.refund_arena_stake(m.creator_id, m.stake_amount, 'DUEL_DRAW_A_' || m.id::text);
      if coalesce((r ->> 'success')::boolean, false) is not true then
        raise exception 'refund failed';
      end if;
      if m.opponent_id is not null then
        r := public.refund_arena_stake(m.opponent_id, m.stake_amount, 'DUEL_DRAW_B_' || m.id::text);
        if coalesce((r ->> 'success')::boolean, false) is not true then
          raise exception 'refund failed';
        end if;
      end if;
    else
      pot := m.stake_amount * 2;
      f := round(pot * pct / 100.0)::integer;
      pay := pot - f;
      r := public.refund_arena_stake(m.winner_id, pay, 'DUEL_WIN_' || m.id::text);
      if coalesce((r ->> 'success')::boolean, false) is not true then
        raise exception 'payout failed';
      end if;
      update public.duel_matches set payout = pay, fee = f where id = p_id;
    end if;
    update public.duel_matches set settled = true where id = p_id;
  exception when others then
    -- leave unsettled for a retry
    null;
  end;
end;
$$;

revoke execute on function public.duel_settle(uuid) from public, authenticated, anon;

-- Retry anything of mine that finished but was not paid out yet.
create or replace function public.duel_settle_mine()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  r record;
  n integer := 0;
begin
  if uid is null then
    return 0;
  end if;
  for r in
    select id from public.duel_matches
     where settled = false and stake_amount > 0
       and status in ('completed', 'cancelled')
       and (creator_id = uid or opponent_id = uid)
     limit 20
  loop
    perform public.duel_settle(r.id);
    n := n + 1;
  end loop;
  return n;
end;
$$;
grant execute on function public.duel_settle_mine() to authenticated;

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
  perform public.duel_settle(p_id);
  select * into m from public.duel_matches where id = p_id;
  return m;
end;
$$;
revoke execute on function public.duel_resolve(uuid) from public, authenticated, anon;

drop function if exists public.duel_quick(text, text);

create or replace function public.duel_quick(p_key text, p_name text, p_stake integer default 0)
returns public.duel_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  m public.duel_matches;
  stake integer := coalesce(p_stake, 0);
  r jsonb;
  old record;
begin
  if uid is null then
    raise exception 'not signed in';
  end if;
  if stake not in (0, 200, 500, 1000, 2000, 5000) then
    raise exception 'invalid stake';
  end if;

  for old in
    select id from public.duel_matches
     where status = 'waiting' and created_at < now() - interval '10 minutes'
  loop
    update public.duel_matches
       set status = 'cancelled', end_reason = 'expired', ended_at = now()
     where id = old.id;
    perform public.duel_settle(old.id);
  end loop;

  select * into m from public.duel_matches
   where status = 'waiting' and game_key = p_key and creator_id <> uid
     and stake_amount = stake
   order by created_at
   limit 1
   for update skip locked;

  if found then
    if stake > 0 then
      r := public.deduct_arena_stake(uid, stake, 'DUEL_JOIN_' || m.id::text);
      if coalesce((r ->> 'success')::boolean, false) is not true then
        raise exception '%', coalesce(r ->> 'error', 'Not enough balance for this stake');
      end if;
    end if;
    update public.duel_matches
       set opponent_id = uid, status = 'active', started_at = now(),
           deadline = now() + interval '20 minutes'
     where id = m.id
     returning * into m;
    return m;
  end if;

  select * into m from public.duel_matches
   where status = 'waiting' and game_key = p_key and creator_id = uid
     and stake_amount = stake
   order by created_at desc
   limit 1;
  if found then
    return m;
  end if;

  if stake > 0 then
    r := public.deduct_arena_stake(uid, stake, 'DUEL_OPEN_' || p_key || '_' || extract(epoch from clock_timestamp())::text);
    if coalesce((r ->> 'success')::boolean, false) is not true then
      raise exception '%', coalesce(r ->> 'error', 'Not enough balance for this stake');
    end if;
  end if;

  insert into public.duel_matches (game_key, game_name, creator_id, stake_amount)
  values (p_key, p_name, uid, stake)
  returning * into m;
  return m;
end;
$$;
grant execute on function public.duel_quick(text, text, integer) to authenticated;

create or replace function public.duel_join(p_id uuid)
returns public.duel_matches
language plpgsql
security definer
set search_path = public
as $$
declare
  uid uuid := auth.uid();
  m public.duel_matches;
  r jsonb;
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
  if m.stake_amount > 0 then
    r := public.deduct_arena_stake(uid, m.stake_amount, 'DUEL_JOIN_' || m.id::text);
    if coalesce((r ->> 'success')::boolean, false) is not true then
      raise exception '%', coalesce(r ->> 'error', 'Not enough balance for this stake');
    end if;
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
    perform public.duel_settle(p_id);
    select * into m from public.duel_matches where id = p_id;
  end if;
  return m;
end;
$$;

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
    perform public.duel_settle(p_id);
    select * into m from public.duel_matches where id = p_id;
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
  perform public.duel_settle(p_id);
  select * into m from public.duel_matches where id = p_id;
  return m;
end;
$$;

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
    perform public.duel_settle(p_id);
    select * into m from public.duel_matches where id = p_id;
  end if;
  return m;
end;
$$;

grant execute on function public.duel_join(uuid) to authenticated;
grant execute on function public.duel_cancel(uuid) to authenticated;
grant execute on function public.duel_forfeit(uuid) to authenticated;
grant execute on function public.duel_claim(uuid) to authenticated;
