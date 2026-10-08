-- Weapon skins (cosmetic only, shown on duel victory screens and in the
-- locker) and the six starter heroes. Weapons never change gameplay.

alter table public.user_cosmetics add column if not exists equipped_weapon uuid references public.cosmetic_items(id);

-- equip_cosmetic gains the 'weapon_skin' category
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
    else null end;
  if col is null then return jsonb_build_object('success', false, 'error', 'Unknown category'); end if;
  insert into public.user_cosmetics (user_id) values (uid) on conflict (user_id) do nothing;
  execute format('update public.user_cosmetics set %I = $1, updated_at = now() where user_id = $2', col) using p_item_id, uid;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.equip_cosmetic(uuid, text) to authenticated;

-- revoke_cosmetic also clears the weapon slot
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
    updated_at = now()
  where user_id = p_user;
end;
$$;
revoke all on function public.revoke_cosmetic(uuid, uuid) from public, anon, authenticated;

-- Weapon skins. asset: weapon (hammer|dagger|shield|sword|staff|axe), metal, hi, ex (trim), w (handle), glow (hex, optional)
insert into public.cosmetic_items
  (category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
select * from (values
  ('weapon_skin','Hammer','hammer','{"weapon":"hammer","metal":"#98A4B8","hi":"#B8C4D8","ex":"#6B7790","w":"#7A4A2B"}'::jsonb,0,'common',false,'user','Plain steel. Heavy hitter.',1,'shop',null),
  ('weapon_skin','Frostbite Hammer','hammer','{"weapon":"hammer","metal":"#6EC8FF","hi":"#C9E5FF","ex":"#1F5FA8","w":"#2D3748","glow":"#3C9DFF"}'::jsonb,400,'rare',false,'user','Icy blue edge light.',2,'shop',null),
  ('weapon_skin','Voidforged Hammer','hammer','{"weapon":"hammer","metal":"#4A2A7A","hi":"#B060FF","ex":"#D9A8FF","w":"#1A1030","glow":"#B060FF"}'::jsonb,800,'epic',false,'user','A violet sheen sweeps across it.',3,'shop',null),
  ('weapon_skin','Solar Forge Hammer','hammer','{"weapon":"hammer","metal":"#FFB11F","hi":"#FFF1B8","ex":"#C2410C","w":"#3A2A0C","glow":"#FFB11F"}'::jsonb,1500,'legendary',false,'user','Gold plate and ember sparks.',4,'shop',null),
  ('weapon_skin','Voltage Hammer','hammer','{"weapon":"hammer","metal":"#2A0E14","hi":"#FF4F66","ex":"#FFD1D8","w":"#161B26","glow":"#FF4F66"}'::jsonb,0,'mythic',false,'user','Arcs of red lightning. Never sold.',5,'earned','Win the Agon finale'),
  ('weapon_skin','Dagger','dagger','{"weapon":"dagger","metal":"#98A4B8","hi":"#B8C4D8","ex":"#6B7790","w":"#7A4A2B"}'::jsonb,0,'common',false,'user','Fast and light.',10,'shop',null),
  ('weapon_skin','Cyan Dagger','dagger','{"weapon":"dagger","metal":"#6EE7F2","hi":"#D6FAFD","ex":"#1E9FB0","w":"#1B2A41","glow":"#2ED3E6"}'::jsonb,400,'rare',false,'user','Edge lit in cyan.',11,'shop',null),
  ('weapon_skin','Sword','sword','{"weapon":"sword","metal":"#98A4B8","hi":"#B8C4D8","ex":"#6B7790","w":"#7A4A2B"}'::jsonb,0,'common',false,'user','The all-rounder.',20,'shop',null),
  ('weapon_skin','Emerald Sword','sword','{"weapon":"sword","metal":"#4BD37B","hi":"#C8F5D8","ex":"#14532D","w":"#1F2D24","glow":"#4BD37B"}'::jsonb,500,'rare',false,'user','Green steel.',21,'shop',null),
  ('weapon_skin','Shield','shield','{"weapon":"shield","metal":"#98A4B8","hi":"#B8C4D8","ex":"#2ED3E6","w":"#7A4A2B"}'::jsonb,0,'common',false,'user','Defender.',30,'shop',null),
  ('weapon_skin','Gold Shield','shield','{"weapon":"shield","metal":"#FFB11F","hi":"#FFF1B8","ex":"#C2410C","w":"#3A2A0C","glow":"#FFB11F"}'::jsonb,1200,'legendary',false,'user','Heavy gold.',31,'shop',null),
  ('weapon_skin','Staff','staff','{"weapon":"staff","metal":"#98A4B8","hi":"#B8C4D8","ex":"#6B7790","w":"#7A4A2B"}'::jsonb,0,'common',false,'user','Scholar focus.',40,'shop',null),
  ('weapon_skin','Violet Staff','staff','{"weapon":"staff","metal":"#B060FF","hi":"#E9D2FF","ex":"#4A2A7A","w":"#1A1030","glow":"#B060FF"}'::jsonb,800,'epic',false,'user','Glows when you answer right.',41,'shop',null),
  ('weapon_skin','Axe','axe','{"weapon":"axe","metal":"#98A4B8","hi":"#B8C4D8","ex":"#6B7790","w":"#7A4A2B"}'::jsonb,0,'common',false,'user','Brutal swing.',50,'shop',null),
  ('weapon_skin','Ember Axe','axe','{"weapon":"axe","metal":"#FF8A3D","hi":"#FFE0C2","ex":"#C2410C","w":"#2A1A0E","glow":"#FF8A3D"}'::jsonb,500,'rare',false,'user','Hot to the touch.',51,'shop',null)
) as seed(category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
where not exists (select 1 from public.cosmetic_items c where c.category = seed.category and c.name = seed.name);

-- The six starter heroes: free outfits with different looks. hair_style is one of
-- low | afro | braids | locs | wrap | hijab (drawn by the app).
insert into public.cosmetic_items
  (category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source)
select * from (values
  ('hero_outfit','Ayo','','{"shirt":"#EEF2F8","pants":"#1F3B66","skin":"#8D5A3B","hair":"#1A1410","hair_style":"low"}'::jsonb,0,'common',false,'user','Low cut, white shirt.',1,'shop'),
  ('hero_outfit','Zainab','','{"shirt":"#EEF2F8","pants":"#2B4A66","skin":"#C68B59","hair":"#2F6F8F","hair_style":"hijab"}'::jsonb,0,'common',false,'user','Hijab, school wear.',2,'shop'),
  ('hero_outfit','Chidi','','{"shirt":"#4BD37B","pants":"#14532D","skin":"#5A3A28","hair":"#14100C","hair_style":"afro"}'::jsonb,0,'common',false,'user','Afro, practice kit.',3,'shop'),
  ('hero_outfit','Folake','','{"shirt":"#E8467C","pants":"#1E3A8A","skin":"#A66E47","hair":"#14100C","hair_style":"braids"}'::jsonb,0,'common',false,'user','Braids, ankara top.',4,'shop'),
  ('hero_outfit','Emeka','','{"shirt":"#6B2FBF","pants":"#2D3748","skin":"#3E2A20","hair":"#14100C","hair_style":"locs"}'::jsonb,0,'common',false,'user','Locs, hoodie.',5,'shop'),
  ('hero_outfit','Bisi','','{"shirt":"#F6B93B","pants":"#2D3748","skin":"#D9A074","hair":"#E8860C","hair_style":"wrap"}'::jsonb,0,'common',false,'user','Headwrap, casual.',6,'shop')
) as seed(category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source)
where not exists (select 1 from public.cosmetic_items c where c.category = seed.category and c.name = seed.name);

notify pgrst, 'reload schema';
