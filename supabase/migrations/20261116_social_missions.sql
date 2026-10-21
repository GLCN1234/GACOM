-- Social missions: brand accounts, player social usernames, follow missions, what to tag,
-- and username checks on submitted posts.
--
-- What is and is not verified automatically (be honest with players and staff):
--   * X: the post link must come from the username the player saved, so nobody can submit
--     someone else's post. TikTok links with the @name in them are checked the same way.
--   * Instagram links and TikTok short links do not contain the username, so those are
--     always flagged for a spot check by staff.
--   * Whether the post really tags the brand, or whether the player really follows, cannot be
--     read without paid platform access. The player's personal code goes in the post, and staff
--     spot check by searching the brand account's mentions and followers.

-- ---------------------------------------------------------------------------
-- 1. Brand accounts and player usernames
-- ---------------------------------------------------------------------------
create table if not exists public.brand_socials (
  platform text primary key check (platform in ('x', 'instagram', 'tiktok', 'youtube', 'facebook')),
  handle text not null,
  url text not null,
  hashtags text,
  sort_order integer not null default 0
);
alter table public.brand_socials enable row level security;
drop policy if exists "anyone views brand socials" on public.brand_socials;
create policy "anyone views brand socials" on public.brand_socials for select using (true);
drop policy if exists "admins manage brand socials" on public.brand_socials;
create policy "admins manage brand socials" on public.brand_socials for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());

create table if not exists public.user_social_handles (
  user_id uuid not null references auth.users(id) on delete cascade,
  platform text not null check (platform in ('x', 'instagram', 'tiktok')),
  handle text not null check (handle ~ '^[A-Za-z0-9_.]{1,30}$'),
  updated_at timestamptz not null default now(),
  primary key (user_id, platform)
);
-- One account name belongs to one player on each platform.
create unique index if not exists user_social_handles_uq on public.user_social_handles (platform, lower(handle));
alter table public.user_social_handles enable row level security;
drop policy if exists "own handles" on public.user_social_handles;
create policy "own handles" on public.user_social_handles for select using (auth.uid() = user_id);
drop policy if exists "admins view handles" on public.user_social_handles;
create policy "admins view handles" on public.user_social_handles for select using (public.identity_is_admin());
revoke insert, update, delete on public.user_social_handles from anon, authenticated;

create or replace function public.set_my_social_handle(p_platform text, p_handle text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  h text := regexp_replace(btrim(coalesce(p_handle, '')), '^@', '');
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_platform not in ('x', 'instagram', 'tiktok') then
    return jsonb_build_object('success', false, 'error', 'Unknown platform');
  end if;
  if h !~ '^[A-Za-z0-9_.]{1,30}$' or (p_platform = 'x' and h !~ '^[A-Za-z0-9_]{1,15}$') then
    return jsonb_build_object('success', false, 'error', 'That does not look like a valid username');
  end if;
  begin
    insert into public.user_social_handles (user_id, platform, handle) values (uid, p_platform, h)
    on conflict (user_id, platform) do update set handle = excluded.handle, updated_at = now();
  exception when unique_violation then
    return jsonb_build_object('success', false, 'error', 'That username is already linked to another GACOM account');
  end;
  return jsonb_build_object('success', true, 'handle', h);
end;
$$;
grant execute on function public.set_my_social_handle(text, text) to authenticated;

create or replace function public.my_social_handles()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_object_agg(platform, handle), '{}'::jsonb) from public.user_social_handles where user_id = auth.uid();
$$;
grant execute on function public.my_social_handles() to authenticated;

-- ---------------------------------------------------------------------------
-- 2. Mission columns and the follow type
-- ---------------------------------------------------------------------------
alter table public.missions add column if not exists tag_text text;
alter table public.missions drop constraint if exists missions_type_check;
alter table public.missions add constraint missions_type_check
  check (type in ('in_app', 'social_link', 'clip', 'code_word', 'follow'));

-- ---------------------------------------------------------------------------
-- 3. What the player sees (adds tag text, brand account and the player's own username)
-- ---------------------------------------------------------------------------
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
      'tag_text', m.tag_text,
      'brand_handle', (select b.handle from public.brand_socials b where b.platform = m.platform),
      'brand_url', (select b.url from public.brand_socials b where b.platform = m.platform),
      'brand_hashtags', (select b.hashtags from public.brand_socials b where b.platform = m.platform),
      'my_handle', (select h.handle from public.user_social_handles h where h.user_id = uid and h.platform = m.platform),
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

-- ---------------------------------------------------------------------------
-- 4. Submitting (username match for X and TikTok, follow missions)
-- ---------------------------------------------------------------------------
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
  hnd text;
  needs_handle boolean;
  stored_proof text;
  note_text text := left(coalesce(p_note, ''), 240);
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

  needs_handle := m.type in ('social_link', 'clip', 'follow') and m.platform in ('x', 'instagram', 'tiktok');
  if needs_handle then
    select handle into hnd from public.user_social_handles where user_id = uid and platform = m.platform;
    if hnd is null then
      return jsonb_build_object('success', false, 'error', 'Add your ' || m.platform || ' username first', 'code', 'need_handle', 'platform', m.platform);
    end if;
    note_text := btrim('@' || hnd || ' on ' || m.platform || '. ' || note_text);
  end if;

  if m.type = 'follow' then
    -- No link to check. The saved username is the claim; staff check it against the followers.
    if hnd is null then return jsonb_build_object('success', false, 'error', 'Pick the platform for this mission'); end if;
    auto := m.verify <> 'manual';
    spot := m.verify <> 'manual' and random() < 0.35;
    stored_proof := null;
  elsif m.type = 'code_word' then
    if proof = '' then return jsonb_build_object('success', false, 'error', 'Add your proof first'); end if;
    select answer into secret from public.mission_secrets where mission_id = p_mission_id;
    if secret is null or lower(btrim(secret)) <> lower(proof) then
      return jsonb_build_object('success', false, 'error', 'That code word is not right');
    end if;
    auto := true;
    stored_proof := proof;
  elsif proof ~* '^https?://' then
    if char_length(proof) > 500 or not public.mission_url_ok(m.platform, proof) then
      return jsonb_build_object('success', false, 'error',
        case m.platform when 'any' then 'Paste the link to your post or clip'
                        else 'Paste the link to your ' || m.platform || ' post' end);
    end if;
    auto := m.verify <> 'manual';
    spot := m.verify = 'auto_spotcheck' and random() < 0.2;
    if m.platform = 'x' then
      if proof !~* ('^https?://(www\.|mobile\.)?(x|twitter)\.com/' || replace(hnd, '.', '\.') || '/status/') then
        return jsonb_build_object('success', false, 'error', 'That post is not from @' || hnd || '. Post it from your own account.');
      end if;
    elsif m.platform = 'tiktok' then
      if proof ~* '/@' then
        if proof !~* ('/@' || replace(hnd, '.', '\.') || '/') then
          return jsonb_build_object('success', false, 'error', 'That video is not from @' || hnd || '. Post it from your own account.');
        end if;
      else
        spot := true; -- a short link hides the username
      end if;
    elsif m.platform = 'instagram' then
      spot := true; -- Instagram links do not contain the username
    end if;
    stored_proof := proof;
  elsif m.type = 'clip' and proof like uid::text || '/%' then
    is_upload := true; -- uploaded clips are always reviewed by a person
    stored_proof := proof;
  else
    return jsonb_build_object('success', false, 'error', 'Paste the link to your post or clip');
  end if;

  begin
    insert into public.mission_submissions
      (mission_id, user_id, status, proof_url, storage_path, code, note, auto_approved, needs_spot_check, reviewed_at)
    values (p_mission_id, uid, case when auto then 'approved' else 'pending' end,
            case when is_upload or m.type in ('follow', 'code_word') then null else stored_proof end,
            case when is_upload then stored_proof else null end,
            public.my_mission_code(uid), note_text, auto, spot, case when auto then now() end)
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

notify pgrst, 'reload schema';
