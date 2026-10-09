-- Arena refunds without handing clients the raw refund function.
-- refund_arena_stake(user, amount, reference) stays service-role only. Clients
-- use these two checked wrappers instead:
--   arena_refund_entry(reference)  a stake was debited but the match could not be created or joined
--   arena_refund_match(match, why) a waiting match was cancelled by its creator, or a match ended in a draw
-- Every refund is written once to arena_refund_log (primary key), so repeats do nothing.
-- Safe to re-run.

create table if not exists public.arena_refund_log (
  ref text primary key,
  user_id uuid not null,
  match_id uuid,
  amount numeric not null,
  reason text not null,
  created_at timestamptz not null default now()
);
alter table public.arena_refund_log enable row level security;
revoke all on public.arena_refund_log from anon, authenticated;

create or replace function public.arena_refund_entry(p_reference text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  full_ref text;
  tx record;
  r jsonb;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_reference is null or length(p_reference) < 4 or length(p_reference) > 60 then
    return jsonb_build_object('success', false, 'error', 'Invalid reference');
  end if;
  perform pg_advisory_xact_lock(hashtextextended('gacom:wallet:' || uid::text, 0));
  full_ref := 'ARENA_' || left(p_reference, 60) || '_' || uid::text;
  select * into tx from public.wallet_transactions
   where user_id = uid and reference = full_ref and created_at > now() - interval '15 minutes'
   order by created_at desc limit 1;
  if not found then return jsonb_build_object('success', false, 'error', 'No recent stake to refund'); end if;
  if exists (select 1 from public.arena_refund_log where ref = 'ENTRY_' || full_ref) then
    return jsonb_build_object('success', true, 'already', true);
  end if;
  -- the stake is only refundable if it is not backing a live match of this player
  if exists (select 1 from public.arena_matches m
              where (m.creator_id = uid or m.opponent_id = uid)
                and m.status in ('waiting', 'active')
                and m.created_at >= tx.created_at - interval '1 minute') then
    return jsonb_build_object('success', false, 'error', 'This stake is in use by a match');
  end if;
  insert into public.arena_refund_log (ref, user_id, amount, reason) values ('ENTRY_' || full_ref, uid, tx.amount, 'entry_failed');
  r := public.refund_arena_stake(uid, tx.amount::integer, 'ARENA_REFUND_' || full_ref);
  return coalesce(r, jsonb_build_object('success', true));
end $$;

create or replace function public.arena_refund_match(p_match uuid, p_reason text)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  m record;
  who uuid;
  r jsonb;
  done int := 0;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_reason not in ('cancel', 'draw', 'dispute') then return jsonb_build_object('success', false, 'error', 'Invalid reason'); end if;
  select * into m from public.arena_matches where id = p_match for update;
  if not found then return jsonb_build_object('success', false, 'error', 'Match not found'); end if;
  if p_reason = 'dispute' then
    if not coalesce(public.sec_is_admin(), false) then return jsonb_build_object('success', false, 'error', 'Admins only'); end if;
    if m.winner_id is not null then return jsonb_build_object('success', false, 'error', 'This match already has a winner'); end if;
  elsif uid is distinct from m.creator_id and uid is distinct from m.opponent_id then
    return jsonb_build_object('success', false, 'error', 'Not your match');
  end if;
  if coalesce(m.stake_amount, 0) <= 0 then return jsonb_build_object('success', true, 'refunded', 0); end if;

  if p_reason = 'cancel' then
    -- only the creator, only while nobody has joined
    if uid is distinct from m.creator_id or m.opponent_id is not null or m.status not in ('waiting', 'cancelled') then
      return jsonb_build_object('success', false, 'error', 'This match cannot be cancelled here');
    end if;
    foreach who in array array[m.creator_id] loop
      if not exists (select 1 from public.arena_refund_log where ref = 'MATCH_' || p_match::text || '_' || who::text) then
        insert into public.arena_refund_log (ref, user_id, match_id, amount, reason)
        values ('MATCH_' || p_match::text || '_' || who::text, who, p_match, m.stake_amount, 'cancel');
        r := public.refund_arena_stake(who, m.stake_amount::integer, 'ARENA_REFUND_' || p_match::text || '_' || who::text);
        done := done + 1;
      end if;
    end loop;
    update public.arena_matches set status = 'cancelled' where id = p_match and status = 'waiting';
  elsif p_reason = 'dispute' then
    -- an admin settled a dispute with no winner: refund everyone who paid
    foreach who in array array[m.creator_id, m.opponent_id] loop
      if who is not null and not exists (select 1 from public.arena_refund_log where ref = 'MATCH_' || p_match::text || '_' || who::text) then
        insert into public.arena_refund_log (ref, user_id, match_id, amount, reason)
        values ('MATCH_' || p_match::text || '_' || who::text, who, p_match, m.stake_amount, 'dispute');
        r := public.refund_arena_stake(who, m.stake_amount::integer, 'ARENA_REFUND_' || p_match::text || '_' || who::text);
        done := done + 1;
      end if;
    end loop;
    update public.arena_matches set status = 'cancelled' where id = p_match;
  else
    -- draw: a started match with no winner, refund both players once
    if m.opponent_id is null or m.winner_id is not null or m.status not in ('active', 'completed') then
      return jsonb_build_object('success', false, 'error', 'This match is not a draw');
    end if;
    foreach who in array array[m.creator_id, m.opponent_id] loop
      if not exists (select 1 from public.arena_refund_log where ref = 'MATCH_' || p_match::text || '_' || who::text) then
        insert into public.arena_refund_log (ref, user_id, match_id, amount, reason)
        values ('MATCH_' || p_match::text || '_' || who::text, who, p_match, m.stake_amount, 'draw');
        r := public.refund_arena_stake(who, m.stake_amount::integer, 'ARENA_REFUND_' || p_match::text || '_' || who::text);
        done := done + 1;
      end if;
    end loop;
    update public.arena_matches set status = 'completed' where id = p_match and status = 'active';
  end if;
  return jsonb_build_object('success', true, 'refunded', done);
end $$;

revoke all on function public.arena_refund_entry(text) from public, anon;
revoke all on function public.arena_refund_match(uuid, text) from public, anon;
grant execute on function public.arena_refund_entry(text) to authenticated;
grant execute on function public.arena_refund_match(uuid, text) to authenticated;
notify pgrst, 'reload schema';
