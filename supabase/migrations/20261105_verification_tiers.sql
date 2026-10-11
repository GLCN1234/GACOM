-- Verification levels, ID checks, tier-based hosting limits, and admin pricing controls.
-- Run after 20261103_verified_hosting.sql and 20261104_ads_engine.sql (both can be re-run safely).
--
--   * Five paid levels (Verified, Plus, Pro, Elite, Legend). Each has a price, a tick colour,
--     hosting limits, a platform fee on entry fees, an ad discount, and cosmetic assets that come
--     with it. Assets are granted while the level is active and taken back when it lapses or drops.
--   * ID check: the user uploads an ID photo and a selfie to a private bucket, an admin approves or
--     rejects, and the pictures are deleted after the decision. The higher levels, and any
--     competition with an entry fee, need an approved ID.
--   * Admin controls for ad rates, ad settings and the tiers (the Ads and Pricing screen).

-- ---------------------------------------------------------------------------
-- 1. Tiers
-- ---------------------------------------------------------------------------
create table if not exists public.verification_tiers (
  code text primary key,
  rank integer not null unique,
  name text not null,
  tagline text not null default '',
  price integer not null check (price >= 0),          -- naira per 30 days
  color text not null default '#3B82F6',               -- tick colour
  max_active integer not null check (max_active >= 1),  -- competitions hosted at once
  max_prize integer not null check (max_prize >= 0),    -- biggest prize pool
  max_players integer not null check (max_players between 2 and 1000),
  fee_percent integer not null check (fee_percent between 0 and 50),   -- platform cut of entry fees
  ad_discount integer not null default 0 check (ad_discount between 0 and 90),
  needs_id boolean not null default false,
  active boolean not null default true
);
alter table public.verification_tiers enable row level security;
drop policy if exists "anyone reads tiers" on public.verification_tiers;
create policy "anyone reads tiers" on public.verification_tiers for select using (true);
revoke insert, update, delete on public.verification_tiers from anon, authenticated;

insert into public.verification_tiers (code, rank, name, tagline, price, color, max_active, max_prize, max_players, fee_percent, ad_discount, needs_id) values
  ('verified', 1, 'Verified', 'The tick, and your first competitions', 2000, '#3B82F6', 1, 20000, 50, 15, 0, false),
  ('plus', 2, 'Plus', 'More room to host, cheaper ads', 5000, '#14B8A6', 3, 100000, 200, 12, 5, false),
  ('pro', 3, 'Pro', 'Serious hosting for regular events', 10000, '#F59E0B', 5, 300000, 500, 10, 10, true),
  ('elite', 4, 'Elite', 'Big prize pools and low fees', 20000, '#8B5CF6', 8, 500000, 1000, 8, 15, true),
  ('legend', 5, 'Legend', 'Everything unlocked, lowest fees', 50000, '#EF4444', 15, 1000000, 1000, 5, 20, true)
on conflict (code) do nothing;

alter table public.verification_subscriptions add column if not exists tier text not null default 'verified';
alter table public.profiles add column if not exists verification_tier text;

-- ---------------------------------------------------------------------------
-- 2. Assets that come with a level
-- ---------------------------------------------------------------------------
do $$ begin
  alter table public.cosmetic_items drop constraint if exists cosmetic_items_source_chk;
  alter table public.cosmetic_items add constraint cosmetic_items_source_chk
    check (source in ('shop', 'premium', 'earned', 'licence', 'verification'));
end $$;

create table if not exists public.verification_tier_items (
  tier text not null references public.verification_tiers(code) on delete cascade,
  item_id uuid not null references public.cosmetic_items(id) on delete cascade,
  primary key (tier, item_id)
);
alter table public.verification_tier_items enable row level security;
drop policy if exists "anyone reads tier items" on public.verification_tier_items;
create policy "anyone reads tier items" on public.verification_tier_items for select using (true);
revoke insert, update, delete on public.verification_tier_items from anon, authenticated;

insert into public.cosmetic_items
  (category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
select v.category, v.name, v.value, v.asset, 0, v.rarity, false, 'user', v.description, v.sort_order, 'verification', v.earn_hint
from (values
  ('title','Verified Member','Verified Member','{}'::jsonb,'rare','Shown under your name.',950,'Included with Verified'),
  ('emote','Blue Star','star','{"kind":"star","color":"#3B82F6"}'::jsonb,'rare','A bright blue star.',951,'Included with Verified'),
  ('avatar_frame','Plus Halo','','{"style":"crest","colors":["#14B8A6","#99F6E4"]}'::jsonb,'epic','A teal halo ring.',952,'Included with Plus'),
  ('spray','Plus Bolt','bolt','{"kind":"bolt","color":"#14B8A6"}'::jsonb,'epic','Teal bolt stencil.',953,'Included with Plus'),
  ('title','Pro Host','Pro Host','{}'::jsonb,'epic','For hosts who run real events.',954,'Included with Pro'),
  ('finisher','Pro Shockwave','shockwave','{"kind":"shockwave","color":"#F59E0B","color2":"#FFFFFF"}'::jsonb,'epic','Golden rings of force.',955,'Included with Pro'),
  ('avatar_frame','Elite Vault','','{"style":"vault","colors":["#8B5CF6","#DDD6FE"]}'::jsonb,'legendary','A heavy violet vault ring.',956,'Included with Elite'),
  ('emote','Elite Crown','crown','{"kind":"crown","color":"#8B5CF6"}'::jsonb,'legendary','A violet crown.',957,'Included with Elite'),
  ('finisher','Legend Nova','nova','{"kind":"nova","color":"#EF4444","color2":"#FECACA"}'::jsonb,'legendary','A crimson star goes off.',958,'Included with Legend'),
  ('spray','Legend Crown','crown','{"kind":"crown","color":"#EF4444"}'::jsonb,'legendary','Crimson crown tag.',959,'Included with Legend'),
  ('avatar_frame','Legend Stormline','','{"style":"voltage","colors":["#EF4444","#FDE047"]}'::jsonb,'legendary','Live current in red and gold.',960,'Included with Legend')
) as v(category, name, value, asset, rarity, description, sort_order, earn_hint)
where not exists (select 1 from public.cosmetic_items c where c.category = v.category and c.name = v.name);

insert into public.verification_tier_items (tier, item_id)
select t.tier, c.id from (values
  ('verified','title','Verified Member'), ('verified','emote','Blue Star'),
  ('plus','avatar_frame','Plus Halo'), ('plus','spray','Plus Bolt'),
  ('pro','title','Pro Host'), ('pro','finisher','Pro Shockwave'),
  ('elite','avatar_frame','Elite Vault'), ('elite','emote','Elite Crown'),
  ('legend','finisher','Legend Nova'), ('legend','spray','Legend Crown'), ('legend','avatar_frame','Legend Stormline')
) as t(tier, category, name)
join public.cosmetic_items c on c.category = t.category and c.name = t.name
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- 3. ID check
-- ---------------------------------------------------------------------------
create table if not exists public.id_verifications (
  user_id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'approved', 'rejected')),
  doc_type text,
  full_name text,
  doc_path text,
  selfie_path text,
  submitted_at timestamptz not null default now(),
  reviewed_by uuid,
  reviewed_at timestamptz,
  note text
);
alter table public.id_verifications enable row level security;
drop policy if exists "own id check" on public.id_verifications;
create policy "own id check" on public.id_verifications for select using (user_id = auth.uid() or public.sec_is_admin());
revoke insert, update, delete on public.id_verifications from anon, authenticated;

create or replace function public.id_approved(p_user uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.id_verifications v where v.user_id = p_user and v.status = 'approved');
$$;

create or replace function public.id_check_state()
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.id_verifications;
begin
  if auth.uid() is null then return null; end if;
  select * into v from public.id_verifications x where x.user_id = auth.uid();
  if not found then return jsonb_build_object('status', 'none'); end if;
  return jsonb_build_object('status', v.status, 'note', v.note, 'submitted_at', v.submitted_at);
end;
$$;
grant execute on function public.id_check_state() to authenticated;

create or replace function public.id_check_submit(p_doc_type text, p_full_name text, p_doc_path text, p_selfie_path text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); v public.id_verifications; v_name text := btrim(coalesce(p_full_name, ''));
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  perform public.sec_rl('id_submit', 5, 86400);
  if p_doc_type not in ('nin', 'drivers_licence', 'passport', 'voters_card') then
    return jsonb_build_object('success', false, 'error', 'Choose the type of ID');
  end if;
  if length(v_name) < 3 or length(v_name) > 80 then return jsonb_build_object('success', false, 'error', 'Enter your full name as it appears on the ID'); end if;
  if coalesce(p_doc_path, '') not like uid::text || '/%' or coalesce(p_selfie_path, '') not like uid::text || '/%' then
    return jsonb_build_object('success', false, 'error', 'Upload the ID photo and the selfie again');
  end if;
  select * into v from public.id_verifications x where x.user_id = uid;
  if found and v.status = 'approved' then return jsonb_build_object('success', false, 'error', 'Your ID is already verified'); end if;
  if found and v.status = 'pending' then return jsonb_build_object('success', false, 'error', 'Your ID is already being reviewed'); end if;
  insert into public.id_verifications (user_id, status, doc_type, full_name, doc_path, selfie_path, submitted_at, reviewed_by, reviewed_at, note)
  values (uid, 'pending', p_doc_type, v_name, p_doc_path, p_selfie_path, now(), null, null, null)
  on conflict (user_id) do update
    set status = 'pending', doc_type = excluded.doc_type, full_name = excluded.full_name, doc_path = excluded.doc_path,
        selfie_path = excluded.selfie_path, submitted_at = now(), reviewed_by = null, reviewed_at = null, note = null;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.id_check_submit(text, text, text, text) to authenticated;

create or replace function public.admin_id_queue()
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'user_id', v.user_id, 'username', p.username, 'display_name', p.display_name, 'full_name', v.full_name,
      'doc_type', v.doc_type, 'doc_path', v.doc_path, 'selfie_path', v.selfie_path, 'submitted_at', v.submitted_at)
      order by v.submitted_at)
    from public.id_verifications v left join public.profiles p on p.id = v.user_id
   where v.status = 'pending'), '[]'::jsonb);
end;
$$;
grant execute on function public.admin_id_queue() to authenticated;

-- The app deletes the two pictures from storage with the paths returned here.
create or replace function public.admin_id_review(p_user uuid, p_approve boolean, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare v public.id_verifications;
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  select * into v from public.id_verifications x where x.user_id = p_user for update;
  if not found or v.status <> 'pending' then return jsonb_build_object('success', false, 'error', 'Nothing to review'); end if;
  update public.id_verifications
     set status = case when p_approve then 'approved' else 'rejected' end,
         reviewed_by = auth.uid(), reviewed_at = now(), note = nullif(btrim(coalesce(p_note, '')), ''),
         doc_path = null, selfie_path = null
   where user_id = p_user;
  perform public.identity_notify(p_user,
    case when p_approve then 'ID verified' else 'ID not accepted' end,
    case when p_approve then 'Your ID check passed. Higher verification levels and paid competitions are now open to you.'
         else coalesce(nullif(btrim(coalesce(p_note, '')), ''), 'We could not read your ID. Please try again with clearer photos.') end,
    jsonb_build_object('kind', 'id_check', 'approved', p_approve));
  return jsonb_build_object('success', true, 'paths', jsonb_build_array(v.doc_path, v.selfie_path));
end;
$$;
grant execute on function public.admin_id_review(uuid, boolean, text) to authenticated;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('id-checks', 'id-checks', false, 6291456, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = false, file_size_limit = 6291456,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];
drop policy if exists "id checks upload own" on storage.objects;
create policy "id checks upload own" on storage.objects for insert to authenticated
  with check (bucket_id = 'id-checks' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "id checks read own or admin" on storage.objects;
create policy "id checks read own or admin" on storage.objects for select to authenticated
  using (bucket_id = 'id-checks' and ((storage.foldername(name))[1] = auth.uid()::text or public.sec_is_admin()));
drop policy if exists "id checks delete admin" on storage.objects;
create policy "id checks delete admin" on storage.objects for delete to authenticated
  using (bucket_id = 'id-checks' and public.sec_is_admin());

-- ---------------------------------------------------------------------------
-- 4. Current level, asset sync, expiry
-- ---------------------------------------------------------------------------
-- The tier a user holds right now (null row when none).
create or replace function public.verification_active_tier(p_user uuid)
returns public.verification_tiers language sql stable security definer set search_path = public as $$
  select t.* from public.verification_subscriptions s
    join public.verification_tiers t on t.code = s.tier
   where s.user_id = p_user and s.expires_at > now();
$$;

-- Limits used when hosting. Admins without a subscription get the top level.
create or replace function public.host_limits(p_user uuid)
returns public.verification_tiers language plpgsql stable security definer set search_path = public as $$
declare t public.verification_tiers;
begin
  select * into t from public.verification_active_tier(p_user);
  if t.code is not null then return t; end if;
  if exists (select 1 from public.profiles p where p.id = p_user and p.role::text in ('admin', 'super_admin')) then
    select * into t from public.verification_tiers order by rank desc limit 1;
    return t;
  end if;
  return null;
end;
$$;

-- Gives the user every asset of their level and the levels below, and takes back the rest
-- (only items that came from verification).
create or replace function public.verification_sync_assets(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare cur_rank integer := 0; r record;
begin
  select coalesce((select t.rank from public.verification_active_tier(p_user) t), 0) into cur_rank;
  for r in
    select ti.item_id, vt.rank, vt.code from public.verification_tier_items ti join public.verification_tiers vt on vt.code = ti.tier
  loop
    if r.rank <= cur_rank then
      perform public.grant_cosmetic(p_user, r.item_id, 'verification', r.code);
    elsif exists (select 1 from public.user_cosmetic_inventory i where i.user_id = p_user and i.item_id = r.item_id and i.source = 'verification') then
      perform public.revoke_cosmetic(p_user, r.item_id);
    end if;
  end loop;
end;
$$;
revoke all on function public.verification_sync_assets(uuid) from public, anon, authenticated;

-- Ends lapsed subscriptions: drops the tick and takes the assets back.
create or replace function public.verification_sweep()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in
    select s.user_id from public.verification_subscriptions s
     where s.expires_at <= now()
       and (exists (select 1 from public.profiles p where p.id = s.user_id and (p.verification_status = 'verified' or p.verification_tier is not null))
            or exists (select 1 from public.user_cosmetic_inventory i where i.user_id = s.user_id and i.source = 'verification'))
     limit 50
  loop
    begin
      update public.profiles set verification_status = 'unverified', verification_tier = null where id = r.user_id;
      perform public.verification_sync_assets(r.user_id);
      n := n + 1;
    exception when others then null;
    end;
  end loop;
  return n;
end;
$$;
revoke all on function public.verification_sweep() from public, anon, authenticated;

create or replace function public.comp_sweep()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  perform public.verification_sweep();
  for r in
    select c.id from public.competitions c
      join public.competition_hosting h on h.competition_id = c.id
     where c.hosted and c.status::text in ('upcoming', 'live')
       and c.ends_at + interval '7 days' < now()
       and (h.prize_status = 'held' or h.fee_status = 'collecting')
     limit 10
  loop
    begin
      perform public.comp_refund_all(r.id, 'Host did not settle in time');
      n := n + 1;
    exception when others then null;
    end;
  end loop;
  return n;
end;
$$;
grant execute on function public.comp_sweep() to authenticated;

create or replace function public.verification_ad_discount(p_user uuid)
returns integer language sql stable security definer set search_path = public as $$
  select coalesce((select t.ad_discount from public.verification_active_tier(p_user) t), 0);
$$;

-- ---------------------------------------------------------------------------
-- 5. State and subscribe
-- ---------------------------------------------------------------------------
drop function if exists public.verification_state();
create or replace function public.verification_state()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.verification_subscriptions;
  has_s boolean := false;
  t public.verification_tiers;
  v_active boolean := false;
  v_status text;
  lim public.verification_tiers;
  v_id text;
begin
  if uid is null then return null; end if;
  select * into s from public.verification_subscriptions x where x.user_id = uid;
  has_s := found;
  v_active := has_s and s.expires_at > now();
  if has_s and not v_active then
    perform public.verification_sweep();
  end if;
  select pr.verification_status::text into v_status from public.profiles pr where pr.id = uid;
  if v_active then select * into t from public.verification_tiers vt where vt.code = s.tier; end if;
  lim := public.host_limits(uid);
  select coalesce((select x.status from public.id_verifications x where x.user_id = uid), 'none') into v_id;
  return jsonb_build_object(
    'active', v_active,
    'tier', case when v_active then s.tier else null end,
    'tier_name', t.name, 'tier_rank', coalesce(t.rank, 0), 'tier_color', t.color, 'tier_price', t.price,
    'expires_at', case when has_s then s.expires_at else null end,
    'days_left', case when v_active then ceil(extract(epoch from (s.expires_at - now())) / 86400.0)::int else 0 end,
    'status', v_status,
    'host', public.is_competition_host(uid),
    'id_status', v_id,
    'limits', case when lim.code is null then null else jsonb_build_object(
        'tier', lim.code, 'max_active', lim.max_active, 'max_prize', lim.max_prize, 'max_players', lim.max_players,
        'fee_percent', lim.fee_percent, 'ad_discount', lim.ad_discount) end);
end;
$$;
grant execute on function public.verification_state() to authenticated;

-- Everything the verification screen shows: the state plus the levels and their assets.
create or replace function public.verification_overview()
returns jsonb language plpgsql security definer set search_path = public as $$
declare st jsonb; tiers jsonb;
begin
  if auth.uid() is null then return null; end if;
  st := public.verification_state();
  select coalesce(jsonb_agg(jsonb_build_object(
      'code', t.code, 'rank', t.rank, 'name', t.name, 'tagline', t.tagline, 'price', t.price, 'color', t.color,
      'max_active', t.max_active, 'max_prize', t.max_prize, 'max_players', t.max_players, 'fee_percent', t.fee_percent,
      'ad_discount', t.ad_discount, 'needs_id', t.needs_id,
      'assets', coalesce((select jsonb_agg(jsonb_build_object('category', c.category, 'name', c.name, 'rarity', c.rarity, 'asset', c.asset, 'value', c.value) order by c.sort_order)
                            from public.verification_tier_items ti join public.cosmetic_items c on c.id = ti.item_id where ti.tier = t.code), '[]'::jsonb))
      order by t.rank), '[]'::jsonb)
    into tiers from public.verification_tiers t where t.active;
  return st || jsonb_build_object('tiers', tiers);
end;
$$;
grant execute on function public.verification_overview() to authenticated;

drop function if exists public.verification_subscribe(integer);
drop function if exists public.verification_price();
create or replace function public.verification_subscribe(p_tier text, p_months integer default 1)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  v_months integer := greatest(1, least(coalesce(p_months, 1), 12));
  t public.verification_tiers;
  cur public.verification_subscriptions;
  cur_t public.verification_tiers;
  has_cur boolean := false;
  v_amount integer;
  v_credit integer := 0;
  v_base timestamptz;
  v_exp timestamptz;
  v_ref text;
  v_r jsonb;
  v_bal numeric;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  perform public.sec_rl('verify_sub', 8, 3600);
  if exists (select 1 from public.profiles pr where pr.id = uid and pr.is_banned is true) then
    return jsonb_build_object('success', false, 'error', 'This account cannot subscribe');
  end if;
  select * into t from public.verification_tiers vt where vt.code = p_tier and vt.active;
  if not found then return jsonb_build_object('success', false, 'error', 'That level is not available'); end if;
  if t.needs_id and not public.id_approved(uid) then
    return jsonb_build_object('success', false, 'error', 'This level needs an ID check first', 'needs_id', true);
  end if;

  select * into cur from public.verification_subscriptions s where s.user_id = uid for update;
  has_cur := found;
  v_base := now();
  if has_cur and cur.expires_at > now() then
    if cur.tier = t.code then
      v_base := cur.expires_at;
    else
      select * into cur_t from public.verification_tiers vt where vt.code = cur.tier;
      v_credit := floor(extract(epoch from (cur.expires_at - now())) / 86400.0 / 30.0 * coalesce(cur_t.price, 0))::int;
    end if;
  end if;
  v_amount := t.price * v_months;
  v_credit := least(v_credit, v_amount);
  v_amount := v_amount - v_credit;
  v_exp := v_base + (v_months * 30) * interval '1 day';
  v_ref := 'VERIFY_' || uid::text || '_' || floor(extract(epoch from clock_timestamp()) * 1000)::bigint::text;

  if v_amount > 0 then
    v_r := public.deduct_arena_stake(uid, v_amount, v_ref);
    if coalesce((v_r ->> 'success')::boolean, false) is not true then
      return jsonb_build_object('success', false, 'error', coalesce(v_r ->> 'error', 'Not enough balance. Please fund your wallet.'));
    end if;
  end if;
  begin
    insert into public.verification_subscriptions (user_id, tier, expires_at, months_paid, last_paid)
    values (uid, t.code, v_exp, v_months, v_amount)
    on conflict (user_id) do update
      set tier = t.code, expires_at = v_exp,
          months_paid = public.verification_subscriptions.months_paid + v_months,
          last_paid = v_amount, updated_at = now();
    update public.profiles set verification_status = 'verified', verification_tier = t.code where id = uid;
    perform public.verification_sync_assets(uid);
  exception when others then
    if v_amount > 0 then perform public.refund_arena_stake(uid, v_amount, v_ref || '_REFUND'); end if;
    return jsonb_build_object('success', false, 'error', 'Could not complete the subscription, you were not charged');
  end;
  select pr.wallet_balance into v_bal from public.profiles pr where pr.id = uid;
  return jsonb_build_object('success', true, 'tier', t.code, 'expires_at', v_exp, 'paid', v_amount, 'credit', v_credit, 'balance', v_bal);
end;
$$;
grant execute on function public.verification_subscribe(text, integer) to authenticated;

-- Back-fill: people who already subscribed before levels existed hold the first level.
update public.profiles p set verification_tier = s.tier
  from public.verification_subscriptions s where s.user_id = p.id and s.expires_at > now() and p.verification_tier is null;

-- ---------------------------------------------------------------------------
-- 6. Hosting uses the level's limits
-- ---------------------------------------------------------------------------
create or replace function public.host_create_competition(
  p_title text, p_game text, p_description text, p_rules text, p_banner_url text,
  p_platform text, p_region text, p_entry_fee integer, p_prize_pool integer, p_max integer,
  p_starts timestamptz, p_ends timestamptz, p_deadline timestamptz, p_tags text[],
  p_scope_type text default 'all', p_scope_country text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  lim public.verification_tiers;
  t text := btrim(coalesce(p_title, ''));
  g text := btrim(coalesce(p_game, ''));
  fee integer := greatest(0, coalesce(p_entry_fee, 0));
  prize integer := greatest(0, coalesce(p_prize_pool, 0));
  mx integer := coalesce(p_max, 100);
  dl timestamptz := coalesce(p_deadline, p_starts);
  cid uuid := gen_random_uuid();
  active_n integer;
  r jsonb;
  ref text;
  bal numeric;
  tags text[];
  scope text := coalesce(nullif(p_scope_type, ''), 'all');
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if not public.is_competition_host(uid) then
    return jsonb_build_object('success', false, 'error', 'Hosting is for verified members. Subscribe to verification first.');
  end if;
  lim := public.host_limits(uid);
  if lim.code is null then return jsonb_build_object('success', false, 'error', 'Hosting is for verified members. Subscribe to verification first.'); end if;
  perform public.sec_rl('host_create', 6, 3600);

  if length(t) < 4 or length(t) > 80 then return jsonb_build_object('success', false, 'error', 'The title needs 4 to 80 characters'); end if;
  if length(g) < 2 or length(g) > 60 then return jsonb_build_object('success', false, 'error', 'Enter the game name'); end if;
  if length(coalesce(p_description, '')) > 1500 then return jsonb_build_object('success', false, 'error', 'The description is too long'); end if;
  if length(coalesce(p_rules, '')) > 3000 then return jsonb_build_object('success', false, 'error', 'The rules are too long'); end if;
  if p_banner_url is not null and p_banner_url <> '' and (p_banner_url !~ '^https://' or length(p_banner_url) > 500) then
    return jsonb_build_object('success', false, 'error', 'The banner must be an uploaded image');
  end if;
  if fee <> 0 and (fee < 100 or fee > 50000) then return jsonb_build_object('success', false, 'error', 'Entry fee is 0, or between N100 and N50,000'); end if;
  if fee > 0 and not public.id_approved(uid) and not public.sec_is_admin() then
    return jsonb_build_object('success', false, 'error', 'Competitions with an entry fee need a verified ID. Complete the ID check first.', 'needs_id', true);
  end if;
  if prize > lim.max_prize then
    return jsonb_build_object('success', false, 'error', 'Your ' || lim.name || ' level allows a prize pool of up to N' || lim.max_prize);
  end if;
  if mx < 2 or mx > lim.max_players then
    return jsonb_build_object('success', false, 'error', 'Your ' || lim.name || ' level allows 2 to ' || lim.max_players || ' players');
  end if;
  if p_starts is null or p_ends is null then return jsonb_build_object('success', false, 'error', 'Pick a start and end time'); end if;
  if p_starts < now() + interval '1 hour' then return jsonb_build_object('success', false, 'error', 'Start at least 1 hour from now'); end if;
  if p_starts > now() + interval '90 days' then return jsonb_build_object('success', false, 'error', 'Start within the next 90 days'); end if;
  if p_ends <= p_starts or p_ends > p_starts + interval '30 days' then
    return jsonb_build_object('success', false, 'error', 'It must end after it starts, within 30 days');
  end if;
  if dl > p_starts then dl := p_starts; end if;
  if dl < now() then dl := p_starts; end if;
  if scope not in ('all', 'country') then scope := 'all'; end if;
  if scope = 'country' and coalesce(btrim(p_scope_country), '') = '' then
    return jsonb_build_object('success', false, 'error', 'Pick the country for a country-only competition');
  end if;

  select count(*) into active_n from public.competitions c
   where c.created_by = uid and c.hosted and c.status::text in ('upcoming', 'live');
  if active_n >= lim.max_active and not public.sec_is_admin() then
    return jsonb_build_object('success', false, 'error', 'Your ' || lim.name || ' level allows ' || lim.max_active || ' at a time. Finish one first or upgrade.');
  end if;

  select coalesce(array_agg(x), '{}') into tags
    from (select left(btrim(v), 24) as x from unnest(coalesce(p_tags, '{}')) v where btrim(v) <> '' limit 6) q;

  ref := 'HOSTPRIZE_' || cid::text;
  if prize > 0 then
    r := public.deduct_arena_stake(uid, prize, ref);
    if coalesce((r ->> 'success')::boolean, false) is not true then
      return jsonb_build_object('success', false, 'error', coalesce(r ->> 'error', 'Not enough balance to fund the prize pool'));
    end if;
  end if;

  begin
    insert into public.competitions (
      id, title, description, game_name, banner_url, created_by, is_admin_created, competition_type,
      entry_fee, prize_pool, max_participants, status, rules, platform, region, starts_at, ends_at,
      registration_deadline, platform_fee_percent, tags, scope_type, scope_country, hosted, prize_secured)
    values (
      cid, t, nullif(btrim(coalesce(p_description, '')), ''), g, nullif(p_banner_url, ''), uid, false,
      (case when fee > 0 then 'paid' else 'free' end)::competition_type,
      fee, prize, mx, 'upcoming', nullif(btrim(coalesce(p_rules, '')), ''), nullif(btrim(coalesce(p_platform, '')), ''),
      nullif(btrim(coalesce(p_region, '')), ''), p_starts, p_ends, dl, lim.fee_percent, tags, scope,
      case when scope = 'country' then btrim(p_scope_country) else null end, true, prize > 0);
    insert into public.competition_hosting (competition_id, host_id, prize_escrow, prize_status)
    values (cid, uid, prize, case when prize > 0 then 'held' else 'paid' end);
  exception when others then
    if prize > 0 then perform public.refund_arena_stake(uid, prize, ref || '_REFUND'); end if;
    return jsonb_build_object('success', false, 'error', 'Could not create the competition, you were not charged');
  end;

  select pr.wallet_balance into bal from public.profiles pr where pr.id = uid;
  return jsonb_build_object('success', true, 'id', cid, 'balance', bal);
end;
$$;
grant execute on function public.host_create_competition(text, text, text, text, text, text, text, integer, integer, integer, timestamptz, timestamptz, timestamptz, text[], text, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Admin: ad rates, ad settings, tiers
-- ---------------------------------------------------------------------------
create or replace function public.admin_pricing_get()
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  return jsonb_build_object(
    'rates', coalesce((select jsonb_agg(to_jsonb(r) order by r.cpm) from public.ad_rates r), '[]'::jsonb),
    'settings', (select to_jsonb(s) from public.ad_settings s limit 1),
    'tiers', coalesce((select jsonb_agg(to_jsonb(t) order by t.rank) from public.verification_tiers t), '[]'::jsonb),
    'pending_ads', (select count(*) from public.ad_campaigns where status = 'pending_review' and settled = false),
    'pending_ids', (select count(*) from public.id_verifications where status = 'pending'));
end;
$$;
grant execute on function public.admin_pricing_get() to authenticated;

create or replace function public.admin_set_ad_rate(p_placement text, p_cpm integer, p_cpc integer)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  if p_cpm is null or p_cpc is null or p_cpm < 1 or p_cpc < 1 or p_cpm > 10000000 or p_cpc > 1000000 then
    return jsonb_build_object('success', false, 'error', 'Enter whole naira amounts above zero');
  end if;
  update public.ad_rates set cpm = p_cpm, cpc = p_cpc where placement = p_placement;
  if not found then return jsonb_build_object('success', false, 'error', 'Unknown placement'); end if;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.admin_set_ad_rate(text, integer, integer) to authenticated;

create or replace function public.admin_set_ad_settings(p_review_first boolean, p_max_live integer, p_min_daily integer, p_max_daily integer)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  if p_max_live < 1 or p_max_live > 100 or p_min_daily < 100 or p_max_daily < p_min_daily or p_max_daily > 50000000 then
    return jsonb_build_object('success', false, 'error', 'Check the numbers: the maximum must be above the minimum');
  end if;
  update public.ad_settings
     set review_first_campaign = coalesce(p_review_first, review_first_campaign),
         max_live_per_advertiser = p_max_live, min_daily_budget = p_min_daily, max_daily_budget = p_max_daily;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.admin_set_ad_settings(boolean, integer, integer, integer) to authenticated;

create or replace function public.admin_set_tier(p_code text, p_cfg jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  begin
    update public.verification_tiers set
      name = coalesce(nullif(btrim(p_cfg ->> 'name'), ''), name),
      tagline = coalesce(p_cfg ->> 'tagline', tagline),
      price = coalesce((p_cfg ->> 'price')::int, price),
      color = coalesce(nullif(p_cfg ->> 'color', ''), color),
      max_active = coalesce((p_cfg ->> 'max_active')::int, max_active),
      max_prize = coalesce((p_cfg ->> 'max_prize')::int, max_prize),
      max_players = coalesce((p_cfg ->> 'max_players')::int, max_players),
      fee_percent = coalesce((p_cfg ->> 'fee_percent')::int, fee_percent),
      ad_discount = coalesce((p_cfg ->> 'ad_discount')::int, ad_discount),
      needs_id = coalesce((p_cfg ->> 'needs_id')::boolean, needs_id),
      active = coalesce((p_cfg ->> 'active')::boolean, active)
    where code = p_code;
  exception when others then
    return jsonb_build_object('success', false, 'error', 'One of the values is out of range');
  end;
  if not found then return jsonb_build_object('success', false, 'error', 'Unknown level'); end if;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.admin_set_tier(text, jsonb) to authenticated;
