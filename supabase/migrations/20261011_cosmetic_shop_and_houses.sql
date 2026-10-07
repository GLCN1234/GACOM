-- Paid cosmetics shop + the full Houses system.
--
-- Cosmetics: items can be free, premium (included with the subscription) or
-- bought with wallet money. Ownership is stored server side and equipping goes
-- through functions, so nobody can equip something they do not own.
--
-- Houses: roles, open or closed houses with join requests, levels and member
-- limits, weekly house wars with trophies, and emblems/banners bought by the
-- captain. Money moves through the same wallet functions the Arena uses
-- (deduct_arena_stake / refund_arena_stake).

-- ---------------------------------------------------------------------------
-- 1. Cosmetic catalogue
-- ---------------------------------------------------------------------------
alter table public.cosmetic_items add column if not exists price integer not null default 0;
alter table public.cosmetic_items add column if not exists rarity text not null default 'common';
alter table public.cosmetic_items add column if not exists asset jsonb not null default '{}'::jsonb;
alter table public.cosmetic_items add column if not exists description text;
alter table public.cosmetic_items add column if not exists is_active boolean not null default true;
alter table public.cosmetic_items add column if not exists sort_order integer not null default 0;
alter table public.cosmetic_items add column if not exists available_until timestamptz;
-- 'user' items are worn by a player, 'house' items belong to a house.
alter table public.cosmetic_items add column if not exists scope text not null default 'user';

do $$
begin
  create unique index if not exists cosmetic_items_category_name_uq on public.cosmetic_items (category, name);
exception when unique_violation then
  raise notice 'duplicate cosmetic names exist, unique index skipped';
end $$;

drop policy if exists "admins manage cosmetic items" on public.cosmetic_items;
create policy "admins manage cosmetic items" on public.cosmetic_items for all
  using (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role::text in ('admin', 'super_admin')))
  with check (exists (select 1 from public.profiles p where p.id = auth.uid() and p.role::text in ('admin', 'super_admin')));

-- ---------------------------------------------------------------------------
-- 2. What players own and wear
-- ---------------------------------------------------------------------------
create table if not exists public.user_cosmetic_inventory (
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null references public.cosmetic_items(id) on delete cascade,
  acquired_at timestamptz not null default now(),
  source text not null default 'purchase', -- purchase | gift | house_win | admin
  price_paid integer not null default 0,
  primary key (user_id, item_id)
);
alter table public.user_cosmetic_inventory enable row level security;
drop policy if exists "users view own inventory" on public.user_cosmetic_inventory;
create policy "users view own inventory" on public.user_cosmetic_inventory for select using (auth.uid() = user_id);

alter table public.user_cosmetics add column if not exists equipped_hero_outfit uuid references public.cosmetic_items(id);
alter table public.user_cosmetics add column if not exists equipped_trail uuid references public.cosmetic_items(id);
alter table public.user_cosmetics add column if not exists equipped_profile_banner uuid references public.cosmetic_items(id);

-- Writes now go through equip_cosmetic(); the old policy let anyone write any
-- item id straight into their own row.
drop policy if exists "users manage own cosmetics" on public.user_cosmetics;

create or replace function public.cosmetic_is_pro(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (
    select 1 from public.edu_subscriptions s
    where s.user_id = p_user and s.status = 'active' and s.expires_at > now()
  );
$$;

create or replace function public.cosmetic_is_owned(p_user uuid, p_item uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare it public.cosmetic_items;
begin
  select * into it from public.cosmetic_items where id = p_item;
  if not found then return false; end if;
  if it.price <= 0 and not it.requires_premium then return true; end if;           -- free for everyone
  if exists (select 1 from public.user_cosmetic_inventory i where i.user_id = p_user and i.item_id = p_item) then return true; end if;
  if it.requires_premium and public.cosmetic_is_pro(p_user) then return true; end if; -- included with premium
  return false;
end;
$$;

create or replace function public.purchase_cosmetic(p_item_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  it public.cosmetic_items;
  r jsonb;
  bal numeric;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into it from public.cosmetic_items where id = p_item_id;
  if not found or not it.is_active or it.scope <> 'user' then
    return jsonb_build_object('success', false, 'error', 'This item is not available');
  end if;
  if it.available_until is not null and it.available_until < now() then
    return jsonb_build_object('success', false, 'error', 'This item is no longer on sale');
  end if;
  if it.price <= 0 then
    if it.requires_premium then
      return jsonb_build_object('success', false, 'error', 'Included with a Premium membership');
    end if;
    return jsonb_build_object('success', false, 'error', 'This item is not for sale');
  end if;
  if exists (select 1 from public.user_cosmetic_inventory where user_id = uid and item_id = p_item_id) then
    return jsonb_build_object('success', false, 'error', 'You already own this');
  end if;

  r := public.deduct_arena_stake(uid, it.price, 'COSMETIC_' || p_item_id::text || '_' || uid::text);
  if coalesce((r ->> 'success')::boolean, false) is not true then
    return jsonb_build_object('success', false, 'error', coalesce(r ->> 'error', 'Not enough balance'));
  end if;

  begin
    insert into public.user_cosmetic_inventory (user_id, item_id, source, price_paid)
    values (uid, p_item_id, 'purchase', it.price);
  exception when others then
    perform public.refund_arena_stake(uid, it.price, 'COSMETIC_REFUND_' || p_item_id::text || '_' || uid::text);
    return jsonb_build_object('success', false, 'error', 'Could not complete the purchase, you were not charged');
  end;

  select wallet_balance into bal from public.profiles where id = uid;
  return jsonb_build_object('success', true, 'balance', bal);
end;
$$;
grant execute on function public.purchase_cosmetic(uuid) to authenticated;

-- Equip an item you own, or pass only p_category to take it off.
create or replace function public.equip_cosmetic(p_item_id uuid default null, p_category text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  it public.cosmetic_items;
  cat text;
  col text;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_item_id is not null then
    select * into it from public.cosmetic_items where id = p_item_id;
    if not found or it.scope <> 'user' then return jsonb_build_object('success', false, 'error', 'Unknown item'); end if;
    if not public.cosmetic_is_owned(uid, p_item_id) then
      return jsonb_build_object('success', false, 'error', case when it.requires_premium then 'Premium members only' else 'You do not own this yet' end);
    end if;
    cat := it.category;
  else
    cat := p_category;
  end if;
  col := case cat
    when 'name_color' then 'equipped_name_color'
    when 'badge' then 'equipped_badge'
    when 'avatar_frame' then 'equipped_avatar_frame'
    when 'hero_outfit' then 'equipped_hero_outfit'
    when 'trail' then 'equipped_trail'
    when 'profile_banner' then 'equipped_profile_banner'
    else null end;
  if col is null then return jsonb_build_object('success', false, 'error', 'Unknown category'); end if;
  insert into public.user_cosmetics (user_id) values (uid) on conflict (user_id) do nothing;
  execute format('update public.user_cosmetics set %I = $1, updated_at = now() where user_id = $2', col) using p_item_id, uid;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.equip_cosmetic(uuid, text) to authenticated;

-- Everything a player owns, as ids, for the shop screen.
create or replace function public.my_cosmetic_ids()
returns setof uuid language sql stable security definer set search_path = public as $$
  select i.item_id from public.user_cosmetic_inventory i where i.user_id = auth.uid();
$$;
grant execute on function public.my_cosmetic_ids() to authenticated;

-- ---------------------------------------------------------------------------
-- 3. Houses: structure
-- ---------------------------------------------------------------------------
alter table public.houses add column if not exists motto text;
alter table public.houses add column if not exists description text;
alter table public.houses add column if not exists is_open boolean not null default true;
alter table public.houses add column if not exists emblem_item_id uuid references public.cosmetic_items(id);
alter table public.houses add column if not exists banner_item_id uuid references public.cosmetic_items(id);
alter table public.houses add column if not exists updated_at timestamptz not null default now();

alter table public.house_members add column if not exists role text not null default 'member';
do $$
begin
  alter table public.house_members add constraint house_members_role_chk check (role in ('captain', 'officer', 'member'));
exception when duplicate_object then null;
end $$;
update public.house_members hm set role = 'captain'
  from public.houses h where h.id = hm.house_id and h.captain_id = hm.user_id and hm.role <> 'captain';

do $$
begin
  create unique index if not exists house_members_one_house_per_user on public.house_members (user_id);
exception when unique_violation then
  raise notice 'some users are in two houses; clean that up and run this statement again';
end $$;

create table if not exists public.house_inventory (
  house_id uuid not null references public.houses(id) on delete cascade,
  item_id uuid not null references public.cosmetic_items(id) on delete cascade,
  acquired_at timestamptz not null default now(),
  price_paid integer not null default 0,
  primary key (house_id, item_id)
);
alter table public.house_inventory enable row level security;
drop policy if exists "anyone views house inventory" on public.house_inventory;
create policy "anyone views house inventory" on public.house_inventory for select using (true);

create table if not exists public.house_join_requests (
  id uuid primary key default gen_random_uuid(),
  house_id uuid not null references public.houses(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  message text,
  status text not null default 'pending', -- pending | accepted | declined
  created_at timestamptz not null default now(),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz
);
create unique index if not exists house_join_requests_pending_uq
  on public.house_join_requests (house_id, user_id) where status = 'pending';
alter table public.house_join_requests enable row level security;
drop policy if exists "view own or managed requests" on public.house_join_requests;
create policy "view own or managed requests" on public.house_join_requests for select using (
  auth.uid() = user_id
  or exists (select 1 from public.house_members hm where hm.house_id = house_join_requests.house_id
             and hm.user_id = auth.uid() and hm.role in ('captain', 'officer'))
);

create table if not exists public.house_weekly_results (
  week_start date not null,
  house_id uuid not null references public.houses(id) on delete cascade,
  rank integer not null,
  points integer not null,
  primary key (week_start, house_id)
);
alter table public.house_weekly_results enable row level security;
drop policy if exists "anyone views house results" on public.house_weekly_results;
create policy "anyone views house results" on public.house_weekly_results for select using (true);

-- Joining, editing and founding now go through the functions below, so the
-- loose direct-write policies are removed. Leaving (delete) stays.
drop policy if exists "users join houses" on public.house_members;
drop policy if exists "signed in users create houses" on public.houses;
drop policy if exists "captains manage own house" on public.houses;
drop policy if exists "users leave houses" on public.house_members;
create policy "users leave houses" on public.house_members for delete
  using (auth.uid() = user_id and role <> 'captain');

-- ---------------------------------------------------------------------------
-- 4. Houses: points, levels, limits
-- ---------------------------------------------------------------------------
create or replace function public.house_level(p_points integer)
returns integer language sql immutable as $$
  select 1 + floor(sqrt(greatest(p_points, 0) / 1000.0))::int;
$$;

create or replace function public.house_member_limit(p_level integer)
returns integer language sql immutable as $$
  select least(100, 20 + 10 * (greatest(p_level, 1) - 1));
$$;

create or replace function public.house_week_points(p_house_id uuid)
returns integer language sql stable as $$
  select coalesce(sum(gs.score), 0)::int
  from public.game_scores gs
  join public.house_members hm on hm.user_id = gs.user_id
  where hm.house_id = p_house_id
    and gs.created_at >= date_trunc('week', now());
$$;

-- ---------------------------------------------------------------------------
-- 5. Houses: actions
-- ---------------------------------------------------------------------------
create or replace function public.house_role_of(p_house uuid, p_user uuid)
returns text language sql stable security definer set search_path = public as $$
  select role from public.house_members where house_id = p_house and user_id = p_user;
$$;

create or replace function public.found_house(p_name text, p_color text, p_motto text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  nm text := btrim(coalesce(p_name, ''));
  fee constant integer := 500;     -- founding fee for players without premium
  r jsonb;
  h public.houses;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if char_length(nm) < 3 or char_length(nm) > 24 then
    return jsonb_build_object('success', false, 'error', 'House names need 3 to 24 characters');
  end if;
  if exists (select 1 from public.house_members where user_id = uid) then
    return jsonb_build_object('success', false, 'error', 'Leave your current house first');
  end if;
  if exists (select 1 from public.houses where lower(name) = lower(nm)) then
    return jsonb_build_object('success', false, 'error', 'That name is taken');
  end if;
  if not public.cosmetic_is_pro(uid) then
    r := public.deduct_arena_stake(uid, fee, 'HOUSE_FOUND_' || uid::text || '_' || extract(epoch from clock_timestamp())::text);
    if coalesce((r ->> 'success')::boolean, false) is not true then
      return jsonb_build_object('success', false, 'error', 'Founding a house costs N' || fee || ' without premium, and your balance is too low');
    end if;
  end if;
  begin
    insert into public.houses (name, banner_color, captain_id, motto)
    values (nm, coalesce(nullif(p_color, ''), '#E84B00'), uid, nullif(btrim(coalesce(p_motto, '')), ''))
    returning * into h;
    insert into public.house_members (house_id, user_id, role) values (h.id, uid, 'captain');
  exception when others then
    if not public.cosmetic_is_pro(uid) then
      perform public.refund_arena_stake(uid, fee, 'HOUSE_FOUND_REFUND_' || uid::text);
    end if;
    return jsonb_build_object('success', false, 'error', 'Could not found the house, you were not charged');
  end;
  return jsonb_build_object('success', true, 'house_id', h.id);
end;
$$;
grant execute on function public.found_house(text, text, text) to authenticated;

create or replace function public.join_house(p_house_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  h public.houses;
  cnt integer;
  lim integer;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into h from public.houses where id = p_house_id;
  if not found then return jsonb_build_object('success', false, 'error', 'House not found'); end if;
  if exists (select 1 from public.house_members where user_id = uid) then
    return jsonb_build_object('success', false, 'error', 'Leave your current house first');
  end if;
  if not h.is_open then
    return jsonb_build_object('success', false, 'error', 'closed');
  end if;
  select count(*) into cnt from public.house_members where house_id = p_house_id;
  lim := public.house_member_limit(public.house_level(public.get_house_points(p_house_id)));
  if cnt >= lim then return jsonb_build_object('success', false, 'error', 'This house is full'); end if;
  insert into public.house_members (house_id, user_id, role) values (p_house_id, uid, 'member');
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.join_house(uuid) to authenticated;

create or replace function public.request_join_house(p_house_id uuid, p_message text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if exists (select 1 from public.house_members where user_id = uid) then
    return jsonb_build_object('success', false, 'error', 'Leave your current house first');
  end if;
  if not exists (select 1 from public.houses where id = p_house_id) then
    return jsonb_build_object('success', false, 'error', 'House not found');
  end if;
  begin
    insert into public.house_join_requests (house_id, user_id, message)
    values (p_house_id, uid, left(nullif(btrim(coalesce(p_message, '')), ''), 200));
  exception when unique_violation then
    return jsonb_build_object('success', false, 'error', 'You already asked to join');
  end;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.request_join_house(uuid, text) to authenticated;

create or replace function public.review_join_request(p_request_id uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  rq public.house_join_requests;
  cnt integer;
  lim integer;
begin
  select * into rq from public.house_join_requests where id = p_request_id and status = 'pending';
  if not found then return jsonb_build_object('success', false, 'error', 'Request not found'); end if;
  if coalesce(public.house_role_of(rq.house_id, uid), '') not in ('captain', 'officer') then
    return jsonb_build_object('success', false, 'error', 'Only the captain or officers can do that');
  end if;
  if p_accept then
    if exists (select 1 from public.house_members where user_id = rq.user_id) then
      update public.house_join_requests set status = 'declined', reviewed_by = uid, reviewed_at = now() where id = p_request_id;
      return jsonb_build_object('success', false, 'error', 'That player already joined another house');
    end if;
    select count(*) into cnt from public.house_members where house_id = rq.house_id;
    lim := public.house_member_limit(public.house_level(public.get_house_points(rq.house_id)));
    if cnt >= lim then return jsonb_build_object('success', false, 'error', 'Your house is full'); end if;
    insert into public.house_members (house_id, user_id, role) values (rq.house_id, rq.user_id, 'member');
    update public.house_join_requests set status = 'accepted', reviewed_by = uid, reviewed_at = now() where id = p_request_id;
    -- every other pending request from that player is now moot
    update public.house_join_requests set status = 'declined', reviewed_at = now()
      where user_id = rq.user_id and status = 'pending';
  else
    update public.house_join_requests set status = 'declined', reviewed_by = uid, reviewed_at = now() where id = p_request_id;
  end if;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.review_join_request(uuid, boolean) to authenticated;

create or replace function public.leave_house(p_house_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  my text;
  heir uuid;
begin
  my := public.house_role_of(p_house_id, uid);
  if my is null then return jsonb_build_object('success', false, 'error', 'You are not in this house'); end if;
  if my = 'captain' then
    select user_id into heir from public.house_members
     where house_id = p_house_id and user_id <> uid
     order by (role = 'officer') desc, joined_at asc limit 1;
    if heir is null then
      delete from public.houses where id = p_house_id;   -- last member: the house closes
      return jsonb_build_object('success', true, 'closed', true);
    end if;
    update public.houses set captain_id = heir, updated_at = now() where id = p_house_id;
    update public.house_members set role = 'captain' where house_id = p_house_id and user_id = heir;
  end if;
  delete from public.house_members where house_id = p_house_id and user_id = uid;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.leave_house(uuid) to authenticated;

create or replace function public.kick_house_member(p_house_id uuid, p_user_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  my text := coalesce(public.house_role_of(p_house_id, uid), '');
  theirs text := public.house_role_of(p_house_id, p_user_id);
begin
  if theirs is null then return jsonb_build_object('success', false, 'error', 'Not a member'); end if;
  if p_user_id = uid then return jsonb_build_object('success', false, 'error', 'Use Leave instead'); end if;
  if theirs = 'captain' then return jsonb_build_object('success', false, 'error', 'The captain cannot be removed'); end if;
  if not (my = 'captain' or (my = 'officer' and theirs = 'member')) then
    return jsonb_build_object('success', false, 'error', 'You cannot remove this member');
  end if;
  delete from public.house_members where house_id = p_house_id and user_id = p_user_id;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.kick_house_member(uuid, uuid) to authenticated;

create or replace function public.set_house_role(p_house_id uuid, p_user_id uuid, p_role text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if public.house_role_of(p_house_id, uid) is distinct from 'captain' then
    return jsonb_build_object('success', false, 'error', 'Only the captain can do that');
  end if;
  if p_role not in ('officer', 'member') then
    return jsonb_build_object('success', false, 'error', 'Unknown role');
  end if;
  if coalesce(public.house_role_of(p_house_id, p_user_id), 'captain') = 'captain' then
    return jsonb_build_object('success', false, 'error', 'Cannot change that member');
  end if;
  update public.house_members set role = p_role where house_id = p_house_id and user_id = p_user_id;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.set_house_role(uuid, uuid, text) to authenticated;

create or replace function public.transfer_house_captain(p_house_id uuid, p_new_captain uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if public.house_role_of(p_house_id, uid) is distinct from 'captain' then
    return jsonb_build_object('success', false, 'error', 'Only the captain can do that');
  end if;
  if p_new_captain = uid or public.house_role_of(p_house_id, p_new_captain) is null then
    return jsonb_build_object('success', false, 'error', 'Pick another member of the house');
  end if;
  update public.house_members set role = 'officer' where house_id = p_house_id and user_id = uid;
  update public.house_members set role = 'captain' where house_id = p_house_id and user_id = p_new_captain;
  update public.houses set captain_id = p_new_captain, updated_at = now() where id = p_house_id;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.transfer_house_captain(uuid, uuid) to authenticated;

create or replace function public.update_house(p_house_id uuid, p_motto text, p_description text, p_color text, p_is_open boolean)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if public.house_role_of(p_house_id, uid) is distinct from 'captain' then
    return jsonb_build_object('success', false, 'error', 'Only the captain can do that');
  end if;
  update public.houses set
    motto = left(nullif(btrim(coalesce(p_motto, '')), ''), 80),
    description = left(nullif(btrim(coalesce(p_description, '')), ''), 400),
    banner_color = coalesce(nullif(p_color, ''), banner_color),
    is_open = coalesce(p_is_open, is_open),
    updated_at = now()
  where id = p_house_id;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.update_house(uuid, text, text, text, boolean) to authenticated;

-- A captain buys an emblem or banner for the house, or picks one it owns.
create or replace function public.purchase_house_item(p_house_id uuid, p_item_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  it public.cosmetic_items;
  r jsonb;
  bal numeric;
begin
  if public.house_role_of(p_house_id, uid) is distinct from 'captain' then
    return jsonb_build_object('success', false, 'error', 'Only the captain can do that');
  end if;
  select * into it from public.cosmetic_items where id = p_item_id;
  if not found or not it.is_active or it.scope <> 'house' then
    return jsonb_build_object('success', false, 'error', 'This item is not available');
  end if;
  if it.available_until is not null and it.available_until < now() then
    return jsonb_build_object('success', false, 'error', 'This item is no longer on sale');
  end if;
  if it.price > 0 and not exists (select 1 from public.house_inventory where house_id = p_house_id and item_id = p_item_id) then
    r := public.deduct_arena_stake(uid, it.price, 'HOUSEITEM_' || p_item_id::text || '_' || p_house_id::text);
    if coalesce((r ->> 'success')::boolean, false) is not true then
      return jsonb_build_object('success', false, 'error', coalesce(r ->> 'error', 'Not enough balance'));
    end if;
    begin
      insert into public.house_inventory (house_id, item_id, price_paid) values (p_house_id, p_item_id, it.price);
    exception when others then
      perform public.refund_arena_stake(uid, it.price, 'HOUSEITEM_REFUND_' || p_item_id::text || '_' || p_house_id::text);
      return jsonb_build_object('success', false, 'error', 'Could not complete the purchase, you were not charged');
    end;
  end if;
  if it.category = 'house_emblem' then
    update public.houses set emblem_item_id = p_item_id, updated_at = now() where id = p_house_id;
  elsif it.category = 'house_banner' then
    update public.houses set banner_item_id = p_item_id, updated_at = now() where id = p_house_id;
  else
    return jsonb_build_object('success', false, 'error', 'Unknown category');
  end if;
  select wallet_balance into bal from public.profiles where id = uid;
  return jsonb_build_object('success', true, 'balance', bal);
end;
$$;
grant execute on function public.purchase_house_item(uuid, uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Houses: reads
-- ---------------------------------------------------------------------------
create or replace function public.house_leaderboard(p_scope text default 'all')
returns table (
  house_id uuid, name text, banner_color text, motto text, is_open boolean,
  emblem text, banner jsonb, members integer, points integer, week_points integer, level integer, rank integer
)
language sql stable security definer set search_path = public as $$
  with base as (
    select h.id, h.name, h.banner_color, h.motto, h.is_open,
           e.value as emblem, b.asset as banner,
           (select count(*)::int from public.house_members hm where hm.house_id = h.id) as members,
           public.get_house_points(h.id) as points,
           public.house_week_points(h.id) as week_points
    from public.houses h
    left join public.cosmetic_items e on e.id = h.emblem_item_id
    left join public.cosmetic_items b on b.id = h.banner_item_id
  )
  select id, name, banner_color, motto, is_open, emblem, banner, members, points, week_points,
         public.house_level(points) as level,
         (rank() over (order by case when p_scope = 'week' then week_points else points end desc, name asc))::int as rank
  from base
  order by rank;
$$;
grant execute on function public.house_leaderboard(text) to authenticated;

create or replace function public.get_house_details(p_house_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  h public.houses;
  pts integer;
  lvl integer;
  my text;
  members jsonb;
  reqs jsonb := '[]'::jsonb;
  all_rank integer;
  wk_rank integer;
  pending_mine boolean;
  trophies jsonb;
begin
  select * into h from public.houses where id = p_house_id;
  if not found then return null; end if;
  pts := public.get_house_points(p_house_id);
  lvl := public.house_level(pts);
  my := public.house_role_of(p_house_id, uid);

  select jsonb_agg(m order by (m ->> 'sort')::int, (m ->> 'points')::int desc) into members from (
    select jsonb_build_object(
      'user_id', hm.user_id, 'role', hm.role, 'joined_at', hm.joined_at,
      'username', p.username, 'display_name', p.display_name, 'avatar_url', p.avatar_url,
      'points', coalesce((select sum(gs.score) from public.game_scores gs where gs.user_id = hm.user_id), 0)::int,
      'sort', case hm.role when 'captain' then 0 when 'officer' then 1 else 2 end
    ) as m
    from public.house_members hm
    join public.profiles p on p.id = hm.user_id
    where hm.house_id = p_house_id
  ) t;

  if my in ('captain', 'officer') then
    select coalesce(jsonb_agg(jsonb_build_object(
      'id', r.id, 'user_id', r.user_id, 'message', r.message, 'created_at', r.created_at,
      'username', p.username, 'display_name', p.display_name, 'avatar_url', p.avatar_url
    ) order by r.created_at), '[]'::jsonb) into reqs
    from public.house_join_requests r join public.profiles p on p.id = r.user_id
    where r.house_id = p_house_id and r.status = 'pending';
  end if;

  select x.rank into all_rank from public.house_leaderboard('all') x where x.house_id = p_house_id;
  select x.rank into wk_rank from public.house_leaderboard('week') x where x.house_id = p_house_id;
  pending_mine := exists (select 1 from public.house_join_requests where house_id = p_house_id and user_id = uid and status = 'pending');

  select coalesce(jsonb_agg(jsonb_build_object('week_start', w.week_start, 'rank', w.rank, 'points', w.points)
                            order by w.week_start desc), '[]'::jsonb) into trophies
  from public.house_weekly_results w where w.house_id = p_house_id and w.rank <= 3;

  return jsonb_build_object(
    'id', h.id, 'name', h.name, 'banner_color', h.banner_color, 'motto', h.motto, 'description', h.description,
    'is_open', h.is_open, 'captain_id', h.captain_id, 'created_at', h.created_at,
    'emblem', (select value from public.cosmetic_items where id = h.emblem_item_id),
    'emblem_item_id', h.emblem_item_id, 'banner_item_id', h.banner_item_id,
    'banner', (select asset from public.cosmetic_items where id = h.banner_item_id),
    'points', pts, 'week_points', public.house_week_points(p_house_id), 'level', lvl,
    'next_level_points', (lvl * lvl * 1000),
    'member_limit', public.house_member_limit(lvl),
    'member_count', coalesce(jsonb_array_length(members), 0),
    'rank', all_rank, 'week_rank', wk_rank,
    'my_role', my, 'my_request_pending', pending_mine,
    'members', coalesce(members, '[]'::jsonb), 'requests', reqs, 'trophies', trophies,
    'owned_item_ids', coalesce((select jsonb_agg(item_id) from public.house_inventory where house_id = p_house_id), '[]'::jsonb)
  );
end;
$$;
grant execute on function public.get_house_details(uuid) to authenticated;

-- The house a player belongs to, for profiles and leaderboards.
create or replace function public.get_user_house(p_user_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'house_id', h.id, 'name', h.name, 'banner_color', h.banner_color, 'role', hm.role,
    'emblem', (select value from public.cosmetic_items where id = h.emblem_item_id))
  from public.house_members hm join public.houses h on h.id = hm.house_id
  where hm.user_id = p_user_id;
$$;
grant execute on function public.get_user_house(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Weekly house wars
-- ---------------------------------------------------------------------------
-- Run after each week ends (scheduled below). Records the top three houses of
-- the week that had at least three members and some points, and gives the
-- winning house's members the House Champion badge. Safe to run twice.
create or replace function public.award_house_week()
returns integer language plpgsql security definer set search_path = public as $$
declare
  wk date := (date_trunc('week', now()) - interval '7 days')::date;
  wk_end timestamptz := date_trunc('week', now());
  badge_id uuid;
  winner uuid;
  n integer := 0;
begin
  if exists (select 1 from public.house_weekly_results where week_start = wk) then return 0; end if;

  insert into public.house_weekly_results (week_start, house_id, rank, points)
  select wk, x.house_id, x.rk, x.pts from (
    select h.id as house_id,
           coalesce(sum(gs.score), 0)::int as pts,
           (rank() over (order by coalesce(sum(gs.score), 0) desc))::int as rk
    from public.houses h
    join public.house_members hm on hm.house_id = h.id
    left join public.game_scores gs on gs.user_id = hm.user_id
         and gs.created_at >= wk::timestamptz and gs.created_at < wk_end
    group by h.id
    having count(distinct hm.user_id) >= 3 and coalesce(sum(gs.score), 0) > 0
  ) x
  where x.rk <= 3
  on conflict do nothing;
  get diagnostics n = row_count;

  select house_id into winner from public.house_weekly_results where week_start = wk and rank = 1 limit 1;
  select id into badge_id from public.cosmetic_items where category = 'badge' and name = 'House Champion';
  if winner is not null and badge_id is not null then
    insert into public.user_cosmetic_inventory (user_id, item_id, source)
    select hm.user_id, badge_id, 'house_win' from public.house_members hm where hm.house_id = winner
    on conflict do nothing;
  end if;
  return n;
end;
$$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('award-house-week', '10 0 * * 1', 'select public.award_house_week()');
  end if;
exception when others then
  raise notice 'could not schedule award_house_week; run select public.award_house_week(); every Monday instead';
end $$;

-- ---------------------------------------------------------------------------
-- 8. Starter catalogue. Prices are in naira and can be changed any time by
--    editing cosmetic_items (price, is_active, available_until).
-- ---------------------------------------------------------------------------
insert into public.cosmetic_items (category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order)
select * from (values
  -- hero outfits: how your character looks in Odyssey and the Realms
  ('hero_outfit', 'Explorer',      '', '{"shirt":"#FF6A00","pants":"#2A3A63","skin":"#F2B785","hair":"#2B1B12"}'::jsonb, 0,    'common',    false, 'user', 'The classic look.', 0),
  ('hero_outfit', 'Frost Ranger',  '', '{"shirt":"#4FC3F7","pants":"#263859","skin":"#F2B785","hair":"#ECEFF1"}'::jsonb, 300,  'rare',      false, 'user', 'Icy blues for cold caves.', 10),
  ('hero_outfit', 'Jungle Scout',  '', '{"shirt":"#66BB6A","pants":"#4E342E","skin":"#C68642","hair":"#1B1B1B"}'::jsonb, 300,  'rare',      false, 'user', 'Made for the wild.', 11),
  ('hero_outfit', 'Ember Runner',  '', '{"shirt":"#E53935","pants":"#212121","skin":"#8D5524","hair":"#3E2723"}'::jsonb, 300,  'rare',      false, 'user', 'Runs hot.', 12),
  ('hero_outfit', 'Shadow Ninja',  '', '{"shirt":"#212121","pants":"#101010","skin":"#C68642","hair":"#000000"}'::jsonb, 800,  'epic',      false, 'user', 'Quiet and quick.', 20),
  ('hero_outfit', 'Royal Guard',   '', '{"shirt":"#7B1FA2","pants":"#FFD54F","skin":"#8D5524","hair":"#212121"}'::jsonb, 800,  'epic',      false, 'user', 'Purple and gold.', 21),
  ('hero_outfit', 'Solar Knight',  '', '{"shirt":"#FFC107","pants":"#FF6F00","skin":"#F2B785","hair":"#FFF8E1"}'::jsonb, 1500, 'legendary', false, 'user', 'Shines in every realm.', 30),
  ('hero_outfit', 'Golden Scholar','', '{"shirt":"#FFD700","pants":"#1A237E","skin":"#F2B785","hair":"#2B1B12"}'::jsonb, 0,    'epic',      true,  'user', 'Included with premium.', 25),
  -- trails: a glow that follows your hero
  ('trail', 'None',      '', '{"kind":"none"}'::jsonb,                                  0,    'common',    false, 'user', 'No trail.', 0),
  ('trail', 'Sparkle',   '', '{"kind":"sparkle","color":"#FFF176"}'::jsonb,             200,  'common',    false, 'user', 'A few golden sparks.', 10),
  ('trail', 'Flame',     '', '{"kind":"flame","color":"#FF6D00"}'::jsonb,               400,  'rare',      false, 'user', 'Leave fire behind you.', 11),
  ('trail', 'Stardust',  '', '{"kind":"stars","color":"#B388FF"}'::jsonb,               600,  'epic',      false, 'user', 'Purple stardust.', 20),
  ('trail', 'Rainbow',   '', '{"kind":"rainbow","color":"#FF4081"}'::jsonb,             1000, 'legendary', false, 'user', 'Every colour at once.', 30),
  -- profile banners
  ('profile_banner', 'None',     '', '{}'::jsonb,                                                    0,    'common',    false, 'user', 'Plain profile.', 0),
  ('profile_banner', 'Sunset',   '', '{"from":"#FF6A00","to":"#E91E63"}'::jsonb,                     200,  'common',    false, 'user', 'Orange into pink.', 10),
  ('profile_banner', 'Aurora',   '', '{"from":"#00E5FF","to":"#7C4DFF"}'::jsonb,                     500,  'rare',      false, 'user', 'Northern lights.', 11),
  ('profile_banner', 'Cosmic',   '', '{"from":"#1A237E","to":"#AA00FF"}'::jsonb,                     800,  'epic',      false, 'user', 'Deep space.', 20),
  ('profile_banner', 'Gold Lux', '', '{"from":"#FFD700","to":"#FF8F00"}'::jsonb,                     1500, 'legendary', false, 'user', 'Pure gold.', 30),
  -- more frames, name colours and badges
  ('avatar_frame', 'Neon Ring',    'neon',   '{"colors":["#00E5FF","#7C4DFF"]}'::jsonb,              300,  'rare',      false, 'user', 'A glowing ring.', 10),
  ('avatar_frame', 'Laurel',       'laurel', '{"colors":["#FFD54F","#8BC34A"]}'::jsonb,              600,  'epic',      false, 'user', 'For winners.', 20),
  ('avatar_frame', 'Dragon Scale', 'dragon', '{"colors":["#D32F2F","#FF6F00"]}'::jsonb,              1200, 'legendary', false, 'user', 'Fierce.', 30),
  ('name_color',   'Crimson',      '#E53935', '{}'::jsonb,                                           150,  'common',    false, 'user', 'Bold red name.', 10),
  ('name_color',   'Emerald',      '#00C853', '{}'::jsonb,                                           150,  'common',    false, 'user', 'Fresh green name.', 11),
  ('name_color',   'Rose',         '#FF4081', '{}'::jsonb,                                           150,  'common',    false, 'user', 'Bright pink name.', 12),
  ('badge', 'Lightning',  'bolt_rounded',                    '{}'::jsonb, 250, 'common', false, 'user', 'Quick thinker.', 10),
  ('badge', 'Blaze',      'local_fire_department_rounded',   '{}'::jsonb, 350, 'rare',   false, 'user', 'On fire.', 11),
  ('badge', 'Diamond',    'diamond_rounded',                 '{}'::jsonb, 500, 'epic',   false, 'user', 'Rare and bright.', 20),
  ('badge', 'Rocket',     'rocket_launch_rounded',           '{}'::jsonb, 400, 'rare',   false, 'user', 'Going places.', 12),
  ('badge', 'Brain',      'psychology_rounded',              '{}'::jsonb, 450, 'rare',   false, 'user', 'Big brain.', 13),
  ('badge', 'House Champion', 'military_tech_rounded',       '{}'::jsonb, 0,   'legendary', false, 'user', 'Won the weekly house war. Cannot be bought.', 99),
  -- house emblems and banners (bought by the captain)
  ('house_emblem', 'Shield',  'shield_rounded',               '{}'::jsonb, 0,    'common',    false, 'house', 'The classic shield.', 0),
  ('house_emblem', 'Bolt',    'bolt_rounded',                 '{}'::jsonb, 500,  'rare',      false, 'house', 'Fast and sharp.', 10),
  ('house_emblem', 'Paw',     'pets_rounded',                 '{}'::jsonb, 500,  'rare',      false, 'house', 'The pack.', 11),
  ('house_emblem', 'Flame',   'local_fire_department_rounded','{}'::jsonb, 500,  'rare',      false, 'house', 'Burning bright.', 12),
  ('house_emblem', 'Castle',  'castle_rounded',               '{}'::jsonb, 800,  'epic',      false, 'house', 'Hold the fort.', 20),
  ('house_emblem', 'Rocket',  'rocket_launch_rounded',        '{}'::jsonb, 800,  'epic',      false, 'house', 'Aim high.', 21),
  ('house_emblem', 'Diamond', 'diamond_rounded',              '{}'::jsonb, 1000, 'epic',      false, 'house', 'Rare and valuable.', 22),
  ('house_emblem', 'Trophy',  'emoji_events_rounded',         '{}'::jsonb, 1200, 'legendary', false, 'house', 'Champions only.', 30),
  ('house_banner', 'Classic',    '', '{"from":"#37474F","to":"#263238"}'::jsonb, 0,    'common',    false, 'house', 'Plain and proud.', 0),
  ('house_banner', 'Twilight',   '', '{"from":"#6A1B9A","to":"#283593"}'::jsonb, 700,  'rare',      false, 'house', 'Purple dusk.', 10),
  ('house_banner', 'Inferno',    '', '{"from":"#D84315","to":"#FFB300"}'::jsonb, 900,  'epic',      false, 'house', 'Red and gold flame.', 20),
  ('house_banner', 'Ocean',      '', '{"from":"#006064","to":"#29B6F6"}'::jsonb, 900,  'epic',      false, 'house', 'Deep blue sea.', 21),
  ('house_banner', 'Royal Gold', '', '{"from":"#FFD700","to":"#B8860B"}'::jsonb, 2000, 'legendary', false, 'house', 'The finest banner.', 30)
) as seed(category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order)
where not exists (
  select 1 from public.cosmetic_items c where c.category = seed.category and c.name = seed.name
);

-- Existing premium frames/colours get a rarity so the shop can sort them.
update public.cosmetic_items set rarity = 'epic' where requires_premium and rarity = 'common';

notify pgrst, 'reload schema';
