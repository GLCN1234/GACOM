-- Squad Contracts: co-op missions for a house squad.
-- Team rewards are cosmetic progression only (Season Pass XP, through the
-- existing pass_add_xp and its own daily cap). Nothing here touches solo
-- mission points, ranked ladders, wallets or prizes.

-- 1. The host can now also pick a contract as the squad mode.
create or replace function public.darkom_set_squad_mode(p_squad uuid, p_mode text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.darkom_squads;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_mode is null or p_mode !~ '^(arena|city|contract_(clear|hold|bounty|data))$' then
    return jsonb_build_object('success', false, 'error', 'Unknown mode');
  end if;
  select * into s from public.darkom_squads where id = p_squad for update;
  if not found then return jsonb_build_object('success', false, 'error', 'Squad not found'); end if;
  if s.host_id <> uid then return jsonb_build_object('success', false, 'error', 'Only the host can change the mode'); end if;
  if s.status <> 'open' then return jsonb_build_object('success', false, 'error', 'This squad already started or closed'); end if;
  update public.darkom_squads set mode = p_mode, updated_at = now() where id = p_squad;
  return jsonb_build_object('success', true, 'squad', public.darkom_squad_json(p_squad));
end;
$$;

-- 2. One reward per player per squad, and a separate tally that no ranking reads.
create table if not exists public.darkom_coop_rewards (
  squad_id uuid not null references public.darkom_squads(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  contract text not null,
  xp integer not null default 0,
  day date not null default ((now() at time zone 'utc')::date),
  created_at timestamptz not null default now(),
  primary key (squad_id, user_id)
);
create index if not exists darkom_coop_rewards_user_day_idx on public.darkom_coop_rewards (user_id, day);
alter table public.darkom_coop_rewards enable row level security;
drop policy if exists darkom_coop_rewards_read on public.darkom_coop_rewards;
create policy darkom_coop_rewards_read on public.darkom_coop_rewards for select using (user_id = auth.uid());

-- 3. Claim the team reward after a won contract. Always answers with a message.
create or replace function public.darkom_report_coop_contract(p_squad uuid, p_contract text, p_seconds integer, p_kills integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.darkom_squads;
  today date := (now() at time zone 'utc')::date;
  done_today integer;
  base integer;
  xp integer;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_contract is null or p_contract !~ '^(clear|hold|bounty|data)$' then
    return jsonb_build_object('success', false, 'error', 'Unknown contract');
  end if;
  select * into s from public.darkom_squads where id = p_squad;
  if not found then return jsonb_build_object('success', false, 'error', 'Squad not found'); end if;
  if not exists (select 1 from public.darkom_squad_members m where m.squad_id = p_squad and m.user_id = uid) then
    return jsonb_build_object('success', false, 'error', 'You were not in this squad');
  end if;
  if s.mode <> ('contract_' || p_contract) or s.status <> 'started' or s.started_at is null then
    return jsonb_build_object('success', true, 'accepted', false, 'note', 'This squad was not running that contract');
  end if;
  if coalesce(s.started_count, 0) < 2 then
    return jsonb_build_object('success', true, 'accepted', false, 'note', 'Contracts need at least 2 players');
  end if;
  if now() - s.started_at < interval '75 seconds' or now() - s.started_at > interval '45 minutes' then
    return jsonb_build_object('success', true, 'accepted', false, 'note', 'That run was too short or too old to count');
  end if;
  if exists (select 1 from public.darkom_coop_rewards r where r.squad_id = p_squad and r.user_id = uid) then
    return jsonb_build_object('success', true, 'accepted', false, 'note', 'Already claimed for this contract');
  end if;
  select count(*) into done_today from public.darkom_coop_rewards r where r.user_id = uid and r.day = today;
  if done_today >= 3 then
    return jsonb_build_object('success', true, 'accepted', false, 'note', 'Daily squad reward limit reached (3)');
  end if;
  base := case p_contract when 'clear' then 60 when 'hold' then 60 when 'bounty' then 70 else 70 end;
  xp := base + least(2, greatest(0, s.started_count - 2)) * 10;
  insert into public.darkom_coop_rewards (squad_id, user_id, contract, xp, day) values (p_squad, uid, p_contract, xp, today);
  perform public.pass_add_xp(uid, xp);
  return jsonb_build_object('success', true, 'accepted', true, 'xp', xp,
    'done_today', done_today + 1, 'note', 'Team reward: ' || xp || ' Season Pass XP');
end;
$$;

grant execute on function public.darkom_set_squad_mode(uuid, text) to authenticated;
grant execute on function public.darkom_report_coop_contract(uuid, text, integer, integer) to authenticated;
notify pgrst, 'reload schema';
