-- Shop assets for the five new GACOM Edu games.
--
-- Each game gets its own equip slot, so a player can own a bike for Okada Run
-- and a banner for Gate Siege at the same time. A kit is only colours and a
-- couple of style words in the item's `asset` json: nothing a player buys can
-- change how a game plays, only how it looks.
--
-- Slots match the categories exactly, so CosmeticsService.slotOf() needs no
-- special case: okada, siege, current, pitch, market.
-- Run after 20261102 and 20261105.

-- ---------------------------------------------------------------------------
-- 1. The new equip slots
-- ---------------------------------------------------------------------------
alter table public.user_cosmetics add column if not exists equipped_okada uuid references public.cosmetic_items(id);
alter table public.user_cosmetics add column if not exists equipped_siege uuid references public.cosmetic_items(id);
alter table public.user_cosmetics add column if not exists equipped_current uuid references public.cosmetic_items(id);
alter table public.user_cosmetics add column if not exists equipped_pitch uuid references public.cosmetic_items(id);
alter table public.user_cosmetics add column if not exists equipped_market uuid references public.cosmetic_items(id);

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
    when 'okada' then 'equipped_okada'
    when 'siege' then 'equipped_siege'
    when 'current' then 'equipped_current'
    when 'pitch' then 'equipped_pitch'
    when 'market' then 'equipped_market'
    else null end;
  if col is null then return jsonb_build_object('success', false, 'error', 'Unknown category'); end if;
  insert into public.user_cosmetics (user_id) values (uid) on conflict (user_id) do nothing;
  execute format('update public.user_cosmetics set %I = $1, updated_at = now() where user_id = $2', col) using p_item_id, uid;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.equip_cosmetic(uuid, text) to authenticated;

-- Taking an item away must also unequip it from the new slots.
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
    equipped_okada         = case when equipped_okada         = p_item then null else equipped_okada end,
    equipped_siege         = case when equipped_siege         = p_item then null else equipped_siege end,
    equipped_current       = case when equipped_current       = p_item then null else equipped_current end,
    equipped_pitch         = case when equipped_pitch         = p_item then null else equipped_pitch end,
    equipped_market        = case when equipped_market        = p_item then null else equipped_market end,
    updated_at = now()
  where user_id = p_user;
end;
$$;

-- ---------------------------------------------------------------------------
-- 2. The catalogue
-- ---------------------------------------------------------------------------
insert into public.cosmetic_items
  (category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
select v.category, v.name, v.value, v.asset, v.price, v.rarity, v.requires_premium, v.scope, v.description, v.sort_order, v.source, nullif(v.earn_hint, '')
from (values
  -- Okada Run: bike, helmet, road and exhaust
  ('okada','Danfo Yellow','','{"accent":"#FFC233","road":"#23242B","kerb":"#3A3D47","bike":"#FFC107","helmet":"#FFF3D0","sign":"#1B6B3A","exhaust":"smoke"}'::jsonb,0,'common',false,'user','The yellow and black everyone knows.',500,'shop',''),
  ('okada','Night Rider','','{"accent":"#7C4DFF","road":"#16161C","kerb":"#2A2A36","bike":"#5E35B1","helmet":"#D1C4E9","sign":"#311B92","exhaust":"sparks"}'::jsonb,700,'rare',false,'user','Violet tank, sparks off the pipe.',501,'shop',''),
  ('okada','Harmattan Dust','','{"accent":"#FFAB40","road":"#2B2520","kerb":"#473C30","bike":"#E65100","helmet":"#FFE0B2","sign":"#4E342E","exhaust":"smoke"}'::jsonb,900,'epic',false,'user','Orange and sand, built for the dry season.',502,'shop',''),
  ('okada','Lagos Lights','','{"accent":"#00E5FF","road":"#101820","kerb":"#1C2A33","bike":"#00BCD4","helmet":"#E0F7FA","sign":"#006064","exhaust":"flame"}'::jsonb,1800,'legendary',false,'user','Chrome and cyan, with a flame on the exhaust.',503,'shop',''),
  ('okada','Lane Master','','{"accent":"#FFD54F","road":"#0E0E12","kerb":"#23232C","bike":"#212121","helmet":"#FFD54F","sign":"#1B5E20","exhaust":"flame"}'::jsonb,0,'mythic',false,'user','Black and gold. Only for riders who read the signs.',504,'earned','Pass 40 junctions in the right lane in one ride of Okada Run'),

  -- Gate Siege: wall, banner and marchers
  ('siege','Stone Keep','','{"accent":"#FFCA28","ground":"#1A1711","wall":"#5D4037","banner":"#8E24AA","marcher":"#78909C","marcher_trim":"#CFD8DC","style":"stone"}'::jsonb,0,'common',false,'user','Plain stone and a violet banner.',510,'shop',''),
  ('siege','Brass Bastion','','{"accent":"#FFD54F","ground":"#1C1810","wall":"#8D6E63","banner":"#FFB300","marcher":"#8D6E63","marcher_trim":"#FFE082","style":"brass"}'::jsonb,800,'rare',false,'user','Brass fittings and a gold banner.',511,'shop',''),
  ('siege','Emerald Watch','','{"accent":"#69F0AE","ground":"#0F1A13","wall":"#2E5339","banner":"#00897B","marcher":"#546E7A","marcher_trim":"#B2DFDB","style":"stone"}'::jsonb,1100,'epic',false,'user','Green stone, for a gate that never fell.',512,'shop',''),
  ('siege','Ember Gate','','{"accent":"#FF7043","ground":"#1A0F0C","wall":"#4E2419","banner":"#D84315","marcher":"#6D4C41","marcher_trim":"#FFCCBC","style":"ember"}'::jsonb,1900,'legendary',false,'user','Fire-scarred walls and a red banner.',513,'shop',''),
  ('siege','Prime Factor','','{"accent":"#FFECB3","ground":"#0C0C10","wall":"#263238","banner":"#FFD600","marcher":"#37474F","marcher_trim":"#FFF9C4","style":"brass"}'::jsonb,0,'mythic',false,'user','Black iron and bright gold. Earned by holding out.',514,'earned','Hold the gate to wave 10 in Gate Siege'),

  -- Word Current: river, swim ring and word tiles
  ('current','River Blue','','{"accent":"#4FC3F7","water":"#0C3A4A","deep":"#06212B","bank":"#2E4A1F","tile":"#123B52","swimmer":"#FFD166","surface":"ripple"}'::jsonb,0,'common',false,'user','Clear water and a yellow ring.',520,'shop',''),
  ('current','Green Delta','','{"accent":"#69F0AE","water":"#0D3B32","deep":"#05201B","bank":"#33691E","tile":"#114036","swimmer":"#FFF176","surface":"lily"}'::jsonb,700,'rare',false,'user','Lily pads on a slow green river.',521,'shop',''),
  ('current','White Rapids','','{"accent":"#E1F5FE","water":"#14506B","deep":"#082F40","bank":"#37474F","tile":"#0E4258","swimmer":"#FF8A65","surface":"foam"}'::jsonb,1100,'epic',false,'user','Fast water and plenty of foam.',522,'shop',''),
  ('current','Sunset Creek','','{"accent":"#FFAB91","water":"#3E2A4A","deep":"#1E1327","bank":"#4E342E","tile":"#4A2C52","swimmer":"#FFD54F","surface":"ripple"}'::jsonb,1600,'legendary',false,'user','Purple water under an evening sky.',523,'shop',''),
  ('current','Word Keeper','','{"accent":"#FFFFFF","water":"#102A43","deep":"#081B2C","bank":"#1B3A2A","tile":"#0B2237","swimmer":"#B388FF","surface":"foam"}'::jsonb,0,'mythic',false,'user','For a reader the river cannot beat.',524,'earned','Catch 30 words in one swim of Word Current'),

  -- Set Piece: kit, ball and pitch
  ('pitch','Green Park','','{"accent":"#7CFFA0","grass":"#1B5E20","grass_alt":"#225E26","kit":"#00897B","kit_trim":"#FFFFFF","ball":"#FFFFFF","keeper":"#FFB300","pattern":"classic"}'::jsonb,0,'common',false,'user','A proper pitch and a plain white ball.',530,'shop',''),
  ('pitch','Green and White','','{"accent":"#B9F6CA","grass":"#194D1F","grass_alt":"#1F5A26","kit":"#2E7D32","kit_trim":"#FFFFFF","ball":"#F5F5F5","keeper":"#FDD835","pattern":"stripes"}'::jsonb,800,'rare',false,'user','The national colours, striped.',531,'shop',''),
  ('pitch','Floodlit Night','','{"accent":"#80D8FF","grass":"#10361A","grass_alt":"#153F1F","kit":"#1A237E","kit_trim":"#80D8FF","ball":"#FFFFFF","keeper":"#FF7043","pattern":"sash"}'::jsonb,1200,'epic',false,'user','Deep blue kit under the lights.',532,'shop',''),
  ('pitch','Golden Boot','','{"accent":"#FFD54F","grass":"#14421C","grass_alt":"#1A4F22","kit":"#212121","kit_trim":"#FFD54F","ball":"#FFD54F","keeper":"#E0E0E0","pattern":"sash"}'::jsonb,2000,'legendary',false,'user','Black kit, gold ball.',533,'shop',''),
  ('pitch','Dead Ball King','','{"accent":"#FF8A80","grass":"#0F3517","grass_alt":"#14401D","kit":"#B71C1C","kit_trim":"#FFEBEE","ball":"#FF5252","keeper":"#CFD8DC","pattern":"stripes"}'::jsonb,0,'mythic',false,'user','For a player who never misses the zone.',534,'earned','Score 15 goals in one match of Set Piece'),

  -- Market Run: canopies, ground and counter
  ('market','Open Market','','{"accent":"#FFD166","ground":"#2A2119","ground_alt":"#332A20","canopy":"#EF6C00","canopy_alt":"#FFF3E0","counter":"#00695C","cloth":"stripe"}'::jsonb,0,'common',false,'user','Striped canopies on bare ground.',540,'shop',''),
  ('market','Ankara Stalls','','{"accent":"#FF8A65","ground":"#2B1F1A","ground_alt":"#35271F","canopy":"#AD1457","canopy_alt":"#FFD54F","counter":"#4527A0","cloth":"ankara"}'::jsonb,800,'rare',false,'user','Bright ankara cloth over every stall.',541,'shop',''),
  ('market','Cool Shade','','{"accent":"#80DEEA","ground":"#1F2A2E","ground_alt":"#263338","canopy":"#00838F","canopy_alt":"#E0F7FA","counter":"#006064","cloth":"plain"}'::jsonb,1000,'epic',false,'user','Plain blue shade for a hot afternoon.',542,'shop',''),
  ('market','Evening Trade','','{"accent":"#FFCC80","ground":"#1B1410","ground_alt":"#231A14","canopy":"#4E342E","canopy_alt":"#FFB74D","counter":"#BF360C","cloth":"stripe"}'::jsonb,1500,'legendary',false,'user','Lamplight and late bargains.',543,'shop',''),
  ('market','Master Trader','','{"accent":"#FFD600","ground":"#14100C","ground_alt":"#1B1611","canopy":"#212121","canopy_alt":"#FFD600","counter":"#1B5E20","cloth":"ankara"}'::jsonb,0,'mythic',false,'user','Black and gold, for a trader who counts right every time.',544,'earned','Finish a market day with 20,000 naira profit in Market Run')
) as v(category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
where not exists (select 1 from public.cosmetic_items c where c.category = v.category and c.name = v.name);

notify pgrst, 'reload schema';
