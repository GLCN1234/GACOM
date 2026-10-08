-- Identity layer: rarity tiers, shop rotation, bundles, collection, sets,
-- trophies, House goals, and the competition Missions system.
--
-- Everything here is data driven. Items, deals, bundles, milestones, goals,
-- missions and season rewards are rows that admins can edit; no app release
-- is needed to change them. Rarity values are:
--   common | rare | epic | legendary | mythic   (mythic is never sold)
-- cosmetic_items.source says how an item is obtained:
--   shop     bought with wallet money (price 0 = free for everyone)
--   premium  included with a premium membership
--   earned   only through missions, milestones, sets or admin grants
--   licence  granted by an admin (for example a school crest)

-- ---------------------------------------------------------------------------
-- 1. Catalogue columns
-- ---------------------------------------------------------------------------
alter table public.cosmetic_items add column if not exists source text not null default 'shop';
alter table public.cosmetic_items add column if not exists set_key text;
alter table public.cosmetic_items add column if not exists earn_hint text;
do $$
begin
  alter table public.cosmetic_items add constraint cosmetic_items_source_chk
    check (source in ('shop', 'premium', 'earned', 'licence'));
exception when duplicate_object then null;
end $$;

update public.cosmetic_items set source = 'premium' where requires_premium and source = 'shop';
update public.cosmetic_items set source = 'earned', earn_hint = 'Win the weekly House war'
  where category = 'badge' and name = 'House Champion';

alter table public.user_cosmetic_inventory add column if not exists source_ref text;
alter table public.user_cosmetics add column if not exists equipped_title uuid references public.cosmetic_items(id);

create or replace function public.identity_is_admin()
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.profiles p where p.id = auth.uid() and p.role::text in ('admin', 'super_admin'));
$$;

create or replace function public.identity_notify(p_user uuid, p_title text, p_body text, p_data jsonb default '{}'::jsonb)
returns void language plpgsql security definer set search_path = public as $$
begin
  insert into public.notifications (recipient_id, type, title, body, data)
  values (p_user, 'system', p_title, p_body, p_data);
exception when others then
  null; -- a failed notification must never block a reward
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. Ownership, price, grant, revoke
-- ---------------------------------------------------------------------------
create or replace function public.cosmetic_is_owned(p_user uuid, p_item uuid)
returns boolean language plpgsql stable security definer set search_path = public as $$
declare it public.cosmetic_items;
begin
  select * into it from public.cosmetic_items where id = p_item;
  if not found then return false; end if;
  -- free for everyone only when it is a plain free shop item
  if it.source = 'shop' and it.price <= 0 and not it.requires_premium then return true; end if;
  if exists (select 1 from public.user_cosmetic_inventory i where i.user_id = p_user and i.item_id = p_item) then return true; end if;
  if (it.requires_premium or it.source = 'premium') and public.cosmetic_is_pro(p_user) then return true; end if;
  return false;
end;
$$;

-- Shop rotation tables (defined here because the price function reads them)
create table if not exists public.shop_slots (
  id uuid primary key default gen_random_uuid(),
  slot text not null check (slot in ('featured', 'daily')),
  item_id uuid not null references public.cosmetic_items(id) on delete cascade,
  discount_percent integer not null default 0 check (discount_percent between 0 and 90),
  starts_at timestamptz not null default now(),
  ends_at timestamptz not null,
  sort_order integer not null default 0,
  pinned boolean not null default false, -- pinned slots are never replaced by the automatic rotation
  created_at timestamptz not null default now()
);
create index if not exists shop_slots_active_idx on public.shop_slots (slot, ends_at);
alter table public.shop_slots enable row level security;
drop policy if exists "anyone views shop slots" on public.shop_slots;
create policy "anyone views shop slots" on public.shop_slots for select using (true);
drop policy if exists "admins manage shop slots" on public.shop_slots;
create policy "admins manage shop slots" on public.shop_slots for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());

create or replace function public.cosmetic_effective_price(p_item uuid)
returns integer language sql stable security definer set search_path = public as $$
  select case
    when c.price <= 0 then 0
    else ceil(c.price * (100 - coalesce((
      select max(s.discount_percent) from public.shop_slots s
      where s.item_id = c.id and s.starts_at <= now() and s.ends_at > now()
    ), 0)) / 100.0)::int
  end
  from public.cosmetic_items c where c.id = p_item;
$$;

create or replace function public.grant_cosmetic(p_user uuid, p_item uuid, p_source text, p_ref text default null)
returns boolean language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  insert into public.user_cosmetic_inventory (user_id, item_id, source, source_ref, price_paid)
  values (p_user, p_item, p_source, p_ref, 0)
  on conflict (user_id, item_id) do nothing;
  get diagnostics n = row_count;
  return n > 0;
end;
$$;

create or replace function public.revoke_cosmetic(p_user uuid, p_item uuid)
returns void language plpgsql security definer set search_path = public as $$
begin
  delete from public.user_cosmetic_inventory where user_id = p_user and item_id = p_item;
  update public.user_cosmetics set
    equipped_name_color    = case when equipped_name_color    = p_item then null else equipped_name_color end,
    equipped_badge         = case when equipped_badge         = p_item then null else equipped_badge end,
    equipped_avatar_frame  = case when equipped_avatar_frame  = p_item then null else equipped_avatar_frame end,
    equipped_hero_outfit   = case when equipped_hero_outfit   = p_item then null else equipped_hero_outfit end,
    equipped_trail         = case when equipped_trail         = p_item then null else equipped_trail end,
    equipped_profile_banner= case when equipped_profile_banner= p_item then null else equipped_profile_banner end,
    equipped_title         = case when equipped_title         = p_item then null else equipped_title end,
    updated_at = now()
  where user_id = p_user;
end;
$$;

-- ---------------------------------------------------------------------------
-- 3. Sets, bundles, collection milestones
-- ---------------------------------------------------------------------------
create table if not exists public.cosmetic_sets (
  key text primary key,
  name text not null,
  bonus_item_id uuid references public.cosmetic_items(id),
  description text
);
alter table public.cosmetic_sets enable row level security;
drop policy if exists "anyone views sets" on public.cosmetic_sets;
create policy "anyone views sets" on public.cosmetic_sets for select using (true);
drop policy if exists "admins manage sets" on public.cosmetic_sets;
create policy "admins manage sets" on public.cosmetic_sets for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());

create table if not exists public.cosmetic_bundles (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  description text,
  discount_percent integer not null default 25 check (discount_percent between 0 and 90),
  is_active boolean not null default true,
  available_until timestamptz,
  sort_order integer not null default 0
);
create table if not exists public.cosmetic_bundle_items (
  bundle_id uuid not null references public.cosmetic_bundles(id) on delete cascade,
  item_id uuid not null references public.cosmetic_items(id) on delete cascade,
  primary key (bundle_id, item_id)
);
alter table public.cosmetic_bundles enable row level security;
alter table public.cosmetic_bundle_items enable row level security;
drop policy if exists "anyone views bundles" on public.cosmetic_bundles;
create policy "anyone views bundles" on public.cosmetic_bundles for select using (true);
drop policy if exists "anyone views bundle items" on public.cosmetic_bundle_items;
create policy "anyone views bundle items" on public.cosmetic_bundle_items for select using (true);
drop policy if exists "admins manage bundles" on public.cosmetic_bundles;
create policy "admins manage bundles" on public.cosmetic_bundles for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());
drop policy if exists "admins manage bundle items" on public.cosmetic_bundle_items;
create policy "admins manage bundle items" on public.cosmetic_bundle_items for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());

create table if not exists public.collection_milestones (
  percent integer primary key check (percent between 1 and 100),
  item_id uuid not null references public.cosmetic_items(id),
  label text not null
);
alter table public.collection_milestones enable row level security;
drop policy if exists "anyone views milestones" on public.collection_milestones;
create policy "anyone views milestones" on public.collection_milestones for select using (true);
drop policy if exists "admins manage milestones" on public.collection_milestones;
create policy "admins manage milestones" on public.collection_milestones for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());

-- One item as json, with ownership and today's price, for the app.
create or replace function public.cosmetic_json(it public.cosmetic_items, p_user uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'id', it.id, 'category', it.category, 'name', it.name, 'value', it.value, 'asset', it.asset,
    'rarity', it.rarity, 'price', it.price, 'sale_price', public.cosmetic_effective_price(it.id),
    'description', it.description, 'requires_premium', it.requires_premium, 'source', it.source,
    'set_key', it.set_key, 'earn_hint', it.earn_hint, 'available_until', it.available_until,
    'scope', it.scope, 'owned', public.cosmetic_is_owned(p_user, it.id)
  );
$$;

-- Own every piece of a set and the bonus piece is added automatically.
create or replace function public.grant_set_bonuses(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare s record;
begin
  for s in select * from public.cosmetic_sets where bonus_item_id is not null loop
    if not exists (
      select 1 from public.cosmetic_items c
      where c.set_key = s.key and c.id <> s.bonus_item_id and not public.cosmetic_is_owned(p_user, c.id)
    ) and exists (select 1 from public.cosmetic_items c where c.set_key = s.key and c.id <> s.bonus_item_id) then
      if public.grant_cosmetic(p_user, s.bonus_item_id, 'set', s.key) then
        perform public.identity_notify(p_user, 'Set complete', s.name || ' is complete. Your bonus item is in your locker.',
          jsonb_build_object('kind', 'set', 'set', s.key));
      end if;
    end if;
  end loop;
end;
$$;

create or replace function public.my_sets()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'key', s.key, 'name', s.name, 'description', s.description,
      'bonus', (select public.cosmetic_json(b, uid) from public.cosmetic_items b where b.id = s.bonus_item_id),
      'items', (select jsonb_agg(jsonb_build_object('id', c.id, 'name', c.name, 'category', c.category,
                  'rarity', c.rarity, 'owned', public.cosmetic_is_owned(uid, c.id)) order by c.sort_order)
                from public.cosmetic_items c where c.set_key = s.key and c.id is distinct from s.bonus_item_id)
    ) order by s.name)
    from public.cosmetic_sets s
  ), '[]'::jsonb);
end;
$$;
grant execute on function public.my_sets() to authenticated;

create or replace function public.collection_stats()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  total integer;
  owned integer;
  pct integer;
begin
  if uid is null then return null; end if;
  select count(*), count(*) filter (where public.cosmetic_is_owned(uid, c.id))
    into total, owned
  from public.cosmetic_items c
  where c.scope = 'user' and c.is_active and c.name <> 'None'
    and not (c.source = 'shop' and c.price <= 0 and not c.requires_premium)
    and (c.available_until is null or c.available_until > now()
         or exists (select 1 from public.user_cosmetic_inventory i where i.user_id = uid and i.item_id = c.id));
  pct := case when total = 0 then 0 else floor(owned * 100.0 / total)::int end;
  return jsonb_build_object(
    'owned', owned, 'total', total, 'percent', pct,
    'milestones', coalesce((
      select jsonb_agg(jsonb_build_object(
        'percent', m.percent, 'label', m.label,
        'item', public.cosmetic_json(c, uid),
        'reached', pct >= m.percent,
        'claimed', exists (select 1 from public.user_cosmetic_inventory i where i.user_id = uid and i.item_id = m.item_id)
      ) order by m.percent)
      from public.collection_milestones m join public.cosmetic_items c on c.id = m.item_id
    ), '[]'::jsonb)
  );
end;
$$;
grant execute on function public.collection_stats() to authenticated;

create or replace function public.claim_collection_milestone(p_percent integer)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  stats jsonb;
  m public.collection_milestones;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into m from public.collection_milestones where percent = p_percent;
  if not found then return jsonb_build_object('success', false, 'error', 'Unknown milestone'); end if;
  stats := public.collection_stats();
  if (stats ->> 'percent')::int < m.percent then
    return jsonb_build_object('success', false, 'error', 'Collect ' || m.percent || '% of the catalogue first');
  end if;
  if not public.grant_cosmetic(uid, m.item_id, 'milestone', m.percent::text) then
    return jsonb_build_object('success', false, 'error', 'Already claimed');
  end if;
  perform public.evaluate_trophies(uid);
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.claim_collection_milestone(integer) to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Buying: single items (with today's price) and bundles
-- ---------------------------------------------------------------------------
create or replace function public.purchase_cosmetic(p_item_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  it public.cosmetic_items;
  r jsonb;
  bal numeric;
  amount integer;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into it from public.cosmetic_items where id = p_item_id;
  if not found or not it.is_active or it.scope <> 'user' then
    return jsonb_build_object('success', false, 'error', 'This item is not available');
  end if;
  if it.source = 'earned' then
    return jsonb_build_object('success', false, 'error', coalesce(it.earn_hint, 'This item is earned, not sold'));
  end if;
  if it.source = 'licence' then
    return jsonb_build_object('success', false, 'error', 'This item is issued by GACOM');
  end if;
  if it.available_until is not null and it.available_until < now() then
    return jsonb_build_object('success', false, 'error', 'This item is no longer on sale');
  end if;
  if it.price <= 0 then
    if it.requires_premium or it.source = 'premium' then
      return jsonb_build_object('success', false, 'error', 'Included with a Premium membership');
    end if;
    return jsonb_build_object('success', false, 'error', 'This item is not for sale');
  end if;
  if exists (select 1 from public.user_cosmetic_inventory where user_id = uid and item_id = p_item_id) then
    return jsonb_build_object('success', false, 'error', 'You already own this');
  end if;

  amount := public.cosmetic_effective_price(p_item_id);
  r := public.deduct_arena_stake(uid, amount, 'COSMETIC_' || p_item_id::text || '_' || uid::text);
  if coalesce((r ->> 'success')::boolean, false) is not true then
    return jsonb_build_object('success', false, 'error', coalesce(r ->> 'error', 'Not enough balance'));
  end if;

  begin
    insert into public.user_cosmetic_inventory (user_id, item_id, source, price_paid)
    values (uid, p_item_id, 'purchase', amount);
  exception when others then
    perform public.refund_arena_stake(uid, amount, 'COSMETIC_REFUND_' || p_item_id::text || '_' || uid::text);
    return jsonb_build_object('success', false, 'error', 'Could not complete the purchase, you were not charged');
  end;

  perform public.grant_set_bonuses(uid);
  select wallet_balance into bal from public.profiles where id = uid;
  return jsonb_build_object('success', true, 'balance', bal, 'paid', amount);
end;
$$;
grant execute on function public.purchase_cosmetic(uuid) to authenticated;

create or replace function public.purchase_bundle(p_bundle_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  b public.cosmetic_bundles;
  full_price integer;
  amount integer;
  n integer;
  r jsonb;
  bal numeric;
  ref text;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into b from public.cosmetic_bundles where id = p_bundle_id;
  if not found or not b.is_active or (b.available_until is not null and b.available_until < now()) then
    return jsonb_build_object('success', false, 'error', 'This bundle is not available');
  end if;

  select coalesce(sum(c.price), 0), count(*) into full_price, n
  from public.cosmetic_bundle_items bi join public.cosmetic_items c on c.id = bi.item_id
  where bi.bundle_id = p_bundle_id and c.is_active and c.source = 'shop' and c.price > 0 and not c.requires_premium
    and not exists (select 1 from public.user_cosmetic_inventory i where i.user_id = uid and i.item_id = c.id);
  if n = 0 then return jsonb_build_object('success', false, 'error', 'You already own everything in this bundle'); end if;

  amount := ceil(full_price * (100 - b.discount_percent) / 100.0)::int;
  ref := 'BUNDLE_' || p_bundle_id::text || '_' || uid::text || '_' || extract(epoch from clock_timestamp())::bigint::text;
  r := public.deduct_arena_stake(uid, amount, ref);
  if coalesce((r ->> 'success')::boolean, false) is not true then
    return jsonb_build_object('success', false, 'error', coalesce(r ->> 'error', 'Not enough balance'));
  end if;

  begin
    insert into public.user_cosmetic_inventory (user_id, item_id, source, source_ref, price_paid)
    select uid, c.id, 'purchase', 'bundle:' || p_bundle_id::text,
           ceil(c.price * (100 - b.discount_percent) / 100.0)::int
    from public.cosmetic_bundle_items bi join public.cosmetic_items c on c.id = bi.item_id
    where bi.bundle_id = p_bundle_id and c.is_active and c.source = 'shop' and c.price > 0 and not c.requires_premium
    on conflict (user_id, item_id) do nothing;
  exception when others then
    perform public.refund_arena_stake(uid, amount, ref || '_REFUND');
    return jsonb_build_object('success', false, 'error', 'Could not complete the purchase, you were not charged');
  end;

  perform public.grant_set_bonuses(uid);
  select wallet_balance into bal from public.profiles where id = uid;
  return jsonb_build_object('success', true, 'balance', bal, 'paid', amount, 'items', n);
end;
$$;
grant execute on function public.purchase_bundle(uuid) to authenticated;

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
      return jsonb_build_object('success', false, 'error',
        case when it.requires_premium or it.source = 'premium' then 'Premium members only'
             when it.source = 'earned' then coalesce(it.earn_hint, 'Earn this item first')
             else 'You do not own this yet' end);
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
    when 'title' then 'equipped_title'
    else null end;
  if col is null then return jsonb_build_object('success', false, 'error', 'Unknown category'); end if;
  insert into public.user_cosmetics (user_id) values (uid) on conflict (user_id) do nothing;
  execute format('update public.user_cosmetics set %I = $1, updated_at = now() where user_id = $2', col) using p_item_id, uid;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.equip_cosmetic(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Shop rotation: a featured item and three daily deals at midnight Lagos
-- ---------------------------------------------------------------------------
create or replace function public.rotate_daily_deals()
returns integer language plpgsql security definer set search_path = public as $$
declare
  pinned_active integer;
  ends timestamptz := (((now() at time zone 'Africa/Lagos')::date + 1)::timestamp at time zone 'Africa/Lagos');
  n integer;
begin
  update public.shop_slots set ends_at = now() where slot = 'daily' and not pinned and ends_at > now();
  select count(*) into pinned_active from public.shop_slots
    where slot = 'daily' and pinned and starts_at <= now() and ends_at > now();
  insert into public.shop_slots (slot, item_id, discount_percent, starts_at, ends_at, sort_order)
  select 'daily', c.id, 30, now(), ends, row_number() over ()
  from (
    select id from public.cosmetic_items
    where scope = 'user' and is_active and source = 'shop' and price >= 150 and not requires_premium
      and rarity in ('common', 'rare', 'epic') and name <> 'None'
      and (available_until is null or available_until > now())
      and category in ('hero_outfit', 'avatar_frame', 'profile_banner', 'trail', 'title', 'badge')
    order by random() limit greatest(0, 3 - pinned_active)
  ) c;
  get diagnostics n = row_count;
  return n;
end;
$$;

create or replace function public.rotate_featured()
returns integer language plpgsql security definer set search_path = public as $$
declare n integer;
begin
  if exists (select 1 from public.shop_slots where slot = 'featured' and starts_at <= now() and ends_at > now()) then
    return 0;
  end if;
  insert into public.shop_slots (slot, item_id, discount_percent, starts_at, ends_at)
  select 'featured', id, 0, now(), now() + interval '48 hours'
  from public.cosmetic_items
  where scope = 'user' and is_active and source = 'shop' and price > 0 and not requires_premium
    and rarity in ('epic', 'legendary') and (available_until is null or available_until > now())
  order by random() limit 1;
  get diagnostics n = row_count;
  return n;
end;
$$;

create or replace function public.rotate_shop()
returns integer language plpgsql security definer set search_path = public as $$
begin
  perform pg_advisory_xact_lock(884201);
  return public.rotate_daily_deals() + public.rotate_featured();
end;
$$;

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('rotate-shop', '0 23 * * *', 'select public.rotate_shop()'); -- midnight in Lagos
  end if;
exception when others then
  raise notice 'could not schedule rotate_shop; the shop also refreshes itself when opened';
end $$;

create or replace function public.get_shop_state()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  feat jsonb;
  deals jsonb;
  resets timestamptz;
  bundles jsonb;
  earn jsonb;
begin
  if uid is null then return null; end if;
  perform pg_advisory_xact_lock(884201);
  if not exists (select 1 from public.shop_slots where slot = 'daily' and starts_at <= now() and ends_at > now()) then
    perform public.rotate_daily_deals();
  end if;
  perform public.rotate_featured();

  select public.cosmetic_json(c, uid) || jsonb_build_object('discount', s.discount_percent, 'ends_at', s.ends_at)
    into feat
  from public.shop_slots s join public.cosmetic_items c on c.id = s.item_id
  where s.slot = 'featured' and s.starts_at <= now() and s.ends_at > now() and c.is_active
  order by s.sort_order, s.ends_at desc limit 1;

  select coalesce(jsonb_agg(public.cosmetic_json(c, uid) || jsonb_build_object('discount', s.discount_percent, 'ends_at', s.ends_at)
           order by s.sort_order), '[]'::jsonb), max(s.ends_at)
    into deals, resets
  from public.shop_slots s join public.cosmetic_items c on c.id = s.item_id
  where s.slot = 'daily' and s.starts_at <= now() and s.ends_at > now() and c.is_active;

  select coalesce(jsonb_agg(x order by (x ->> 'sort')::int), '[]'::jsonb) into bundles from (
    select jsonb_build_object(
      'id', b.id, 'name', b.name, 'description', b.description, 'discount_percent', b.discount_percent,
      'sort', b.sort_order, 'available_until', b.available_until,
      'items', (select jsonb_agg(public.cosmetic_json(c, uid)) from public.cosmetic_bundle_items bi
                join public.cosmetic_items c on c.id = bi.item_id where bi.bundle_id = b.id),
      'full_price', (select coalesce(sum(c.price), 0) from public.cosmetic_bundle_items bi
                     join public.cosmetic_items c on c.id = bi.item_id
                     where bi.bundle_id = b.id and c.source = 'shop' and c.price > 0
                       and not exists (select 1 from public.user_cosmetic_inventory i where i.user_id = uid and i.item_id = c.id)),
      'price', (select ceil(coalesce(sum(c.price), 0) * (100 - b.discount_percent) / 100.0)::int
                from public.cosmetic_bundle_items bi join public.cosmetic_items c on c.id = bi.item_id
                where bi.bundle_id = b.id and c.source = 'shop' and c.price > 0
                  and not exists (select 1 from public.user_cosmetic_inventory i where i.user_id = uid and i.item_id = c.id)),
      'all_owned', not exists (select 1 from public.cosmetic_bundle_items bi join public.cosmetic_items c on c.id = bi.item_id
                     where bi.bundle_id = b.id and c.source = 'shop' and c.price > 0
                       and not exists (select 1 from public.user_cosmetic_inventory i where i.user_id = uid and i.item_id = c.id))
    ) as x
    from public.cosmetic_bundles b
    where b.is_active and (b.available_until is null or b.available_until > now())
  ) t;

  select coalesce(jsonb_agg(public.cosmetic_json(c, uid) order by array_position(array['common','rare','epic','legendary','mythic'], c.rarity) desc, c.sort_order), '[]'::jsonb) into earn
  from public.cosmetic_items c
  where c.is_active and c.scope = 'user' and c.source = 'earned' and c.earn_hint is not null;

  return jsonb_build_object('featured', feat, 'deals', deals, 'deals_reset_at', resets, 'bundles', bundles, 'earn', earn);
end;
$$;
grant execute on function public.get_shop_state() to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Trophies
-- ---------------------------------------------------------------------------
create table if not exists public.trophy_defs (
  key text primary key,
  name text not null,
  description text not null,
  icon text not null default 'emoji_events_rounded',
  rarity text not null default 'rare',
  sort_order integer not null default 0
);
create table if not exists public.user_trophies (
  user_id uuid not null references auth.users(id) on delete cascade,
  trophy_key text not null references public.trophy_defs(key) on delete cascade,
  earned_at timestamptz not null default now(),
  primary key (user_id, trophy_key)
);
alter table public.trophy_defs enable row level security;
alter table public.user_trophies enable row level security;
drop policy if exists "anyone views trophy defs" on public.trophy_defs;
create policy "anyone views trophy defs" on public.trophy_defs for select using (true);
drop policy if exists "admins manage trophy defs" on public.trophy_defs;
create policy "admins manage trophy defs" on public.trophy_defs for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());
drop policy if exists "anyone views trophies" on public.user_trophies;
create policy "anyone views trophies" on public.user_trophies for select using (true);

create or replace function public.grant_trophy(p_user uuid, p_key text)
returns boolean language plpgsql security definer set search_path = public as $$
declare n integer; nm text;
begin
  if not exists (select 1 from public.trophy_defs where key = p_key) then return false; end if;
  insert into public.user_trophies (user_id, trophy_key) values (p_user, p_key) on conflict do nothing;
  get diagnostics n = row_count;
  if n > 0 then
    select name into nm from public.trophy_defs where key = p_key;
    perform public.identity_notify(p_user, 'Trophy earned', nm, jsonb_build_object('kind', 'trophy', 'trophy', p_key));
  end if;
  return n > 0;
end;
$$;

create or replace function public.evaluate_trophies(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare wins integer; streak integer; pct integer;
begin
  select count(*) into wins from public.duel_matches where winner_id = p_user and status = 'completed';
  if wins >= 1 then perform public.grant_trophy(p_user, 'first_win'); end if;
  if wins >= 10 then perform public.grant_trophy(p_user, 'wins_10'); end if;
  if wins >= 50 then perform public.grant_trophy(p_user, 'wins_50'); end if;
  begin
    streak := public.get_current_streak(p_user);
  exception when others then streak := 0;
  end;
  if streak >= 7 then perform public.grant_trophy(p_user, 'streak_7'); end if;
  if streak >= 30 then perform public.grant_trophy(p_user, 'streak_30'); end if;
  if exists (select 1 from public.houses where captain_id = p_user) then
    perform public.grant_trophy(p_user, 'house_founder');
  end if;
  if exists (select 1 from public.user_cosmetic_inventory i where i.user_id = p_user and i.source = 'milestone' and i.source_ref = '50') then
    perform public.grant_trophy(p_user, 'collector');
  end if;
end;
$$;

create or replace function public.get_my_trophies()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return '[]'::jsonb; end if;
  perform public.evaluate_trophies(uid);
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'key', d.key, 'name', d.name, 'description', d.description, 'icon', d.icon, 'rarity', d.rarity,
      'earned', t.user_id is not null, 'earned_at', t.earned_at
    ) order by (t.user_id is null), d.sort_order)
    from public.trophy_defs d
    left join public.user_trophies t on t.trophy_key = d.key and t.user_id = uid
  ), '[]'::jsonb);
end;
$$;
grant execute on function public.get_my_trophies() to authenticated;

-- Another player's earned trophies, for their profile.
create or replace function public.get_user_trophies(p_user_id uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(jsonb_build_object(
    'key', d.key, 'name', d.name, 'description', d.description, 'icon', d.icon, 'rarity', d.rarity,
    'earned', true, 'earned_at', t.earned_at) order by d.sort_order), '[]'::jsonb)
  from public.user_trophies t join public.trophy_defs d on d.key = t.trophy_key
  where t.user_id = p_user_id;
$$;
grant execute on function public.get_user_trophies(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. House goals, bonus points, top members
-- ---------------------------------------------------------------------------
create table if not exists public.house_bonus_points (
  id uuid primary key default gen_random_uuid(),
  house_id uuid not null references public.houses(id) on delete cascade,
  points integer not null,
  reason text not null, -- mission | goal | admin
  source_ref text,
  user_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);
create unique index if not exists house_bonus_points_ref_uq
  on public.house_bonus_points (house_id, reason, source_ref, user_id) nulls not distinct
  where source_ref is not null;
alter table public.house_bonus_points enable row level security;
drop policy if exists "anyone views house bonus" on public.house_bonus_points;
create policy "anyone views house bonus" on public.house_bonus_points for select using (true);

create table if not exists public.house_goal_templates (
  id uuid primary key default gen_random_uuid(),
  title text not null,
  metric text not null check (metric in ('duels_played', 'duels_won', 'games_played')),
  base_target integer not null default 50,
  per_member integer not null default 0,
  reward_points integer not null default 500,
  is_active boolean not null default true,
  sort_order integer not null default 0
);
create table if not exists public.house_goal_results (
  week_start date not null,
  house_id uuid not null references public.houses(id) on delete cascade,
  template_id uuid references public.house_goal_templates(id) on delete set null,
  progress integer not null default 0,
  target integer not null default 0,
  achieved boolean not null default false,
  primary key (week_start, house_id)
);
create table if not exists public.house_fragments (
  house_id uuid primary key references public.houses(id) on delete cascade,
  fragments integer not null default 0,
  unlocked boolean not null default false
);
alter table public.house_goal_templates enable row level security;
alter table public.house_goal_results enable row level security;
alter table public.house_fragments enable row level security;
drop policy if exists "anyone views goal templates" on public.house_goal_templates;
create policy "anyone views goal templates" on public.house_goal_templates for select using (true);
drop policy if exists "admins manage goal templates" on public.house_goal_templates;
create policy "admins manage goal templates" on public.house_goal_templates for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());
drop policy if exists "anyone views goal results" on public.house_goal_results;
create policy "anyone views goal results" on public.house_goal_results for select using (true);
drop policy if exists "anyone views fragments" on public.house_fragments;
create policy "anyone views fragments" on public.house_fragments for select using (true);

create or replace function public.get_house_points(p_house_id uuid)
returns integer language sql stable security definer set search_path = public as $$
  select (
    coalesce((select sum(gs.score) from public.game_scores gs join public.house_members hm on hm.user_id = gs.user_id
              where hm.house_id = p_house_id), 0)
    + coalesce((select sum(b.points) from public.house_bonus_points b where b.house_id = p_house_id), 0)
  )::int;
$$;

create or replace function public.house_week_points(p_house_id uuid)
returns integer language sql stable security definer set search_path = public as $$
  select (
    coalesce((select sum(gs.score) from public.game_scores gs join public.house_members hm on hm.user_id = gs.user_id
              where hm.house_id = p_house_id and gs.created_at >= date_trunc('week', now())), 0)
    + coalesce((select sum(b.points) from public.house_bonus_points b
                where b.house_id = p_house_id and b.reason = 'mission' and b.created_at >= date_trunc('week', now())), 0)
  )::int;
$$;

create or replace function public.house_goal_template_for(p_week date)
returns public.house_goal_templates language plpgsql stable security definer set search_path = public as $$
declare n integer; idx integer; t public.house_goal_templates;
begin
  select count(*) into n from public.house_goal_templates where is_active;
  if n = 0 then return null; end if;
  idx := (floor(extract(epoch from p_week::timestamp) / 604800)::bigint % n)::int;
  select * into t from public.house_goal_templates where is_active order by sort_order, id offset idx limit 1;
  return t;
end;
$$;

create or replace function public.house_goal_progress(p_house uuid, p_metric text, p_from timestamptz, p_to timestamptz)
returns integer language sql stable security definer set search_path = public as $$
  select case p_metric
    when 'duels_played' then (
      select count(*) from public.duel_matches d join public.house_members hm
        on hm.house_id = p_house and (hm.user_id = d.creator_id or hm.user_id = d.opponent_id)
      where d.status = 'completed' and d.ended_at >= p_from and d.ended_at < p_to)
    when 'duels_won' then (
      select count(*) from public.duel_matches d join public.house_members hm
        on hm.house_id = p_house and hm.user_id = d.winner_id
      where d.status = 'completed' and d.ended_at >= p_from and d.ended_at < p_to)
    when 'games_played' then (
      select count(*) from public.game_scores gs join public.house_members hm
        on hm.house_id = p_house and hm.user_id = gs.user_id
      where gs.created_at >= p_from and gs.created_at < p_to)
    else 0 end::int;
$$;

create or replace function public.get_house_goal(p_house_id uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  wk date := date_trunc('week', now())::date;
  t public.house_goal_templates;
  members integer;
  prog integer;
  tgt integer;
  frag record;
begin
  t := public.house_goal_template_for(wk);
  select count(*) into members from public.house_members where house_id = p_house_id;
  select fragments, unlocked into frag from public.house_fragments where house_id = p_house_id;
  if t.id is null then
    return jsonb_build_object('active', false, 'fragments', coalesce(frag.fragments, 0), 'fragments_needed', 4,
                              'unlocked', coalesce(frag.unlocked, false));
  end if;
  prog := public.house_goal_progress(p_house_id, t.metric, wk::timestamptz, (wk + 7)::timestamptz);
  tgt := greatest(t.base_target, t.per_member * members);
  return jsonb_build_object(
    'active', true, 'title', t.title, 'metric', t.metric, 'progress', prog, 'target', tgt,
    'reward_points', t.reward_points, 'achieved', prog >= tgt,
    'ends_at', (wk + 7)::timestamptz,
    'fragments', coalesce(frag.fragments, 0), 'fragments_needed', 4, 'unlocked', coalesce(frag.unlocked, false),
    'reward_name', 'Titan Aura');
end;
$$;
grant execute on function public.get_house_goal(uuid) to authenticated;

create or replace function public.get_house_top_members(p_house_id uuid, p_scope text default 'week')
returns table (user_id uuid, username text, display_name text, avatar_url text, role text, points integer)
language sql stable security definer set search_path = public as $$
  select hm.user_id, p.username, p.display_name, p.avatar_url, hm.role,
         coalesce((select sum(gs.score) from public.game_scores gs
                   where gs.user_id = hm.user_id
                     and (p_scope <> 'week' or gs.created_at >= date_trunc('week', now()))), 0)::int as points
  from public.house_members hm join public.profiles p on p.id = hm.user_id
  where hm.house_id = p_house_id
  order by points desc, p.username asc
  limit 10;
$$;
grant execute on function public.get_house_top_members(uuid, text) to authenticated;

-- Weekly war: records the top three, hands out the champion badge and
-- trophy, and settles each house's weekly goal. Safe to run twice.
create or replace function public.award_house_week()
returns integer language plpgsql security definer set search_path = public as $$
declare
  wk date := (date_trunc('week', now()) - interval '7 days')::date;
  wk_end timestamptz := date_trunc('week', now());
  badge_id uuid;
  titan_id uuid;
  winner uuid;
  n integer := 0;
  t public.house_goal_templates;
  h record;
  prog integer;
  tgt integer;
  frags integer;
begin
  if exists (select 1 from public.house_weekly_results where week_start = wk) then return 0; end if;

  insert into public.house_weekly_results (week_start, house_id, rank, points)
  select wk, x.house_id, x.rk, x.pts from (
    select b.house_id, b.pts, (rank() over (order by b.pts desc))::int as rk
    from (
      select h2.id as house_id,
             (coalesce(sum(gs.score), 0)
              + coalesce((select sum(bp.points) from public.house_bonus_points bp
                          where bp.house_id = h2.id and bp.reason = 'mission'
                            and bp.created_at >= wk::timestamptz and bp.created_at < wk_end), 0))::int as pts,
             count(distinct hm.user_id) as mc
      from public.houses h2
      join public.house_members hm on hm.house_id = h2.id
      left join public.game_scores gs on gs.user_id = hm.user_id
           and gs.created_at >= wk::timestamptz and gs.created_at < wk_end
      group by h2.id
    ) b
    where b.mc >= 3 and b.pts > 0
  ) x
  where x.rk <= 3
  on conflict do nothing;
  get diagnostics n = row_count;

  select house_id into winner from public.house_weekly_results where week_start = wk and rank = 1 limit 1;
  select id into badge_id from public.cosmetic_items where category = 'badge' and name = 'House Champion';
  if winner is not null then
    if badge_id is not null then
      insert into public.user_cosmetic_inventory (user_id, item_id, source)
      select hm.user_id, badge_id, 'house_win' from public.house_members hm where hm.house_id = winner
      on conflict do nothing;
    end if;
    insert into public.user_trophies (user_id, trophy_key)
    select hm.user_id, 'house_champion' from public.house_members hm where hm.house_id = winner
    on conflict do nothing;
  end if;

  -- weekly goal settlement
  t := public.house_goal_template_for(wk);
  if t.id is not null then
    select id into titan_id from public.cosmetic_items where category = 'house_banner' and name = 'Titan Aura';
    for h in
      select hs.id, count(*) as mc from public.houses hs join public.house_members hm on hm.house_id = hs.id
      group by hs.id having count(*) >= 3
    loop
      prog := public.house_goal_progress(h.id, t.metric, wk::timestamptz, wk_end);
      tgt := greatest(t.base_target, t.per_member * h.mc::int);
      insert into public.house_goal_results (week_start, house_id, template_id, progress, target, achieved)
      values (wk, h.id, t.id, prog, tgt, prog >= tgt) on conflict do nothing;
      if prog >= tgt then
        insert into public.house_bonus_points (house_id, points, reason, source_ref)
        values (h.id, t.reward_points, 'goal', wk::text) on conflict do nothing;
        insert into public.house_fragments (house_id, fragments) values (h.id, 1)
        on conflict (house_id) do update set fragments = public.house_fragments.fragments + 1
        returning fragments into frags;
        if frags >= 4 and titan_id is not null then
          insert into public.house_inventory (house_id, item_id) values (h.id, titan_id) on conflict do nothing;
          update public.house_fragments set unlocked = true where house_id = h.id;
        end if;
      end if;
    end loop;
  end if;
  return n;
end;
$$;

-- ---------------------------------------------------------------------------
-- 8. Missions
-- ---------------------------------------------------------------------------
create table if not exists public.mission_seasons (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  starts_on date not null,
  total_days integer not null default 7 check (total_days between 1 and 60),
  is_active boolean not null default false,
  created_at timestamptz not null default now()
);
create unique index if not exists mission_seasons_one_active on public.mission_seasons (is_active) where is_active;

create table if not exists public.missions (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.mission_seasons(id) on delete cascade,
  day_number integer not null check (day_number >= 1),
  title text not null,
  description text,
  instructions text,
  example_url text,
  type text not null check (type in ('in_app', 'social_link', 'clip', 'code_word')),
  metric text check (metric in ('duels_played', 'duels_won', 'games_played', 'game_wins', 'streak_days', 'house_joined')),
  target integer not null default 1 check (target >= 1),
  platform text not null default 'any' check (platform in ('any', 'x', 'instagram', 'tiktok', 'youtube', 'facebook')),
  verify text not null default 'auto_spotcheck' check (verify in ('auto', 'auto_spotcheck', 'manual')),
  reward_item_id uuid references public.cosmetic_items(id) on delete set null,
  reward_house_points integer not null default 0 check (reward_house_points >= 0),
  reward_trophy_key text references public.trophy_defs(key) on delete set null,
  max_winners integer check (max_winners is null or max_winners >= 1),
  starts_at timestamptz,
  ends_at timestamptz,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);
create index if not exists missions_season_idx on public.missions (season_id, day_number, sort_order);

create table if not exists public.mission_secrets (
  mission_id uuid primary key references public.missions(id) on delete cascade,
  answer text not null
);

create table if not exists public.mission_submissions (
  id uuid primary key default gen_random_uuid(),
  mission_id uuid not null references public.missions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  proof_url text,
  storage_path text,
  code text,
  note text,
  auto_approved boolean not null default false,
  needs_spot_check boolean not null default false,
  spot_checked_at timestamptz,
  reviewer_id uuid references auth.users(id),
  reviewed_at timestamptz,
  reject_reason text,
  created_at timestamptz not null default now(),
  unique (mission_id, user_id)
);
create unique index if not exists mission_submissions_url_uq
  on public.mission_submissions (lower(proof_url)) where proof_url is not null and status <> 'rejected';
create index if not exists mission_submissions_queue_idx on public.mission_submissions (status, created_at);

create table if not exists public.mission_season_rewards (
  id uuid primary key default gen_random_uuid(),
  season_id uuid not null references public.mission_seasons(id) on delete cascade,
  threshold integer not null check (threshold >= 1),
  label text not null,
  item_id uuid references public.cosmetic_items(id) on delete set null,
  trophy_key text references public.trophy_defs(key) on delete set null,
  unique (season_id, threshold, label)
);

alter table public.mission_seasons enable row level security;
alter table public.missions enable row level security;
alter table public.mission_secrets enable row level security;
alter table public.mission_submissions enable row level security;
alter table public.mission_season_rewards enable row level security;

drop policy if exists "anyone views seasons" on public.mission_seasons;
create policy "anyone views seasons" on public.mission_seasons for select using (true);
drop policy if exists "admins manage seasons" on public.mission_seasons;
create policy "admins manage seasons" on public.mission_seasons for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());
drop policy if exists "anyone views missions" on public.missions;
create policy "anyone views missions" on public.missions for select using (true);
drop policy if exists "admins manage missions" on public.missions;
create policy "admins manage missions" on public.missions for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());
drop policy if exists "admins manage secrets" on public.mission_secrets;
create policy "admins manage secrets" on public.mission_secrets for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());
drop policy if exists "own submissions" on public.mission_submissions;
create policy "own submissions" on public.mission_submissions for select using (auth.uid() = user_id);
drop policy if exists "admins view submissions" on public.mission_submissions;
create policy "admins view submissions" on public.mission_submissions for select using (public.identity_is_admin());
drop policy if exists "anyone views season rewards" on public.mission_season_rewards;
create policy "anyone views season rewards" on public.mission_season_rewards for select using (true);
drop policy if exists "admins manage season rewards" on public.mission_season_rewards;
create policy "admins manage season rewards" on public.mission_season_rewards for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());

-- Clip uploads: each player writes into their own folder; owners and admins read.
do $$
begin
  if exists (select 1 from information_schema.schemata where schema_name = 'storage') then
    insert into storage.buckets (id, name, public) values ('mission-clips', 'mission-clips', false)
    on conflict (id) do nothing;
    execute 'drop policy if exists "mission clips upload" on storage.objects';
    execute $p$create policy "mission clips upload" on storage.objects for insert to authenticated
      with check (bucket_id = 'mission-clips' and (storage.foldername(name))[1] = auth.uid()::text)$p$;
    execute 'drop policy if exists "mission clips read" on storage.objects';
    execute $p$create policy "mission clips read" on storage.objects for select to authenticated
      using (bucket_id = 'mission-clips' and ((storage.foldername(name))[1] = auth.uid()::text or public.identity_is_admin()))$p$;
  end if;
exception when others then
  raise notice 'could not create the mission-clips bucket policies: %', sqlerrm;
end $$;

-- Day windows, in Lagos time.
create or replace function public.mission_window(p_mission uuid)
returns table (w_from timestamptz, w_to timestamptz, open_from timestamptz, open_until timestamptz)
language plpgsql stable security definer set search_path = public as $$
declare m public.missions; s public.mission_seasons; ds timestamptz;
begin
  select * into m from public.missions where id = p_mission;
  select * into s from public.mission_seasons where id = m.season_id;
  ds := ((s.starts_on + (m.day_number - 1))::timestamp at time zone 'Africa/Lagos');
  w_from := coalesce(m.starts_at, ds);
  w_to := coalesce(m.ends_at, case when m.starts_at is not null then m.starts_at + interval '1 day' else ds + interval '1 day' end);
  open_from := w_from;
  open_until := coalesce(m.ends_at, ((s.starts_on + s.total_days + 2)::timestamp at time zone 'Africa/Lagos'));
  return next;
end;
$$;

create or replace function public.mission_metric_value(p_user uuid, p_metric text, p_from timestamptz, p_to timestamptz)
returns integer language plpgsql stable security definer set search_path = public as $$
declare v integer := 0;
begin
  if p_metric = 'duels_played' then
    select count(*) into v from public.duel_matches
      where status = 'completed' and (creator_id = p_user or opponent_id = p_user) and ended_at >= p_from and ended_at < p_to;
  elsif p_metric = 'duels_won' then
    select count(*) into v from public.duel_matches
      where status = 'completed' and winner_id = p_user and ended_at >= p_from and ended_at < p_to;
  elsif p_metric = 'games_played' then
    select count(*) into v from public.game_scores where user_id = p_user and created_at >= p_from and created_at < p_to;
  elsif p_metric = 'game_wins' then
    select count(*) into v from public.game_scores where user_id = p_user and won and created_at >= p_from and created_at < p_to;
  elsif p_metric = 'streak_days' then
    if exists (select 1 from public.daily_play_log where user_id = p_user
               and play_date >= (p_from at time zone 'Africa/Lagos')::date
               and play_date <= ((p_to - interval '1 second') at time zone 'Africa/Lagos')::date) then
      v := public.get_current_streak(p_user);
    end if;
  elsif p_metric = 'house_joined' then
    select count(*) into v from public.house_members where user_id = p_user;
  end if;
  return coalesce(v, 0);
end;
$$;

create or replace function public.my_mission_code(p_user uuid default auth.uid())
returns text language sql stable security definer set search_path = public as $$
  select 'GAC-' || upper(substr(md5(p_user::text || coalesce((select id::text from public.mission_seasons where is_active limit 1), '')), 1, 4));
$$;
grant execute on function public.my_mission_code(uuid) to authenticated;

-- Rewards for the number of missions finished in the season.
create or replace function public.grant_track_rewards(p_user uuid, p_season uuid)
returns void language plpgsql security definer set search_path = public as $$
declare cnt integer; r record;
begin
  select count(*) into cnt from public.mission_submissions ms join public.missions m on m.id = ms.mission_id
    where ms.user_id = p_user and ms.status = 'approved' and m.season_id = p_season;
  for r in select * from public.mission_season_rewards where season_id = p_season and threshold <= cnt order by threshold loop
    if r.item_id is not null then
      if public.grant_cosmetic(p_user, r.item_id, 'track', p_season::text || ':' || r.threshold) then
        perform public.identity_notify(p_user, 'Season reward unlocked', r.label,
          jsonb_build_object('kind', 'track', 'threshold', r.threshold));
      end if;
    end if;
    if r.trophy_key is not null then perform public.grant_trophy(p_user, r.trophy_key); end if;
  end loop;
  perform public.grant_set_bonuses(p_user);
end;
$$;

create or replace function public.apply_mission_reward(p_mission uuid, p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare m public.missions; hid uuid;
begin
  select * into m from public.missions where id = p_mission;
  if m.reward_item_id is not null then
    perform public.grant_cosmetic(p_user, m.reward_item_id, 'mission', p_mission::text);
  end if;
  if m.reward_house_points > 0 then
    select house_id into hid from public.house_members where user_id = p_user;
    if hid is not null then
      insert into public.house_bonus_points (house_id, points, reason, source_ref, user_id)
      values (hid, m.reward_house_points, 'mission', p_mission::text, p_user) on conflict do nothing;
    end if;
  end if;
  if m.reward_trophy_key is not null then perform public.grant_trophy(p_user, m.reward_trophy_key); end if;
  perform public.identity_notify(p_user, 'Mission complete', m.title,
    jsonb_build_object('kind', 'mission', 'mission_id', p_mission));
  perform public.grant_track_rewards(p_user, m.season_id);
end;
$$;

create or replace function public.mission_winners_left(p_mission uuid)
returns integer language sql stable security definer set search_path = public as $$
  select case when m.max_winners is null then null
         else greatest(0, m.max_winners - (select count(*) from public.mission_submissions s
                                            where s.mission_id = m.id and s.status = 'approved'))::int end
  from public.missions m where m.id = p_mission;
$$;

create or replace function public.my_missions()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.mission_seasons;
  today_day integer;
  cnt integer;
  ms jsonb;
  tr jsonb;
begin
  if uid is null then return null; end if;
  select * into s from public.mission_seasons where is_active order by starts_on desc limit 1;
  if not found then return jsonb_build_object('season', null); end if;
  today_day := ((now() at time zone 'Africa/Lagos')::date - s.starts_on) + 1;

  select count(*) into cnt from public.mission_submissions x join public.missions m on m.id = x.mission_id
    where x.user_id = uid and x.status = 'approved' and m.season_id = s.id;

  select coalesce(jsonb_agg(r.j order by r.day_number, r.sort_order), '[]'::jsonb) into ms from (
    select m.day_number, m.sort_order, jsonb_build_object(
      'id', m.id, 'day_number', m.day_number, 'title', m.title, 'description', m.description,
      'instructions', m.instructions, 'example_url', m.example_url,
      'type', m.type, 'metric', m.metric, 'target', m.target, 'platform', m.platform, 'verify', m.verify,
      'reward_house_points', m.reward_house_points, 'reward_trophy_key', m.reward_trophy_key,
      'reward_item', (select public.cosmetic_json(c, uid) from public.cosmetic_items c where c.id = m.reward_item_id),
      'progress', case when m.type = 'in_app'
                    then least(m.target, public.mission_metric_value(uid, m.metric, w.w_from, w.w_to)) else 0 end,
      'state', case when now() < w.open_from then 'locked' when now() >= w.open_until then 'closed' else 'open' end,
      'opens_at', w.open_from, 'closes_at', w.open_until,
      'status', sub.status, 'reject_reason', sub.reject_reason, 'proof_url', sub.proof_url,
      'winners_left', public.mission_winners_left(m.id)
    ) as j
    from public.missions m
    cross join lateral public.mission_window(m.id) w
    left join public.mission_submissions sub on sub.mission_id = m.id and sub.user_id = uid
    where m.season_id = s.id and m.is_active
  ) r;

  select coalesce(jsonb_agg(jsonb_build_object(
    'threshold', t.threshold, 'label', t.label, 'reached', cnt >= t.threshold,
    'item', (select public.cosmetic_json(c, uid) from public.cosmetic_items c where c.id = t.item_id),
    'trophy_key', t.trophy_key) order by t.threshold), '[]'::jsonb) into tr
  from public.mission_season_rewards t where t.season_id = s.id;

  return jsonb_build_object(
    'season', jsonb_build_object('id', s.id, 'name', s.name, 'starts_on', s.starts_on,
                                 'total_days', s.total_days, 'today_day', today_day),
    'code', public.my_mission_code(uid),
    'approved_count', cnt, 'missions', ms, 'track', tr);
end;
$$;
grant execute on function public.my_missions() to authenticated;

-- In-app missions: the server checks the numbers, the player just taps claim.
create or replace function public.claim_mission(p_mission_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  m public.missions;
  w record;
  v integer;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into m from public.missions where id = p_mission_id and is_active;
  if not found or m.type <> 'in_app' then return jsonb_build_object('success', false, 'error', 'Mission not found'); end if;
  if not exists (select 1 from public.mission_seasons where id = m.season_id and is_active) then
    return jsonb_build_object('success', false, 'error', 'This season is not running');
  end if;
  select * into w from public.mission_window(p_mission_id);
  if now() < w.open_from then return jsonb_build_object('success', false, 'error', 'This mission has not opened yet'); end if;
  if now() >= w.open_until then return jsonb_build_object('success', false, 'error', 'This mission has closed'); end if;
  if exists (select 1 from public.mission_submissions where mission_id = p_mission_id and user_id = uid and status = 'approved') then
    return jsonb_build_object('success', false, 'error', 'Already completed');
  end if;
  if public.mission_winners_left(p_mission_id) = 0 then
    return jsonb_build_object('success', false, 'error', 'Rewards for this mission are fully claimed');
  end if;
  v := public.mission_metric_value(uid, m.metric, w.w_from, w.w_to);
  if v < m.target then
    return jsonb_build_object('success', false, 'error', 'Not finished yet: ' || v || ' of ' || m.target);
  end if;
  insert into public.mission_submissions (mission_id, user_id, status, auto_approved, reviewed_at)
  values (p_mission_id, uid, 'approved', true, now())
  on conflict (mission_id, user_id) do update set status = 'approved', auto_approved = true, reviewed_at = now();
  perform public.apply_mission_reward(p_mission_id, uid);
  return jsonb_build_object('success', true, 'status', 'approved');
end;
$$;
grant execute on function public.claim_mission(uuid) to authenticated;

-- Social posts, clips and code words.
create or replace function public.mission_url_ok(p_platform text, p_url text)
returns boolean language sql immutable as $$
  select case p_platform
    when 'x' then p_url ~* '^https?://(www\.|mobile\.)?(x|twitter)\.com/[A-Za-z0-9_]{1,15}/status/[0-9]+'
    when 'instagram' then p_url ~* '^https?://(www\.)?instagram\.com/(p|reel|reels|tv)/[A-Za-z0-9_-]+'
    when 'tiktok' then p_url ~* '^https?://((www|vm|vt|m)\.)?tiktok\.com/.+'
    when 'youtube' then p_url ~* '^https?://((www|m)\.)?(youtube\.com/(watch|shorts)|youtu\.be/).+'
    when 'facebook' then p_url ~* '^https?://((www|m|web)\.)?(facebook\.com|fb\.watch)/.+'
    else (p_url ~* '^https?://(www\.|mobile\.)?(x|twitter)\.com/[A-Za-z0-9_]{1,15}/status/[0-9]+'
       or p_url ~* '^https?://(www\.)?instagram\.com/(p|reel|reels|tv)/[A-Za-z0-9_-]+'
       or p_url ~* '^https?://((www|vm|vt|m)\.)?tiktok\.com/.+'
       or p_url ~* '^https?://((www|m)\.)?(youtube\.com/(watch|shorts)|youtu\.be/).+'
       or p_url ~* '^https?://((www|m|web)\.)?(facebook\.com|fb\.watch)/.+')
  end;
$$;

-- p_proof is a link, a code word, or (for clips) the storage path of an upload.
create or replace function public.submit_mission(p_mission_id uuid, p_proof text, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  m public.missions;
  w record;
  proof text := btrim(coalesce(p_proof, ''));
  is_upload boolean := false;
  auto boolean := false;
  spot boolean := false;
  prev public.mission_submissions;
  secret text;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into m from public.missions where id = p_mission_id and is_active;
  if not found or m.type = 'in_app' then return jsonb_build_object('success', false, 'error', 'Mission not found'); end if;
  if not exists (select 1 from public.mission_seasons where id = m.season_id and is_active) then
    return jsonb_build_object('success', false, 'error', 'This season is not running');
  end if;
  select * into w from public.mission_window(p_mission_id);
  if now() < w.open_from then return jsonb_build_object('success', false, 'error', 'This mission has not opened yet'); end if;
  if now() >= w.open_until then return jsonb_build_object('success', false, 'error', 'This mission has closed'); end if;

  select * into prev from public.mission_submissions where mission_id = p_mission_id and user_id = uid;
  if found and prev.status in ('pending', 'approved') then
    return jsonb_build_object('success', false, 'error', case when prev.status = 'approved' then 'Already completed' else 'Already submitted, waiting for review' end);
  end if;
  if public.mission_winners_left(p_mission_id) = 0 then
    return jsonb_build_object('success', false, 'error', 'Rewards for this mission are fully claimed');
  end if;
  if proof = '' then return jsonb_build_object('success', false, 'error', 'Add your proof first'); end if;

  if m.type = 'code_word' then
    select answer into secret from public.mission_secrets where mission_id = p_mission_id;
    if secret is null or lower(btrim(secret)) <> lower(proof) then
      return jsonb_build_object('success', false, 'error', 'That code word is not right');
    end if;
    auto := true;
  elsif proof ~* '^https?://' then
    if char_length(proof) > 500 or not public.mission_url_ok(m.platform, proof) then
      return jsonb_build_object('success', false, 'error',
        case m.platform when 'any' then 'Paste the link to your post or clip'
                        else 'Paste the link to your ' || m.platform || ' post' end);
    end if;
    auto := m.verify <> 'manual';
    spot := m.verify = 'auto_spotcheck' and random() < 0.2;
  elsif m.type = 'clip' and proof like uid::text || '/%' then
    is_upload := true; -- uploaded clips are always reviewed by a person
  else
    return jsonb_build_object('success', false, 'error', 'Paste the link to your post or clip');
  end if;

  begin
    insert into public.mission_submissions
      (mission_id, user_id, status, proof_url, storage_path, code, note, auto_approved, needs_spot_check, reviewed_at)
    values (p_mission_id, uid, case when auto then 'approved' else 'pending' end,
            case when is_upload then null else proof end, case when is_upload then proof else null end,
            public.my_mission_code(uid), left(p_note, 300), auto, spot, case when auto then now() end)
    on conflict (mission_id, user_id) do update set
      status = excluded.status, proof_url = excluded.proof_url, storage_path = excluded.storage_path,
      code = excluded.code, note = excluded.note, auto_approved = excluded.auto_approved,
      needs_spot_check = excluded.needs_spot_check, reviewed_at = excluded.reviewed_at,
      reject_reason = null, reviewer_id = null, created_at = now();
  exception when unique_violation then
    return jsonb_build_object('success', false, 'error', 'That link was already used for a mission');
  end;

  if auto then perform public.apply_mission_reward(p_mission_id, uid); end if;
  return jsonb_build_object('success', true, 'status', case when auto then 'approved' else 'pending' end);
end;
$$;
grant execute on function public.submit_mission(uuid, text, text) to authenticated;

-- Admin: the review queue. p_status = pending | spot | approved | rejected | all
create or replace function public.admin_mission_queue(p_status text default 'pending', p_limit integer default 60)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.identity_is_admin() then raise exception 'Admins only'; end if;
  return coalesce((
    select jsonb_agg(j order by created_at desc) from (
      select x.created_at, jsonb_build_object(
        'id', x.id, 'status', x.status, 'proof_url', x.proof_url, 'storage_path', x.storage_path,
        'code', x.code, 'note', x.note, 'auto_approved', x.auto_approved,
        'needs_spot_check', x.needs_spot_check, 'spot_checked_at', x.spot_checked_at,
        'reject_reason', x.reject_reason, 'created_at', x.created_at,
        'user_id', x.user_id, 'username', p.username, 'display_name', p.display_name, 'avatar_url', p.avatar_url,
        'mission_id', m.id, 'mission_title', m.title, 'day_number', m.day_number, 'platform', m.platform, 'type', m.type
      ) as j
      from public.mission_submissions x
      join public.missions m on m.id = x.mission_id
      join public.profiles p on p.id = x.user_id
      where case p_status
              when 'pending' then x.status = 'pending'
              when 'spot' then x.status = 'approved' and x.needs_spot_check and x.spot_checked_at is null
              when 'approved' then x.status = 'approved'
              when 'rejected' then x.status = 'rejected'
              else true end
      order by x.created_at desc
      limit greatest(1, least(p_limit, 200))
    ) t
  ), '[]'::jsonb);
end;
$$;
grant execute on function public.admin_mission_queue(text, integer) to authenticated;

create or replace function public.review_mission_submission(p_id uuid, p_approve boolean, p_reason text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  sub public.mission_submissions;
  m public.missions;
  cnt integer;
  r record;
begin
  if not public.identity_is_admin() then return jsonb_build_object('success', false, 'error', 'Admins only'); end if;
  select * into sub from public.mission_submissions where id = p_id;
  if not found then return jsonb_build_object('success', false, 'error', 'Submission not found'); end if;
  select * into m from public.missions where id = sub.mission_id;

  if p_approve then
    if sub.status = 'approved' then
      update public.mission_submissions set spot_checked_at = now(), reviewer_id = auth.uid() where id = p_id;
    else
      update public.mission_submissions set status = 'approved', reviewer_id = auth.uid(), reviewed_at = now(),
        reject_reason = null, spot_checked_at = now() where id = p_id;
      perform public.apply_mission_reward(sub.mission_id, sub.user_id);
    end if;
  else
    update public.mission_submissions set status = 'rejected', reviewer_id = auth.uid(), reviewed_at = now(),
      reject_reason = coalesce(nullif(btrim(p_reason), ''), 'Proof could not be confirmed'), spot_checked_at = now()
      where id = p_id;
    if sub.status = 'approved' then
      -- take back what the mission gave
      if m.reward_item_id is not null then
        perform public.revoke_cosmetic(sub.user_id, m.reward_item_id);
      end if;
      delete from public.house_bonus_points where reason = 'mission' and source_ref = sub.mission_id::text and user_id = sub.user_id;
      if m.reward_trophy_key is not null then
        delete from public.user_trophies where user_id = sub.user_id and trophy_key = m.reward_trophy_key;
      end if;
      select count(*) into cnt from public.mission_submissions x join public.missions mm on mm.id = x.mission_id
        where x.user_id = sub.user_id and x.status = 'approved' and mm.season_id = m.season_id;
      for r in select * from public.mission_season_rewards where season_id = m.season_id and threshold > cnt loop
        if r.item_id is not null then
          delete from public.user_cosmetic_inventory
            where user_id = sub.user_id and item_id = r.item_id and source = 'track' and source_ref = m.season_id::text || ':' || r.threshold;
        end if;
      end loop;
    end if;
    perform public.identity_notify(sub.user_id, 'Mission not approved', m.title || ': ' || coalesce(nullif(btrim(p_reason), ''), 'Proof could not be confirmed'),
      jsonb_build_object('kind', 'mission_rejected', 'mission_id', m.id));
  end if;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.review_mission_submission(uuid, boolean, text) to authenticated;

-- Admin grants (finale winners, school crests, one-off thanks)
create or replace function public.admin_grant_cosmetic(p_user uuid, p_item uuid, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.identity_is_admin() then return jsonb_build_object('success', false, 'error', 'Admins only'); end if;
  if not exists (select 1 from public.cosmetic_items where id = p_item) then
    return jsonb_build_object('success', false, 'error', 'Unknown item');
  end if;
  perform public.grant_cosmetic(p_user, p_item, 'admin', p_note);
  perform public.grant_set_bonuses(p_user);
  perform public.identity_notify(p_user, 'You received an item', coalesce(p_note, 'A new item is in your locker.'),
    jsonb_build_object('kind', 'gift'));
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.admin_grant_cosmetic(uuid, uuid, text) to authenticated;

create or replace function public.admin_grant_trophy(p_user uuid, p_key text)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.identity_is_admin() then return jsonb_build_object('success', false, 'error', 'Admins only'); end if;
  if not public.grant_trophy(p_user, p_key) then
    return jsonb_build_object('success', false, 'error', 'Unknown trophy or already earned');
  end if;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.admin_grant_trophy(uuid, text) to authenticated;

create or replace function public.admin_grant_house_points(p_house uuid, p_points integer, p_reason text default 'admin')
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.identity_is_admin() then return jsonb_build_object('success', false, 'error', 'Admins only'); end if;
  insert into public.house_bonus_points (house_id, points, reason) values (p_house, p_points, 'admin');
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.admin_grant_house_points(uuid, integer, text) to authenticated;

-- Internal helpers are not callable from the app.
revoke all on function public.grant_cosmetic(uuid, uuid, text, text) from public, anon, authenticated;
revoke all on function public.revoke_cosmetic(uuid, uuid) from public, anon, authenticated;
revoke all on function public.grant_set_bonuses(uuid) from public, anon, authenticated;
revoke all on function public.grant_trophy(uuid, text) from public, anon, authenticated;
revoke all on function public.evaluate_trophies(uuid) from public, anon, authenticated;
revoke all on function public.grant_track_rewards(uuid, uuid) from public, anon, authenticated;
revoke all on function public.apply_mission_reward(uuid, uuid) from public, anon, authenticated;
revoke all on function public.identity_notify(uuid, text, text, jsonb) from public, anon, authenticated;
revoke all on function public.rotate_shop() from public, anon, authenticated;
revoke all on function public.rotate_daily_deals() from public, anon, authenticated;
revoke all on function public.rotate_featured() from public, anon, authenticated;
revoke all on function public.award_house_week() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 9. Seed: trophies
-- ---------------------------------------------------------------------------
insert into public.trophy_defs (key, name, description, icon, rarity, sort_order) values
  ('first_win',      'First Blood',     'Win your first duel',                         'bolt_rounded',                  'common',    1),
  ('wins_10',        'Duelist',         'Win 10 duels',                                'emoji_events_rounded',          'rare',      2),
  ('wins_50',        'Veteran Duelist', 'Win 50 duels',                                'military_tech_rounded',         'epic',      3),
  ('streak_7',       'Week Warrior',    'Play 7 days in a row',                        'local_fire_department_rounded', 'rare',      4),
  ('streak_30',      'Iron Habit',      'Play 30 days in a row',                       'local_fire_department_rounded', 'legendary', 5),
  ('house_founder',  'Founder',         'Found a House',                               'castle_rounded',                'rare',      6),
  ('house_champion', 'House Champion',  'Be in the House that wins the weekly war',    'shield_rounded',                'epic',      7),
  ('collector',      'Collector',       'Collect half of the catalogue',               'diamond_rounded',               'epic',      8),
  ('agon_initiate',  'Agon Initiate',   'Finish your first Agon mission',              'star_rounded',                  'common',    9),
  ('agon_voice',     'Agon Voice',      'Share GACOM with the world during Agon',      'rocket_launch_rounded',         'rare',     10),
  ('agon_finisher',  'Agon Finisher',   'Finish the Agon mission track',               'workspace_premium_rounded',     'legendary',11),
  ('agon_champion',  'Agon Champion',   'Win the Agon finale',                         'emoji_events_rounded',          'mythic',   12)
on conflict (key) do nothing;

-- ---------------------------------------------------------------------------
-- 10. Seed: new catalogue items
-- ---------------------------------------------------------------------------
insert into public.cosmetic_items
  (category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, set_key, earn_hint, available_until)
select * from (values
  -- frames
  ('avatar_frame','Circuit','circuit','{"colors":["#2ED3E6","#3C9DFF"],"style":"circuit"}'::jsonb,600,'epic',false,'user','Traces of light around your portrait.',21,'shop',null,null,null::timestamptz),
  ('avatar_frame','Adire Ring','adire','{"colors":["#2D3A8C","#F6B93B"],"style":"adire"}'::jsonb,700,'epic',false,'user','Indigo and gold, inspired by adire cloth.',22,'shop',null,null,null),
  ('avatar_frame','Voltage','voltage','{"colors":["#FF4F66","#FFD84A"],"style":"voltage"}'::jsonb,0,'mythic',false,'user','Live arcs of current. Never sold.',90,'earned',null,'Finish the whole Agon mission track',null),
  ('avatar_frame','Vault Ring','vault','{"colors":["#F6B93B","#7A5A12"],"style":"vault"}'::jsonb,0,'legendary',false,'user','Heavy gold for serious collectors.',91,'earned',null,'Collect 50% of the catalogue',null),
  ('avatar_frame','School Crest','crest','{"colors":["#2ED3E6","#F6B93B"],"style":"crest"}'::jsonb,0,'epic',false,'user','Issued to students of partner schools.',92,'licence',null,'Issued to partner school students',null),
  -- banners
  ('profile_banner','Lagos Sunset','','{"from":"#FF7A18","to":"#7B2FF7","pattern":"waves"}'::jsonb,500,'rare',false,'user','Orange sky over purple water.',12,'shop',null,null,null),
  ('profile_banner','Harmattan Haze','','{"from":"#C9A66B","to":"#5B6C8F","pattern":"haze"}'::jsonb,400,'rare',false,'user','Dry season light. Gone in March.',13,'shop',null,null,'2027-03-01'::timestamptz),
  ('profile_banner','Archive','','{"from":"#1B2A41","to":"#F6B93B","pattern":"grid"}'::jsonb,0,'epic',false,'user','For people who finish collections.',92,'earned',null,'Collect 75% of the catalogue',null),
  ('profile_banner','Agon Day 1','','{"from":"#0F3B52","to":"#2ED3E6","pattern":"stripes"}'::jsonb,0,'rare',false,'user','Agon, day one.',80,'earned',null,'Agon mission, day 1',null),
  ('profile_banner','Agon Day 2','','{"from":"#1B3A2A","to":"#3DDC84","pattern":"stripes"}'::jsonb,0,'rare',false,'user','Agon, day two.',81,'earned',null,'Agon mission, day 2',null),
  ('profile_banner','Agon Day 3','','{"from":"#3A2A0F","to":"#F6B93B","pattern":"stripes"}'::jsonb,0,'rare',false,'user','Agon, day three.',82,'earned',null,'Agon mission, day 3',null),
  ('profile_banner','Agon Day 4','','{"from":"#3A0F2A","to":"#FF4F66","pattern":"stripes"}'::jsonb,0,'rare',false,'user','Agon, day four.',83,'earned',null,'Agon mission, day 4',null),
  ('profile_banner','Agon Day 5','','{"from":"#2A0F3A","to":"#B060FF","pattern":"stripes"}'::jsonb,0,'rare',false,'user','Agon, day five.',84,'earned',null,'Agon mission, day 5',null),
  ('profile_banner','Agon Day 6','','{"from":"#0F2A3A","to":"#3C9DFF","pattern":"stripes"}'::jsonb,0,'rare',false,'user','Agon, day six.',85,'earned',null,'Agon mission, day 6',null),
  ('profile_banner','Agon Day 7','','{"from":"#3A1F0F","to":"#FF8A3C","pattern":"stripes"}'::jsonb,0,'rare',false,'user','Agon, day seven.',86,'earned',null,'Agon mission, day 7',null),
  ('profile_banner','Agon Arena','','{"from":"#080C14","to":"#FF4F66","pattern":"hex"}'::jsonb,0,'epic',false,'user','Hexagons and red light from the arena.',87,'earned',null,'Finish 6 Agon missions',null),
  -- trails
  ('trail','Lightning','','{"kind":"lightning","color":"#2ED3E6"}'::jsonb,500,'rare',false,'user','Cyan arcs behind your hero.',13,'shop',null,null,null),
  ('trail','Harmattan Dust','','{"kind":"dust","color":"#D9B36C"}'::jsonb,300,'common',false,'user','A cloud of dry season dust. Gone in March.',14,'shop',null,null,'2027-03-01'::timestamptz),
  ('trail','Agon Spark','','{"kind":"sparkle","color":"#FF4F66"}'::jsonb,0,'epic',false,'user','Red sparks from the arena.',85,'earned',null,'Finish 4 Agon missions',null),
  ('trail','Solar Aura','','{"kind":"aura","color":"#FFC107"}'::jsonb,0,'legendary',false,'user','Bonus for owning the whole Solar Set.',88,'earned',null,'Own all four Solar Set pieces',null),
  ('trail','Collector Aura','','{"kind":"aura","color":"#FF4F66"}'::jsonb,0,'mythic',false,'user','For people who own everything.',93,'earned',null,'Collect 100% of the catalogue',null),
  -- titles
  ('title','Challenger','Challenger','{}'::jsonb,100,'common',false,'user','Always up for a duel.',10,'shop',null,null,null),
  ('title','Night Owl','Night Owl','{}'::jsonb,150,'common',false,'user','Plays after midnight.',11,'shop',null,null,null),
  ('title','Scholar','Scholar','{}'::jsonb,150,'common',false,'user','Brain first.',12,'shop',null,null,null),
  ('title','Speedrunner','Speedrunner','{}'::jsonb,300,'rare',false,'user','Fast is a lifestyle.',13,'shop',null,null,null),
  ('title','Quiz Master','Quiz Master','{}'::jsonb,300,'rare',false,'user','Knows the answer already.',14,'shop',null,null,null),
  ('title','Streak Lord','Streak Lord','{}'::jsonb,0,'epic',false,'user','Never misses a day.',80,'earned',null,'Play 30 days in a row',null),
  ('title','Day-One Player','Day-One Player','{}'::jsonb,0,'rare',false,'user','There from the first Agon mission.',81,'earned',null,'Finish 2 Agon missions',null),
  ('title','Collector','Collector','{}'::jsonb,0,'rare',false,'user','Has a locker worth showing.',82,'earned',null,'Collect 25% of the catalogue',null),
  ('title','Agon Finisher','Agon Finisher','{}'::jsonb,0,'epic',false,'user','Finished every Agon mission.',83,'earned',null,'Finish the Agon mission track',null),
  ('title','Agon Champion','Agon Champion','{}'::jsonb,0,'mythic',false,'user','Won the Agon finale.',99,'earned',null,'Win the Agon finale',null),
  -- badge, outfit, house banner
  ('badge','Agon Veteran','emoji_events_rounded','{}'::jsonb,0,'epic',false,'user','Fought through Agon.',85,'earned',null,'Finish 7 Agon missions',null),
  ('hero_outfit','Agon Champion','','{"shirt":"#FF4F66","pants":"#0D1320","skin":"#C68642","hair":"#1B1B1B"}'::jsonb,0,'mythic',false,'user','Worn by the Agon finale winners only.',99,'earned',null,'Win the Agon finale',null),
  ('house_banner','Titan Aura','','{"from":"#F6B93B","to":"#FF4F66"}'::jsonb,0,'legendary',false,'house','Unlocked by four weekly House goals.',90,'earned',null,'Complete 4 weekly House goals',null)
) as seed(category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, set_key, earn_hint, available_until)
where not exists (select 1 from public.cosmetic_items c where c.category = seed.category and c.name = seed.name);

-- Solar Set: four existing items plus the bonus piece
update public.cosmetic_items set set_key = 'solar'
  where (category = 'hero_outfit' and name = 'Solar Knight')
     or (category = 'profile_banner' and name = 'Gold Lux')
     or (category = 'trail' and name = 'Flame')
     or (category = 'badge' and name = 'Blaze');
update public.cosmetic_items set earn_hint = 'Win the weekly House war' where category = 'badge' and name = 'House Champion';

insert into public.cosmetic_sets (key, name, bonus_item_id, description)
select 'solar', 'Solar Set', (select id from public.cosmetic_items where category = 'trail' and name = 'Solar Aura'),
       'Own all four pieces and the Solar Aura trail is yours.'
on conflict (key) do nothing;

insert into public.collection_milestones (percent, item_id, label)
select 25, id, 'Title: Collector' from public.cosmetic_items where category = 'title' and name = 'Collector'
on conflict (percent) do nothing;
insert into public.collection_milestones (percent, item_id, label)
select 50, id, 'Frame: Vault Ring' from public.cosmetic_items where category = 'avatar_frame' and name = 'Vault Ring'
on conflict (percent) do nothing;
insert into public.collection_milestones (percent, item_id, label)
select 75, id, 'Banner: Archive' from public.cosmetic_items where category = 'profile_banner' and name = 'Archive'
on conflict (percent) do nothing;
insert into public.collection_milestones (percent, item_id, label)
select 100, id, 'Mythic effect: Collector Aura' from public.cosmetic_items where category = 'trail' and name = 'Collector Aura'
on conflict (percent) do nothing;

-- Bundles
insert into public.cosmetic_bundles (name, description, discount_percent, sort_order) values
  ('Exam Season Pack', 'Everything you need for a serious revision week.', 25, 1),
  ('Fire Pack', 'Ember Runner, Flame trail and the Blaze badge together.', 30, 2)
on conflict (name) do nothing;
insert into public.cosmetic_bundle_items (bundle_id, item_id)
select b.id, c.id from public.cosmetic_bundles b
join public.cosmetic_items c on (b.name = 'Exam Season Pack' and (c.category, c.name) in
  (('badge','Brain'), ('title','Scholar'), ('profile_banner','Aurora'), ('avatar_frame','Neon Ring')))
  or (b.name = 'Fire Pack' and (c.category, c.name) in
  (('hero_outfit','Ember Runner'), ('trail','Flame'), ('badge','Blaze')))
on conflict do nothing;

-- House goals
insert into public.house_goal_templates (title, metric, base_target, per_member, reward_points, sort_order)
select * from (values
  ('Play 200 duels together this week', 'duels_played', 40, 5, 500, 1),
  ('Win 100 duels together this week', 'duels_won', 20, 3, 500, 2),
  ('Play 500 games together this week', 'games_played', 60, 10, 500, 3)
) as v(title, metric, base_target, per_member, reward_points, sort_order)
where not exists (select 1 from public.house_goal_templates);

-- ---------------------------------------------------------------------------
-- 11. Seed: Agon season 1 (edit or replace from the admin screen)
-- ---------------------------------------------------------------------------
insert into public.mission_seasons (name, starts_on, total_days, is_active)
select 'Agon Season 1', date '2026-10-15', 7, true
where not exists (select 1 from public.mission_seasons)
on conflict (name) do nothing;

insert into public.missions
  (season_id, day_number, title, description, instructions, type, metric, target, platform, verify,
   reward_item_id, reward_house_points, reward_trophy_key, sort_order)
select s.id, v.day_number, v.title, v.description, v.instructions, v.type, v.metric, v.target, v.platform, v.verify,
       (select id from public.cosmetic_items c where c.category = v.cat and c.name = v.item),
       v.hp, v.trophy, v.sort_order
from public.mission_seasons s
cross join (values
  (1, 'First Blood', 'Play 3 duels today.', null, 'in_app', 'duels_played', 3, 'any', 'auto', 'profile_banner', 'Agon Day 1', 25, 'agon_initiate', 1),
  (1, 'Pick a side', 'Join or found a House.', null, 'in_app', 'house_joined', 1, 'any', 'auto', null, null, 25, null, 2),
  (2, 'Winning habit', 'Win 5 games today.', null, 'in_app', 'game_wins', 5, 'any', 'auto', 'profile_banner', 'Agon Day 2', 25, null, 1),
  (3, 'Streak starter', 'Reach a 3 day streak and play today.', null, 'in_app', 'streak_days', 3, 'any', 'auto', 'profile_banner', 'Agon Day 3', 25, null, 1),
  (4, 'Tell X about GACOM', 'Post about GACOM on X and paste the link.',
     'Post on X about why you are playing GACOM. Add your code and tag @gacom_ng. Then paste the link to your post.',
     'social_link', null, 1, 'x', 'auto_spotcheck', 'profile_banner', 'Agon Day 4', 50, 'agon_voice', 1),
  (5, 'Clip of the day', 'Share a gameplay clip.',
     'Record your best moment (screen recording), post it on TikTok, Instagram, YouTube or X with your code, and paste the link. You can also upload the video here.',
     'clip', null, 1, 'any', 'auto_spotcheck', 'profile_banner', 'Agon Day 5', 50, null, 1),
  (6, 'Duel marathon', 'Play 5 duels today.', null, 'in_app', 'duels_played', 5, 'any', 'auto', 'profile_banner', 'Agon Day 6', 25, null, 1),
  (7, 'Finale: close it out', 'Win 3 duels today.', null, 'in_app', 'duels_won', 3, 'any', 'auto', 'profile_banner', 'Agon Day 7', 50, null, 1)
) as v(day_number, title, description, instructions, type, metric, target, platform, verify, cat, item, hp, trophy, sort_order)
where s.name = 'Agon Season 1'
  and not exists (select 1 from public.missions m where m.season_id = s.id);

insert into public.mission_season_rewards (season_id, threshold, label, item_id, trophy_key)
select s.id, v.threshold, v.label, (select id from public.cosmetic_items c where c.category = v.cat and c.name = v.item), v.trophy
from public.mission_seasons s
cross join (values
  (2, 'Title: Day-One Player', 'title', 'Day-One Player', null),
  (4, 'Trail: Agon Spark', 'trail', 'Agon Spark', null),
  (6, 'Banner: Agon Arena', 'profile_banner', 'Agon Arena', null),
  (7, 'Badge: Agon Veteran', 'badge', 'Agon Veteran', null),
  (8, 'Frame: Voltage', 'avatar_frame', 'Voltage', 'agon_finisher'),
  (8, 'Title: Agon Finisher', 'title', 'Agon Finisher', null)
) as v(threshold, label, cat, item, trophy)
where s.name = 'Agon Season 1'
on conflict (season_id, threshold, label) do nothing;

notify pgrst, 'reload schema';
