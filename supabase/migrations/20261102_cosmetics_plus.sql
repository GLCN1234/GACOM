-- Cosmetics, part two.
--   1. New slots: emote, spray, finisher (drawn in code, asset json {kind,color,color2})
--   2. Evolving skins: a weapon or outfit grows through three stages as you play
--   3. Gifting: buy a shop item for another player
--   4. Starter pack: one-time discounted bundle for new players
--   5. First purchase bonus: your first buy unlocks exclusive items (no wallet credit is minted)
--   6. New catalogue: frames, titles, emotes, sprays, finishers, house cosmetics
-- Run after 20261013, 20261014, 20261031.

-- ---------------------------------------------------------------------------
-- 1. New equip slots
-- ---------------------------------------------------------------------------
alter table public.user_cosmetics add column if not exists equipped_emote uuid references public.cosmetic_items(id);
alter table public.user_cosmetics add column if not exists equipped_spray uuid references public.cosmetic_items(id);
alter table public.user_cosmetics add column if not exists equipped_finisher uuid references public.cosmetic_items(id);

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
    when 'weapon_skin' then 'equipped_weapon'
    when 'emote' then 'equipped_emote'
    when 'spray' then 'equipped_spray'
    when 'finisher' then 'equipped_finisher'
    else null end;
  if col is null then return jsonb_build_object('success', false, 'error', 'Unknown category'); end if;
  insert into public.user_cosmetics (user_id) values (uid) on conflict (user_id) do nothing;
  execute format('update public.user_cosmetics set %I = $1, updated_at = now() where user_id = $2', col) using p_item_id, uid;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.equip_cosmetic(uuid, text) to authenticated;

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
    equipped_weapon        = case when equipped_weapon        = p_item then null else equipped_weapon end,
    equipped_emote         = case when equipped_emote         = p_item then null else equipped_emote end,
    equipped_spray         = case when equipped_spray         = p_item then null else equipped_spray end,
    equipped_finisher      = case when equipped_finisher      = p_item then null else equipped_finisher end,
    updated_at = now()
  where user_id = p_user;
end;
$$;
revoke all on function public.revoke_cosmetic(uuid, uuid) from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 2. Catalogue (inserted only when the same category + name is not there yet)
-- ---------------------------------------------------------------------------
insert into public.cosmetic_items
  (category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
select v.category, v.name, v.value, v.asset, v.price, v.rarity, v.requires_premium, v.scope, v.description, v.sort_order, v.source, nullif(v.earn_hint, '')
from (values
  -- frames
  ('avatar_frame','Neon Crest','','{"style":"crest","colors":["#00E5FF","#7C4DFF"]}'::jsonb,700,'rare',false,'user','A cyan and violet crest ring.',200,'shop',''),
  ('avatar_frame','Ember Circuit','','{"style":"circuit","colors":["#FF6A00","#FFD166"]}'::jsonb,1200,'epic',false,'user','Glowing circuit traces in ember orange.',201,'shop',''),
  ('avatar_frame','Adire Royal','','{"style":"adire","colors":["#3D5AFE","#E8EAF6"]}'::jsonb,1200,'epic',false,'user','Indigo adire pattern.',202,'shop',''),
  ('avatar_frame','Vault Platinum','','{"style":"vault","colors":["#B0BEC5","#ECEFF1"]}'::jsonb,2200,'legendary',false,'user','A heavy platinum vault ring.',203,'shop',''),
  ('avatar_frame','Stormline','','{"style":"voltage","colors":["#7DF9FF","#2979FF"]}'::jsonb,2500,'legendary',false,'user','Live current runs round the ring.',204,'shop',''),
  -- titles
  ('title','Fresh Blood','Fresh Blood','{}'::jsonb,300,'common',false,'user','Everyone starts somewhere.',200,'shop',''),
  ('title','Night Runner','Night Runner','{}'::jsonb,600,'rare',false,'user','For the late shift in Darkom.',201,'shop',''),
  ('title','Darkom Ghost','Darkom Ghost','{}'::jsonb,1000,'epic',false,'user','Seen by no one.',202,'shop',''),
  ('title','Unbroken','Unbroken','{}'::jsonb,1800,'legendary',false,'user','Never lost a stand.',203,'shop',''),
  ('title','Day One Patron','Day One Patron','{}'::jsonb,0,'rare',false,'user','First purchase bonus.',900,'earned','Make your first purchase in the shop'),
  -- emotes
  ('emote','Heartbeat','heart','{"kind":"heart","color":"#FF4F7B"}'::jsonb,200,'common',false,'user','Show some love.',300,'shop',''),
  ('emote','Good Laugh','laugh','{"kind":"laugh","color":"#FFD43B"}'::jsonb,200,'common',false,'user','Tears and all.',301,'shop',''),
  ('emote','GG','gg','{"kind":"gg","color":"#4FD6C8"}'::jsonb,400,'rare',false,'user','Good game.',302,'shop',''),
  ('emote','On Fire','flame','{"kind":"flame","color":"#FF7A1A"}'::jsonb,400,'rare',false,'user','You are hot right now.',303,'shop',''),
  ('emote','Bolt','bolt','{"kind":"bolt","color":"#FFE45C"}'::jsonb,400,'rare',false,'user','Quick as lightning.',304,'shop',''),
  ('emote','Crown Me','crown','{"kind":"crown","color":"#FFC53D"}'::jsonb,800,'epic',false,'user','Bow down.',305,'shop',''),
  ('emote','Skull Out','skull','{"kind":"skull","color":"#E8ECF4"}'::jsonb,800,'epic',false,'user','Gone.',306,'shop',''),
  ('emote','Trophy Shot','trophy','{"kind":"trophy","color":"#FFD166"}'::jsonb,1500,'legendary',false,'user','Lift it high.',307,'shop',''),
  ('emote','Gold GG','gg','{"kind":"gg","color":"#FFC53D"}'::jsonb,0,'epic',false,'user','First purchase bonus.',901,'earned','Make your first purchase in the shop'),
  -- sprays
  ('spray','Star Tag','star','{"kind":"star","color":"#FFD166"}'::jsonb,200,'common',false,'user','A quick star.',400,'shop',''),
  ('spray','Heart Tag','heart','{"kind":"heart","color":"#FF4F7B"}'::jsonb,200,'common',false,'user','Spray some love.',401,'shop',''),
  ('spray','Bolt Stencil','bolt','{"kind":"bolt","color":"#35E0FF"}'::jsonb,400,'rare',false,'user','Electric blue stencil.',402,'shop',''),
  ('spray','Flame Tag','flame','{"kind":"flame","color":"#FF6A00"}'::jsonb,400,'rare',false,'user','Burning orange.',403,'shop',''),
  ('spray','Skull Tag','skull','{"kind":"skull","color":"#E8ECF4"}'::jsonb,500,'rare',false,'user','Bone white.',404,'shop',''),
  ('spray','Crown Tag','crown','{"kind":"crown","color":"#FFC53D"}'::jsonb,800,'epic',false,'user','Mark your turf.',405,'shop',''),
  ('spray','Eye Tag','eye','{"kind":"eye","color":"#B060FF"}'::jsonb,800,'epic',false,'user','Always watching.',406,'shop',''),
  ('spray','Gilded G','g','{"kind":"g","color":"#FFC53D"}'::jsonb,0,'epic',false,'user','First purchase bonus.',902,'earned','Make your first purchase in the shop'),
  -- finishers
  ('finisher','Shockwave','shockwave','{"kind":"shockwave","color":"#35E0FF","color2":"#FFFFFF"}'::jsonb,800,'rare',false,'user','Rings of force on every win.',500,'shop',''),
  ('finisher','Embers','embers','{"kind":"embers","color":"#FF6A00","color2":"#FFE08A"}'::jsonb,800,'rare',false,'user','Rising sparks.',501,'shop',''),
  ('finisher','Chain Lightning','lightning','{"kind":"lightning","color":"#7DF9FF","color2":"#FFFFFF"}'::jsonb,1200,'epic',false,'user','Forked bolts that fan out.',502,'shop',''),
  ('finisher','Blade Storm','slash','{"kind":"slash","color":"#FF4F66","color2":"#FFFFFF"}'::jsonb,1200,'epic',false,'user','Three clean cuts.',503,'shop',''),
  ('finisher','Supernova','nova','{"kind":"nova","color":"#B060FF","color2":"#FFD1FF"}'::jsonb,2000,'legendary',false,'user','A star goes off.',504,'shop',''),
  ('finisher','Fireworks','fireworks','{"kind":"fireworks","color":"#FFC53D","color2":"#FF4F7B"}'::jsonb,2000,'legendary',false,'user','Celebrate in style.',505,'shop',''),
  -- evolving skins: Ember Blade (weapon) and Street Phantom (outfit)
  ('weapon_skin','Ember Blade','sword','{"weapon":"sword","metal":"#FF8A3D","hi":"#FFE0B0","ex":"#8A2B0B","w":"#2A1608","glow":"#FF6A00"}'::jsonb,600,'rare',false,'user','Starts as warm steel. Grows as you clear Darkom missions.',60,'shop',''),
  ('weapon_skin','Ember Blade II','sword','{"weapon":"sword","metal":"#FF5A1F","hi":"#FFD2A8","ex":"#B3220A","w":"#2A1608","glow":"#FF3B00"}'::jsonb,0,'epic',false,'user','Stage two of the Ember Blade.',61,'earned','Evolve the Ember Blade: earn 2,500 Darkom points while it is equipped'),
  ('weapon_skin','Ember Blade Infernal','sword','{"weapon":"sword","metal":"#1A0A0A","hi":"#FF3B00","ex":"#FFB347","w":"#120808","glow":"#FF2200"}'::jsonb,0,'legendary',false,'user','Final stage of the Ember Blade.',62,'earned','Evolve the Ember Blade: earn 9,000 Darkom points while it is equipped'),
  ('hero_outfit','Street Phantom','','{"shirt":"#3A3F55","pants":"#1B1E2B","skin":"#F2B785","hair":"#2B1B12","hair_style":"low"}'::jsonb,700,'rare',false,'user','Starts plain. Grows as you clear Darkom missions.',60,'shop',''),
  ('hero_outfit','Street Phantom II','','{"shirt":"#4B2A7A","pants":"#1B1E2B","skin":"#F2B785","hair":"#B060FF","hair_style":"low"}'::jsonb,0,'epic',false,'user','Stage two of the Street Phantom.',61,'earned','Evolve the Street Phantom: earn 2,500 Darkom points while it is equipped'),
  ('hero_outfit','Street Phantom Prime','','{"shirt":"#0E1220","pants":"#0A0C14","skin":"#F2B785","hair":"#00E5FF","hair_style":"low"}'::jsonb,0,'legendary',false,'user','Final stage of the Street Phantom.',62,'earned','Evolve the Street Phantom: earn 9,000 Darkom points while it is equipped'),
  -- house cosmetics (bought by the captain)
  ('house_emblem','Crown','draw:crown','{}'::jsonb,900,'epic',false,'house','A drawn crown crest.',40,'shop',''),
  ('house_emblem','Skull','draw:skull','{}'::jsonb,900,'epic',false,'house','A drawn skull crest.',41,'shop',''),
  ('house_emblem','Eye','draw:eye','{}'::jsonb,900,'epic',false,'house','A drawn all-seeing eye.',42,'shop',''),
  ('house_emblem','Star','draw:star','{}'::jsonb,600,'rare',false,'house','A drawn star crest.',43,'shop',''),
  ('house_emblem','Heart','draw:heart','{}'::jsonb,600,'rare',false,'house','A drawn heart crest.',44,'shop',''),
  ('house_emblem','Cup','draw:trophy','{}'::jsonb,1400,'legendary',false,'house','A drawn trophy crest.',45,'shop',''),
  ('house_banner','Crimson Dawn','','{"from":"#B71C1C","to":"#FF8A65"}'::jsonb,700,'rare',false,'house','Red fading to peach.',40,'shop',''),
  ('house_banner','Emerald Vault','','{"from":"#004D40","to":"#00E676"}'::jsonb,900,'epic',false,'house','Deep green.',41,'shop',''),
  ('house_banner','Royal Violet','','{"from":"#311B92","to":"#E040FB"}'::jsonb,900,'epic',false,'house','Violet royalty.',42,'shop',''),
  ('house_banner','Arctic','','{"from":"#01579B","to":"#E1F5FE"}'::jsonb,900,'epic',false,'house','Ice blue.',43,'shop',''),
  ('house_banner','Obsidian Gold','','{"from":"#0D0D0D","to":"#FFB300"}'::jsonb,2000,'legendary',false,'house','Black and gold.',44,'shop','')
) as v(category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
where not exists (select 1 from public.cosmetic_items c where c.category = v.category and c.name = v.name);

-- ---------------------------------------------------------------------------
-- 3. Evolving skins
-- ---------------------------------------------------------------------------
create table if not exists public.cosmetic_evolutions (
  chain text not null,
  stage integer not null check (stage between 1 and 5),
  item_id uuid not null references public.cosmetic_items(id) on delete cascade,
  xp_needed integer not null default 0 check (xp_needed >= 0),
  primary key (chain, stage),
  unique (item_id)
);
alter table public.cosmetic_evolutions enable row level security;
drop policy if exists "anyone views evolutions" on public.cosmetic_evolutions;
create policy "anyone views evolutions" on public.cosmetic_evolutions for select using (true);

create table if not exists public.user_evolution_xp (
  user_id uuid not null references auth.users(id) on delete cascade,
  chain text not null,
  xp bigint not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, chain)
);
alter table public.user_evolution_xp enable row level security;
drop policy if exists "own evolution xp" on public.user_evolution_xp;
create policy "own evolution xp" on public.user_evolution_xp for select using (user_id = auth.uid());
revoke insert, update, delete on public.cosmetic_evolutions, public.user_evolution_xp from anon, authenticated;

insert into public.cosmetic_evolutions (chain, stage, item_id, xp_needed)
select x.chain, x.stage, c.id, x.xp
from (values
  ('ember_blade', 1, 'weapon_skin', 'Ember Blade', 0),
  ('ember_blade', 2, 'weapon_skin', 'Ember Blade II', 2500),
  ('ember_blade', 3, 'weapon_skin', 'Ember Blade Infernal', 9000),
  ('street_phantom', 1, 'hero_outfit', 'Street Phantom', 0),
  ('street_phantom', 2, 'hero_outfit', 'Street Phantom II', 2500),
  ('street_phantom', 3, 'hero_outfit', 'Street Phantom Prime', 9000)
) as x(chain, stage, cat, nm, xp)
join public.cosmetic_items c on c.category = x.cat and c.name = x.nm
on conflict do nothing;

-- Adds experience to every evolving skin the player is wearing, unlocks the
-- stages it reaches and moves the equipped slot up to the newest stage.
create or replace function public.evo_add_xp(p_user uuid, p_amount integer)
returns void language plpgsql security definer set search_path = public as $$
declare
  uc record;
  slot_item uuid;
  ch text;
  newxp bigint;
  ev record;
  top_item uuid;
begin
  if p_amount is null or p_amount <= 0 then return; end if;
  select equipped_weapon, equipped_hero_outfit into uc from public.user_cosmetics where user_id = p_user;
  if not found then return; end if;
  foreach slot_item in array array[uc.equipped_weapon, uc.equipped_hero_outfit] loop
    if slot_item is null then continue; end if;
    ch := null;
    select e.chain into ch from public.cosmetic_evolutions e where e.item_id = slot_item;
    if ch is null then continue; end if;
    insert into public.user_evolution_xp (user_id, chain, xp) values (p_user, ch, p_amount)
    on conflict (user_id, chain) do update set xp = public.user_evolution_xp.xp + p_amount, updated_at = now()
    returning xp into newxp;
    for ev in select * from public.cosmetic_evolutions where chain = ch and stage > 1 and xp_needed <= newxp order by stage loop
      if public.grant_cosmetic(p_user, ev.item_id, 'earned', 'evo:' || ch || ':' || ev.stage) then
        perform public.identity_notify(p_user, 'Your skin evolved',
          (select name from public.cosmetic_items where id = ev.item_id) || ' is unlocked and equipped.',
          jsonb_build_object('kind', 'evolution', 'chain', ch, 'stage', ev.stage));
      end if;
    end loop;
    top_item := null;
    select e.item_id into top_item from public.cosmetic_evolutions e
      where e.chain = ch and e.xp_needed <= newxp order by e.stage desc limit 1;
    if top_item is not null and top_item <> slot_item then
      update public.user_cosmetics set
        equipped_weapon = case when equipped_weapon = slot_item then top_item else equipped_weapon end,
        equipped_hero_outfit = case when equipped_hero_outfit = slot_item then top_item else equipped_hero_outfit end,
        updated_at = now()
      where user_id = p_user;
    end if;
  end loop;
end;
$$;
revoke all on function public.evo_add_xp(uuid, integer) from public, anon, authenticated;

create or replace function public.evo_from_game_scores()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.game_name = 'Darkom City' and coalesce(new.score, 0) > 0 then
    perform public.evo_add_xp(new.user_id, least(new.score, 400));
  end if;
  return new;
exception when others then
  return new;
end;
$$;
revoke all on function public.evo_from_game_scores() from public, anon, authenticated;
drop trigger if exists evo_from_game_scores on public.game_scores;
create trigger evo_from_game_scores after insert on public.game_scores
  for each row execute function public.evo_from_game_scores();

-- Chains the player has started (owns the first stage), with progress.
create or replace function public.my_evolutions()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid(); res jsonb;
begin
  if uid is null then return '[]'::jsonb; end if;
  select coalesce(jsonb_agg(row_to_json(t)::jsonb order by t.chain), '[]'::jsonb) into res from (
    select e1.chain,
           coalesce((select xp from public.user_evolution_xp u where u.user_id = uid and u.chain = e1.chain), 0) as xp,
           (select jsonb_agg(jsonb_build_object(
                'stage', e.stage, 'xp_needed', e.xp_needed, 'item', public.cosmetic_json(ci, uid)) order by e.stage)
              from public.cosmetic_evolutions e join public.cosmetic_items ci on ci.id = e.item_id
             where e.chain = e1.chain) as stages
      from (select distinct chain from public.cosmetic_evolutions) e1
     where exists (
       select 1 from public.cosmetic_evolutions e2
        where e2.chain = e1.chain and public.cosmetic_is_owned(uid, e2.item_id))
  ) t;
  return res;
end;
$$;
grant execute on function public.my_evolutions() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. First purchase bonus
-- ---------------------------------------------------------------------------
create table if not exists public.first_purchase_bonus (
  user_id uuid primary key references auth.users(id) on delete cascade,
  via text not null default 'shop',
  at timestamptz not null default now()
);
alter table public.first_purchase_bonus enable row level security;
drop policy if exists "own first purchase" on public.first_purchase_bonus;
create policy "own first purchase" on public.first_purchase_bonus for select using (user_id = auth.uid());
revoke insert, update, delete on public.first_purchase_bonus from anon, authenticated;

create or replace function public.first_purchase_award(p_user uuid, p_via text)
returns void language plpgsql security definer set search_path = public as $$
declare n integer; it record;
begin
  insert into public.first_purchase_bonus (user_id, via) values (p_user, coalesce(p_via, 'shop'))
  on conflict (user_id) do nothing;
  get diagnostics n = row_count;
  if n = 0 then return; end if;
  for it in select id from public.cosmetic_items
             where (category, name) in (('title', 'Day One Patron'), ('emote', 'Gold GG'), ('spray', 'Gilded G')) loop
    perform public.grant_cosmetic(p_user, it.id, 'bonus', 'first_purchase');
  end loop;
  perform public.identity_notify(p_user, 'First purchase bonus',
    'Thank you for your first purchase. A title, an emote and a spray have been added to your locker.',
    jsonb_build_object('kind', 'first_purchase'));
exception when others then
  null;
end;
$$;
revoke all on function public.first_purchase_award(uuid, text) from public, anon, authenticated;

create or replace function public.first_purchase_from_inventory()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.source = 'purchase' then
    perform public.first_purchase_award(new.user_id, 'shop');
  end if;
  return new;
exception when others then
  return new;
end;
$$;
revoke all on function public.first_purchase_from_inventory() from public, anon, authenticated;
drop trigger if exists first_purchase_from_inventory on public.user_cosmetic_inventory;
create trigger first_purchase_from_inventory after insert on public.user_cosmetic_inventory
  for each row execute function public.first_purchase_from_inventory();

create or replace function public.first_purchase_from_pass()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if new.premium is true and (tg_op = 'INSERT' or old.premium is not true) then
    perform public.first_purchase_award(new.user_id, 'pass');
  end if;
  return new;
exception when others then
  return new;
end;
$$;
revoke all on function public.first_purchase_from_pass() from public, anon, authenticated;
drop trigger if exists first_purchase_from_pass on public.pass_progress;
create trigger first_purchase_from_pass after insert or update of premium on public.pass_progress
  for each row execute function public.first_purchase_from_pass();

-- What the shop banner shows.
create or replace function public.first_purchase_state()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return null; end if;
  return jsonb_build_object(
    'claimed', exists (select 1 from public.first_purchase_bonus where user_id = uid),
    'items', coalesce((select jsonb_agg(public.cosmetic_json(c, uid) order by c.sort_order) from public.cosmetic_items c
        where (c.category, c.name) in (('title', 'Day One Patron'), ('emote', 'Gold GG'), ('spray', 'Gilded G'))), '[]'::jsonb));
end;
$$;
grant execute on function public.first_purchase_state() to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Starter pack (one per player, 72 hours from the first time the shop shows it)
-- ---------------------------------------------------------------------------
create table if not exists public.starter_offer_log (
  user_id uuid primary key references auth.users(id) on delete cascade,
  first_seen timestamptz not null default now(),
  purchased_at timestamptz,
  paid integer
);
alter table public.starter_offer_log enable row level security;
drop policy if exists "own starter log" on public.starter_offer_log;
create policy "own starter log" on public.starter_offer_log for select using (user_id = auth.uid());
revoke insert, update, delete on public.starter_offer_log from anon, authenticated;

-- Inactive so it never shows in the normal bundle list; the starter functions read it directly.
insert into public.cosmetic_bundles (name, description, discount_percent, is_active, sort_order)
values ('Starter Pack', 'A frame, an emote, a spray, a title and a banner at 60% off. One time only.', 60, false, -1)
on conflict (name) do nothing;

insert into public.cosmetic_bundle_items (bundle_id, item_id)
select b.id, c.id
from public.cosmetic_bundles b
join public.cosmetic_items c on (c.category, c.name) in (
  ('avatar_frame', 'Neon Crest'), ('emote', 'GG'), ('spray', 'Bolt Stencil'),
  ('title', 'Fresh Blood'), ('profile_banner', 'Aurora'))
where b.name = 'Starter Pack'
on conflict do nothing;

create or replace function public.starter_offer()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  b public.cosmetic_bundles;
  lg public.starter_offer_log;
  full_price integer;
  n integer;
  items jsonb;
  ends timestamptz;
begin
  if uid is null then return null; end if;
  select * into b from public.cosmetic_bundles where name = 'Starter Pack';
  if not found then return null; end if;
  insert into public.starter_offer_log (user_id) values (uid) on conflict (user_id) do nothing;
  select * into lg from public.starter_offer_log where user_id = uid;
  if lg.purchased_at is not null then return null; end if;
  ends := lg.first_seen + interval '72 hours';
  if ends < now() then return null; end if;

  select coalesce(sum(c.price), 0), count(*),
         coalesce(jsonb_agg(public.cosmetic_json(c, uid) order by c.sort_order), '[]'::jsonb)
    into full_price, n, items
    from public.cosmetic_bundle_items bi join public.cosmetic_items c on c.id = bi.item_id
   where bi.bundle_id = b.id and c.is_active
     and not exists (select 1 from public.user_cosmetic_inventory i where i.user_id = uid and i.item_id = c.id);
  if n = 0 then return null; end if;

  return jsonb_build_object(
    'bundle_id', b.id, 'name', b.name, 'description', b.description,
    'discount', b.discount_percent, 'full_price', full_price,
    'price', ceil(full_price * (100 - b.discount_percent) / 100.0)::int,
    'ends_at', ends, 'items', items);
end;
$$;
grant execute on function public.starter_offer() to authenticated;

create or replace function public.purchase_starter()
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  b public.cosmetic_bundles;
  lg public.starter_offer_log;
  full_price integer;
  n integer;
  amount integer;
  r jsonb;
  bal numeric;
  ref text;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  perform public.sec_rl('starter_buy', 5, 300);
  select * into b from public.cosmetic_bundles where name = 'Starter Pack';
  if not found then return jsonb_build_object('success', false, 'error', 'The starter pack is not available'); end if;
  select * into lg from public.starter_offer_log where user_id = uid for update;
  if not found or lg.purchased_at is not null or lg.first_seen + interval '72 hours' < now() then
    return jsonb_build_object('success', false, 'error', 'The starter pack offer has ended');
  end if;

  select coalesce(sum(c.price), 0), count(*) into full_price, n
    from public.cosmetic_bundle_items bi join public.cosmetic_items c on c.id = bi.item_id
   where bi.bundle_id = b.id and c.is_active
     and not exists (select 1 from public.user_cosmetic_inventory i where i.user_id = uid and i.item_id = c.id);
  if n = 0 then return jsonb_build_object('success', false, 'error', 'You already own everything in this pack'); end if;

  amount := ceil(full_price * (100 - b.discount_percent) / 100.0)::int;
  ref := 'STARTER_' || uid::text;
  r := public.deduct_arena_stake(uid, amount, ref);
  if coalesce((r ->> 'success')::boolean, false) is not true then
    return jsonb_build_object('success', false, 'error', coalesce(r ->> 'error', 'Not enough balance'));
  end if;

  begin
    insert into public.user_cosmetic_inventory (user_id, item_id, source, source_ref, price_paid)
    select uid, c.id, 'purchase', 'starter', ceil(c.price * (100 - b.discount_percent) / 100.0)::int
      from public.cosmetic_bundle_items bi join public.cosmetic_items c on c.id = bi.item_id
     where bi.bundle_id = b.id and c.is_active
    on conflict (user_id, item_id) do nothing;
    update public.starter_offer_log set purchased_at = now(), paid = amount where user_id = uid;
  exception when others then
    perform public.refund_arena_stake(uid, amount, ref || '_REFUND');
    return jsonb_build_object('success', false, 'error', 'Could not complete the purchase, you were not charged');
  end;

  perform public.grant_set_bonuses(uid);
  select wallet_balance into bal from public.profiles where id = uid;
  return jsonb_build_object('success', true, 'balance', bal, 'paid', amount, 'items', n);
end;
$$;
grant execute on function public.purchase_starter() to authenticated;

-- ---------------------------------------------------------------------------
-- 6. Gifting
-- ---------------------------------------------------------------------------
create table if not exists public.cosmetic_gifts (
  id uuid primary key default gen_random_uuid(),
  from_user uuid not null references auth.users(id) on delete cascade,
  to_user uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null references public.cosmetic_items(id) on delete cascade,
  price integer not null default 0,
  message text,
  created_at timestamptz not null default now()
);
create index if not exists cosmetic_gifts_to_idx on public.cosmetic_gifts (to_user, created_at desc);
alter table public.cosmetic_gifts enable row level security;
drop policy if exists "gift parties view" on public.cosmetic_gifts;
create policy "gift parties view" on public.cosmetic_gifts for select using (auth.uid() in (from_user, to_user));
revoke insert, update, delete on public.cosmetic_gifts from anon, authenticated;

-- Find a player to gift: username prefix, never yourself, never private accounts.
create or replace function public.search_gift_target(p_query text)
returns table (id uuid, username text, display_name text, avatar_url text)
language plpgsql security definer set search_path = public as $$
declare q text := lower(trim(coalesce(p_query, '')));
begin
  if auth.uid() is null then return; end if;
  if length(q) < 2 then return; end if;
  perform public.sec_rl('gift_search', 30, 60);
  q := replace(replace(replace(q, '\', ''), '%', ''), '_', '');
  return query
    select p.id, p.username::text, p.display_name::text, p.avatar_url::text
      from public.profiles p
     where p.id <> auth.uid() and coalesce(p.is_private, false) = false
       and (lower(p.username) like q || '%' or lower(coalesce(p.display_name, '')) like q || '%')
     order by p.username
     limit 8;
end;
$$;
grant execute on function public.search_gift_target(text) to authenticated;

create or replace function public.gift_cosmetic(p_item uuid, p_to uuid, p_message text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  it public.cosmetic_items;
  amount integer;
  r jsonb;
  bal numeric;
  ref text;
  msg text;
  sender text;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_to is null or p_to = uid then return jsonb_build_object('success', false, 'error', 'Pick another player to gift'); end if;
  perform public.sec_rl('gift_send', 10, 3600);
  if not exists (select 1 from public.profiles where id = p_to) then
    return jsonb_build_object('success', false, 'error', 'Player not found');
  end if;
  select * into it from public.cosmetic_items where id = p_item;
  if not found or not it.is_active or it.scope <> 'user' or it.source <> 'shop' or it.price <= 0 or it.requires_premium then
    return jsonb_build_object('success', false, 'error', 'This item cannot be gifted');
  end if;
  if it.available_until is not null and it.available_until < now() then
    return jsonb_build_object('success', false, 'error', 'This item is no longer on sale');
  end if;
  if public.cosmetic_is_owned(p_to, p_item) then
    return jsonb_build_object('success', false, 'error', 'They already have this item');
  end if;

  amount := public.cosmetic_effective_price(p_item);
  msg := left(regexp_replace(trim(coalesce(p_message, '')), '[[:cntrl:]]', ' ', 'g'), 140);
  ref := 'GIFT_' || p_item::text || '_' || uid::text || '_' || p_to::text || '_' || extract(epoch from clock_timestamp())::bigint::text;
  r := public.deduct_arena_stake(uid, amount, ref);
  if coalesce((r ->> 'success')::boolean, false) is not true then
    return jsonb_build_object('success', false, 'error', coalesce(r ->> 'error', 'Not enough balance'));
  end if;

  begin
    insert into public.user_cosmetic_inventory (user_id, item_id, source, source_ref, price_paid)
    values (p_to, p_item, 'gift', 'gift:' || uid::text, 0);
    insert into public.cosmetic_gifts (from_user, to_user, item_id, price, message)
    values (uid, p_to, p_item, amount, nullif(msg, ''));
  exception when others then
    perform public.refund_arena_stake(uid, amount, ref || '_REFUND');
    return jsonb_build_object('success', false, 'error', 'Could not send the gift, you were not charged');
  end;

  select coalesce(display_name, username, 'A player') into sender from public.profiles where id = uid;
  perform public.identity_notify(p_to, 'You received a gift',
    sender || ' gave you ' || it.name || case when msg <> '' then ': ' || msg else '.' end,
    jsonb_build_object('kind', 'gift', 'item', p_item, 'from', uid));
  perform public.grant_set_bonuses(p_to);
  perform public.first_purchase_award(uid, 'gift');
  select wallet_balance into bal from public.profiles where id = uid;
  return jsonb_build_object('success', true, 'balance', bal, 'paid', amount);
end;
$$;
grant execute on function public.gift_cosmetic(uuid, uuid, text) to authenticated;
