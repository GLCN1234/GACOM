-- Ads engine: campaigns that are paid for, reviewed, targeted, delivered, billed and measured.
--
-- Before this file the ad_campaigns table only stored a form. Nothing took the money, nothing
-- chose who saw an ad, nothing showed one, and impressions/clicks were never counted. This adds:
--
--   * Objectives: awareness (you pay per 1,000 impressions) and traffic (you pay per click)
--   * Placements: feed, banner, fullscreen. Each has its own rate (ad_rates, editable)
--   * Budget: a daily budget and a number of days (1 to 30). The whole budget is taken from the
--     advertiser's wallet at launch and held; unspent money is refunded when the ad ends
--   * Schedule: start now or up to 30 days ahead, end date set from the duration
--   * Targeting: countries and interests (darkom, chess, quiz, shooters, football, competitors,
--     shoppers). Age and gender are NOT available: the app does not collect them
--   * Pricing effect of audience size: narrow audiences cost more, as on Instagram
--   * Delivery: ad_serve() chooses a live, in-budget, in-schedule, correctly targeted campaign,
--     caps frequency at 3 views per person per day, paces spend across the day, never shows
--     you your own ad, and counts the impression
--   * Click tracking and billing, reach (unique viewers), results per day
--   * Review: automated policy check; a new advertiser's first campaign waits for an admin
--   * Pause / resume / cancel with refund
-- Run after 20261020_security_hardening.sql and 20261103_verified_hosting.sql.

-- ---------------------------------------------------------------------------
-- 1. Campaign columns
-- ---------------------------------------------------------------------------
alter table public.ad_campaigns alter column spend type numeric(14,4);
alter table public.ad_campaigns add column if not exists objective text not null default 'awareness';
alter table public.ad_campaigns add column if not exists placements text[] not null default '{feed}';
alter table public.ad_campaigns add column if not exists headline text;
alter table public.ad_campaigns add column if not exists cta text not null default 'Learn more';
alter table public.ad_campaigns add column if not exists creative_url text;
alter table public.ad_campaigns add column if not exists target_countries text[] not null default '{}';
alter table public.ad_campaigns add column if not exists target_interests text[] not null default '{}';
alter table public.ad_campaigns add column if not exists duration_days integer not null default 3;
alter table public.ad_campaigns add column if not exists starts_at timestamptz;
alter table public.ad_campaigns add column if not exists ends_at timestamptz;
alter table public.ad_campaigns add column if not exists total_budget integer not null default 0;
alter table public.ad_campaigns add column if not exists price_mult numeric(4,2) not null default 1.00;
alter table public.ad_campaigns add column if not exists audience_size integer;
alter table public.ad_campaigns add column if not exists reach integer not null default 0;
alter table public.ad_campaigns add column if not exists spend_day date;
alter table public.ad_campaigns add column if not exists spend_today numeric(14,4) not null default 0;
alter table public.ad_campaigns add column if not exists imp_today integer not null default 0;
alter table public.ad_campaigns add column if not exists last_served_at timestamptz;
alter table public.ad_campaigns add column if not exists approved_at timestamptz;
alter table public.ad_campaigns add column if not exists review_note text;
alter table public.ad_campaigns add column if not exists flag_reason text;
alter table public.ad_campaigns add column if not exists settled boolean not null default false;
alter table public.ad_campaigns add column if not exists refunded integer not null default 0;

do $$ begin
  alter table public.ad_campaigns add constraint ad_campaigns_objective_chk check (objective in ('awareness', 'traffic'));
exception when duplicate_object then null; end $$;

create index if not exists ad_campaigns_serve_idx on public.ad_campaigns (status, starts_at, ends_at) where settled = false;

-- Only the owner (and admins) may read. All changes go through the functions below,
-- so nobody can edit a budget, delete an ad with money still held, or write their own metrics.
drop policy if exists "advertiser_campaigns" on public.ad_campaigns;
drop policy if exists "ads owner or admin read" on public.ad_campaigns;
create policy "ads owner or admin read" on public.ad_campaigns for select
  using (advertiser_id = auth.uid() or public.sec_is_admin());
revoke insert, update, delete on public.ad_campaigns from anon, authenticated;

create or replace function public.sec_ads_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not public.sec_client() or public.sec_is_admin() then return new; end if;
  raise exception 'Campaigns are created and changed from the Advertise screen' using errcode = '42501';
end $$;

-- ---------------------------------------------------------------------------
-- 2. Rates, policy terms, settings, impressions
-- ---------------------------------------------------------------------------
create table if not exists public.ad_rates (
  placement text primary key check (placement in ('feed', 'banner', 'fullscreen')),
  cpm integer not null check (cpm > 0),   -- naira per 1,000 impressions (awareness)
  cpc integer not null check (cpc > 0),   -- naira per click (traffic)
  label text not null,
  blurb text not null
);
alter table public.ad_rates enable row level security;
drop policy if exists "anyone reads ad rates" on public.ad_rates;
create policy "anyone reads ad rates" on public.ad_rates for select using (true);
revoke insert, update, delete on public.ad_rates from anon, authenticated;
-- Typical Nigerian mobile social ranges. Change any number and every estimate follows.
insert into public.ad_rates (placement, cpm, cpc, label, blurb) values
  ('feed', 1500, 100, 'In-feed', 'A sponsored card between posts in the feed'),
  ('banner', 800, 70, 'Banner', 'A slim banner at the top of the home screen'),
  ('fullscreen', 3000, 180, 'Full screen', 'One high-impact screen when the app opens')
on conflict (placement) do nothing;

create table if not exists public.ad_policy_terms (term text primary key);
alter table public.ad_policy_terms enable row level security;
revoke all on public.ad_policy_terms from anon, authenticated;
insert into public.ad_policy_terms (term) values
  ('guaranteed win'), ('get rich'), ('double your money'), ('investment returns'), ('forex signal'),
  ('crypto giveaway'), ('loan'), ('betting'), ('casino'), ('adult'), ('sex'), ('porn'), ('hack'),
  ('cheat code'), ('free money'), ('mmm'), ('ponzi'), ('whatsapp me for')
on conflict do nothing;

create table if not exists public.ad_settings (
  id boolean primary key default true check (id),
  review_first_campaign boolean not null default true,
  max_live_per_advertiser integer not null default 10
);
insert into public.ad_settings (id) values (true) on conflict do nothing;
alter table public.ad_settings enable row level security;
revoke all on public.ad_settings from anon, authenticated;

create table if not exists public.ad_impressions (
  id bigserial primary key,
  campaign_id uuid not null references public.ad_campaigns(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  placement text not null,
  day date not null,
  at timestamptz not null default now(),
  cost numeric(14,4) not null default 0,
  clicked boolean not null default false,
  clicked_at timestamptz,
  click_cost numeric(14,4) not null default 0
);
create index if not exists ad_impressions_campaign_day_idx on public.ad_impressions (campaign_id, day);
create index if not exists ad_impressions_viewer_idx on public.ad_impressions (viewer_id, campaign_id, at desc);
alter table public.ad_impressions enable row level security;
revoke all on public.ad_impressions from anon, authenticated;

create table if not exists public.ad_reach (
  campaign_id uuid not null references public.ad_campaigns(id) on delete cascade,
  viewer_id uuid not null references auth.users(id) on delete cascade,
  first_at timestamptz not null default now(),
  primary key (campaign_id, viewer_id)
);
alter table public.ad_reach enable row level security;
revoke all on public.ad_reach from anon, authenticated;

-- ---------------------------------------------------------------------------
-- 3. Audience: who can be reached
-- ---------------------------------------------------------------------------
create or replace function public.ad_user_interests(p_user uuid)
returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_remove(array[
    case when exists (select 1 from public.game_scores g where g.user_id = p_user and g.game_name = 'Darkom City') then 'darkom' end,
    case when exists (select 1 from public.game_scores g where g.user_id = p_user and g.game_name ilike '%chess%')
           or exists (select 1 from public.profiles p, unnest(coalesce(p.favorite_games, '{}')) f where p.id = p_user and f ilike '%chess%') then 'chess' end,
    case when exists (select 1 from public.game_scores g where g.user_id = p_user and (g.game_name ilike '%trivia%' or g.game_name ilike '%quiz%' or g.game_name ilike '%math%' or g.game_name ilike '%word%' or g.game_name ilike '%sudoku%')) then 'quiz' end,
    case when exists (select 1 from public.profiles p, unnest(coalesce(p.favorite_games, '{}')) f
                       where p.id = p_user and (f ilike '%pubg%' or f ilike '%call of duty%' or f ilike '%cod%' or f ilike '%free fire%' or f ilike '%fortnite%' or f ilike '%valorant%' or f ilike '%cs%go%')) then 'shooters' end,
    case when exists (select 1 from public.profiles p, unnest(coalesce(p.favorite_games, '{}')) f
                       where p.id = p_user and (f ilike '%fifa%' or f ilike '%efootball%' or f ilike '%pes%' or f ilike '%fc 2%' or f ilike '%football%')) then 'football' end,
    case when exists (select 1 from public.competition_participants c where c.user_id = p_user) then 'competitors' end,
    case when exists (select 1 from public.orders o where o.user_id = p_user) then 'shoppers' end
  ], null), '{}'::text[]);
$$;
revoke all on function public.ad_user_interests(uuid) from public, anon, authenticated;

create or replace function public.ad_audience_size(p_countries text[], p_interests text[], p_exclude uuid default null)
returns integer language plpgsql stable security definer set search_path = public as $$
declare n integer; c text[] := coalesce(p_countries, '{}'); i text[] := coalesce(p_interests, '{}');
begin
  select count(*) into n from public.profiles p
   where coalesce(p.is_banned, false) = false
     and p.last_seen > now() - interval '60 days'
     and (p_exclude is null or p.id <> p_exclude)
     and (cardinality(c) = 0 or exists (select 1 from unnest(c) t
            where lower(coalesce(p.country, '')) = lower(t) or coalesce(p.location, '') ilike '%' || t || '%'))
     and (cardinality(i) = 0 or public.ad_user_interests(p.id) && i);
  return n;
end;
$$;
revoke all on function public.ad_audience_size(text[], text[], uuid) from public, anon, authenticated;

-- Narrow audiences cost more (a smaller pool means a bidding war for the same people).
create or replace function public.ad_price_mult(p_audience integer)
returns numeric language sql immutable as $$
  select case when p_audience < 300 then 1.60 when p_audience < 1500 then 1.30 when p_audience < 5000 then 1.10 else 1.00 end;
$$;

create or replace function public.ad_platform_stats()
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'active_30d', (select count(*) from public.profiles where coalesce(is_banned, false) = false and last_seen > now() - interval '30 days'),
    'total', (select count(*) from public.profiles where coalesce(is_banned, false) = false));
$$;
grant execute on function public.ad_platform_stats() to authenticated;

create or replace function public.ad_rates_list()
returns jsonb language sql stable security definer set search_path = public as $$
  select coalesce(jsonb_agg(to_jsonb(r) order by r.cpm), '[]'::jsonb) from public.ad_rates r;
$$;
grant execute on function public.ad_rates_list() to authenticated;

-- ---------------------------------------------------------------------------
-- 4. Estimate (what the advertiser sees before paying)
-- ---------------------------------------------------------------------------
create or replace function public.ad_estimate(p_cfg jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  countries text[] := coalesce(array(select jsonb_array_elements_text(coalesce(p_cfg -> 'countries', '[]'::jsonb))), '{}');
  interests text[] := coalesce(array(select jsonb_array_elements_text(coalesce(p_cfg -> 'interests', '[]'::jsonb))), '{}');
  places text[] := coalesce(array(select jsonb_array_elements_text(coalesce(p_cfg -> 'placements', '["feed"]'::jsonb))), '{feed}');
  objective text := coalesce(p_cfg ->> 'objective', 'awareness');
  daily integer := coalesce((p_cfg ->> 'daily_budget')::integer, 1000);
  days integer := coalesce((p_cfg ->> 'days')::integer, 3);
  aud integer;
  mult numeric;
  avg_cpm numeric; avg_cpc numeric;
  imp_day numeric; reach_day numeric; clicks_day numeric;
begin
  if uid is null then return null; end if;
  perform public.sec_rl('ad_estimate', 60, 60);
  aud := public.ad_audience_size(countries, interests, uid);
  mult := public.ad_price_mult(aud);
  select coalesce(avg(cpm), 1500), coalesce(avg(cpc), 100) into avg_cpm, avg_cpc
    from public.ad_rates where placement = any(places);
  avg_cpm := avg_cpm * mult; avg_cpc := avg_cpc * mult;
  if objective = 'traffic' then
    imp_day := least(daily / avg_cpc * 100.0, aud * 3.0);          -- a click costs about 1 percent of the views it needs
    clicks_day := least(daily / avg_cpc, imp_day * 0.012);
  else
    imp_day := least(daily / avg_cpm * 1000.0, aud * 3.0);          -- 3 views per person per day is the cap
    clicks_day := imp_day * 0.010;
  end if;
  reach_day := least(aud, imp_day / 1.4);
  return jsonb_build_object(
    'audience', aud, 'price_mult', mult,
    'cpm', round(avg_cpm), 'cpc', round(avg_cpc),
    'total_budget', daily * days,
    'reach_low', floor(reach_day * 0.7), 'reach_high', ceil(reach_day * 1.3),
    'impressions_low', floor(imp_day * 0.7), 'impressions_high', ceil(imp_day * 1.3),
    'clicks_low', floor(clicks_day * 0.5), 'clicks_high', ceil(clicks_day * 1.5),
    'small_audience', aud < 300,
    'budget_too_big', (objective = 'awareness' and daily / avg_cpm * 1000.0 > aud * 3.0));
end;
$$;
grant execute on function public.ad_estimate(jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Money: settle and refund
-- ---------------------------------------------------------------------------
create or replace function public.ad_settle(p_id uuid, p_status text)
returns void language plpgsql security definer set search_path = public as $$
declare c public.ad_campaigns; left_amt integer; r jsonb;
begin
  select * into c from public.ad_campaigns where id = p_id for update;
  if not found or c.settled then return; end if;
  left_amt := greatest(0, floor(c.total_budget - c.spend)::int);
  if left_amt > 0 then
    r := public.refund_arena_stake(c.advertiser_id, left_amt, 'AD_REFUND_' || p_id::text);
    if coalesce((r ->> 'success')::boolean, false) is not true then
      raise exception 'ad refund failed';
    end if;
  end if;
  update public.ad_campaigns set settled = true, refunded = left_amt, status = p_status, updated_at = now() where id = p_id;
  if left_amt > 0 then
    perform public.identity_notify(c.advertiser_id, 'Ad budget returned',
      'N' || left_amt || ' left over from "' || left(c.title, 40) || '" is back in your wallet.',
      jsonb_build_object('kind', 'ad_refund', 'campaign', p_id));
  end if;
end;
$$;
revoke all on function public.ad_settle(uuid, text) from public, anon, authenticated;

create or replace function public.ad_finalize_due()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; n integer := 0;
begin
  for r in
    select id, status, spend, total_budget, ends_at from public.ad_campaigns
     where settled = false
       and ((status in ('active', 'paused') and (ends_at < now() or spend >= total_budget - 0.5))
         or (status = 'pending_review' and ends_at < now()))
     limit 20
  loop
    begin
      perform public.ad_settle(r.id, case when r.status = 'pending_review' then 'expired' else 'ended' end);
      n := n + 1;
    exception when others then null;
    end;
  end loop;
  return n;
end;
$$;
revoke all on function public.ad_finalize_due() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 6. Create
-- ---------------------------------------------------------------------------
create or replace function public.ad_flagged_terms(p_text text)
returns text language sql stable security definer set search_path = public as $$
  select string_agg(term, ', ') from public.ad_policy_terms where lower(p_text) like '%' || term || '%';
$$;
revoke all on function public.ad_flagged_terms(text) from public, anon, authenticated;

create or replace function public.ad_create(p_cfg jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  v_id uuid := gen_random_uuid();
  v_title text := btrim(coalesce(p_cfg ->> 'title', ''));
  v_headline text := btrim(coalesce(p_cfg ->> 'headline', ''));
  v_body text := btrim(coalesce(p_cfg ->> 'body', ''));
  v_cta text := coalesce(nullif(btrim(p_cfg ->> 'cta'), ''), 'Learn more');
  v_dest text := btrim(coalesce(p_cfg ->> 'destination_url', ''));
  v_creative text := btrim(coalesce(p_cfg ->> 'creative_url', ''));
  v_objective text := coalesce(p_cfg ->> 'objective', 'awareness');
  v_places text[] := coalesce(array(select jsonb_array_elements_text(coalesce(p_cfg -> 'placements', '["feed"]'::jsonb))), '{feed}');
  v_countries text[] := coalesce(array(select jsonb_array_elements_text(coalesce(p_cfg -> 'countries', '[]'::jsonb))), '{}');
  v_interests text[] := coalesce(array(select jsonb_array_elements_text(coalesce(p_cfg -> 'interests', '[]'::jsonb))), '{}');
  v_daily integer;
  v_days integer;
  v_start timestamptz;
  v_total integer;
  v_aud integer;
  v_mult numeric;
  v_flags text;
  v_review_first boolean;
  v_had_approved boolean;
  v_status text;
  v_max_live integer;
  v_r jsonb;
  v_ref text;
  v_bal numeric;
  v_p text;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  perform public.sec_rl('ad_create', 8, 3600);
  if exists (select 1 from public.profiles pr where pr.id = uid and pr.is_banned is true) then
    return jsonb_build_object('success', false, 'error', 'This account cannot run ads');
  end if;
  begin
    v_daily := (p_cfg ->> 'daily_budget')::integer;
    v_days := (p_cfg ->> 'days')::integer;
    v_start := coalesce((p_cfg ->> 'start_at')::timestamptz, now());
  exception when others then
    return jsonb_build_object('success', false, 'error', 'Enter a valid budget, number of days and start time');
  end;

  if length(v_title) < 2 or length(v_title) > 60 then return jsonb_build_object('success', false, 'error', 'Campaign name needs 2 to 60 characters'); end if;
  if length(v_headline) < 2 or length(v_headline) > 40 then return jsonb_build_object('success', false, 'error', 'Headline needs 2 to 40 characters'); end if;
  if length(v_body) > 200 then return jsonb_build_object('success', false, 'error', 'Ad text can be at most 200 characters'); end if;
  if v_cta not in ('Learn more', 'Shop now', 'Play now', 'Sign up', 'Download', 'Join now', 'Watch more', 'Contact us') then
    return jsonb_build_object('success', false, 'error', 'Pick a button from the list');
  end if;
  if v_dest !~* '^https://[a-z0-9][a-z0-9.-]*\.[a-z]{2,}(/[^ ]*)?$' or length(v_dest) > 300 then
    return jsonb_build_object('success', false, 'error', 'The link must start with https:// and be a real website');
  end if;
  if v_creative = '' or position('/storage/v1/object/public/ad-creatives/' || uid::text || '/' in v_creative) = 0 or length(v_creative) > 500 then
    return jsonb_build_object('success', false, 'error', 'Upload an image for the ad');
  end if;
  if v_objective not in ('awareness', 'traffic') then return jsonb_build_object('success', false, 'error', 'Pick an objective'); end if;
  if cardinality(v_places) < 1 or cardinality(v_places) > 3 then return jsonb_build_object('success', false, 'error', 'Pick where the ad should appear'); end if;
  foreach v_p in array v_places loop
    if v_p not in ('feed', 'banner', 'fullscreen') then return jsonb_build_object('success', false, 'error', 'Unknown placement'); end if;
  end loop;
  if cardinality(v_countries) > 20 or cardinality(v_interests) > 7 then return jsonb_build_object('success', false, 'error', 'Too many targeting options'); end if;
  if v_daily is null or v_daily < 1000 or v_daily > 500000 then return jsonb_build_object('success', false, 'error', 'Daily budget is between N1,000 and N500,000'); end if;
  if v_days is null or v_days < 1 or v_days > 30 then return jsonb_build_object('success', false, 'error', 'Run it for 1 to 30 days'); end if;
  if v_start < now() - interval '5 minutes' or v_start > now() + interval '30 days' then
    return jsonb_build_object('success', false, 'error', 'Start within the next 30 days');
  end if;
  if v_start < now() then v_start := now(); end if;

  select s.review_first_campaign, s.max_live_per_advertiser into v_review_first, v_max_live from public.ad_settings s limit 1;
  if (select count(*) from public.ad_campaigns ac where ac.advertiser_id = uid and ac.settled = false) >= coalesce(v_max_live, 10) then
    return jsonb_build_object('success', false, 'error', 'You have too many running campaigns. End one first.');
  end if;

  v_total := v_daily * v_days;
  v_aud := public.ad_audience_size(v_countries, v_interests, uid);
  v_mult := public.ad_price_mult(v_aud);
  v_flags := public.ad_flagged_terms(v_title || ' ' || v_headline || ' ' || v_body);
  select exists (select 1 from public.ad_campaigns ac where ac.advertiser_id = uid and ac.approved_at is not null) into v_had_approved;
  v_status := case when v_flags is not null or (coalesce(v_review_first, true) and not v_had_approved) then 'pending_review' else 'active' end;

  v_ref := 'AD_' || v_id::text;
  v_r := public.deduct_arena_stake(uid, v_total, v_ref);
  if coalesce((v_r ->> 'success')::boolean, false) is not true then
    return jsonb_build_object('success', false, 'error', coalesce(v_r ->> 'error', 'Not enough balance. Fund your wallet to launch.'));
  end if;

  begin
    insert into public.ad_campaigns (
      id, advertiser_id, title, description, destination_url, ad_type, target_audience, daily_budget, status,
      objective, placements, headline, cta, creative_url, target_countries, target_interests, duration_days,
      starts_at, ends_at, total_budget, price_mult, audience_size, approved_at, flag_reason)
    values (
      v_id, uid, v_title, nullif(v_body, ''), v_dest, v_places[1], 'custom', v_daily, v_status,
      v_objective, v_places, v_headline, v_cta, v_creative, v_countries, v_interests, v_days,
      v_start, v_start + v_days * interval '1 day', v_total, v_mult, v_aud,
      case when v_status = 'active' then now() else null end, v_flags);
  exception when others then
    perform public.refund_arena_stake(uid, v_total, v_ref || '_REFUND');
    return jsonb_build_object('success', false, 'error', 'Could not create the campaign, you were not charged');
  end;

  select pr.wallet_balance into v_bal from public.profiles pr where pr.id = uid;
  return jsonb_build_object('success', true, 'id', v_id, 'status', v_status, 'total', v_total, 'balance', v_bal,
                            'flag_reason', v_flags);
end;
$$;
grant execute on function public.ad_create(jsonb) to authenticated;

-- Change the wording, picture, button or link. Wording is checked again.
create or replace function public.ad_update_creative(p_id uuid, p_cfg jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  c public.ad_campaigns;
  v_headline text := btrim(coalesce(p_cfg ->> 'headline', ''));
  v_body text := btrim(coalesce(p_cfg ->> 'body', ''));
  v_cta text := coalesce(nullif(btrim(p_cfg ->> 'cta'), ''), 'Learn more');
  v_dest text := btrim(coalesce(p_cfg ->> 'destination_url', ''));
  v_creative text := btrim(coalesce(p_cfg ->> 'creative_url', ''));
  v_flags text;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into c from public.ad_campaigns ac where ac.id = p_id for update;
  if not found or c.advertiser_id <> uid then return jsonb_build_object('success', false, 'error', 'Not your campaign'); end if;
  if c.settled then return jsonb_build_object('success', false, 'error', 'This campaign has ended'); end if;
  if length(v_headline) < 2 or length(v_headline) > 40 or length(v_body) > 200 then
    return jsonb_build_object('success', false, 'error', 'Check the headline and text length');
  end if;
  if v_cta not in ('Learn more', 'Shop now', 'Play now', 'Sign up', 'Download', 'Join now', 'Watch more', 'Contact us') then
    return jsonb_build_object('success', false, 'error', 'Pick a button from the list');
  end if;
  if v_dest !~* '^https://[a-z0-9][a-z0-9.-]*\.[a-z]{2,}(/[^ ]*)?$' or length(v_dest) > 300 then
    return jsonb_build_object('success', false, 'error', 'The link must start with https:// and be a real website');
  end if;
  if position('/storage/v1/object/public/ad-creatives/' || uid::text || '/' in v_creative) = 0 then
    return jsonb_build_object('success', false, 'error', 'Use an uploaded image');
  end if;
  v_flags := public.ad_flagged_terms(v_headline || ' ' || v_body);
  update public.ad_campaigns ac
     set headline = v_headline, description = nullif(v_body, ''), cta = v_cta,
         destination_url = v_dest, creative_url = v_creative, flag_reason = v_flags,
         status = case when v_flags is not null and ac.status = 'active' then 'pending_review' else ac.status end,
         updated_at = now()
   where ac.id = p_id;
  return jsonb_build_object('success', true, 'needs_review', v_flags is not null);
end;
$$;
grant execute on function public.ad_update_creative(uuid, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- 7. Pause, resume, cancel
-- ---------------------------------------------------------------------------
create or replace function public.ad_set_status(p_id uuid, p_action text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); c public.ad_campaigns;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  select * into c from public.ad_campaigns ac where ac.id = p_id for update;
  if not found or c.advertiser_id <> uid then return jsonb_build_object('success', false, 'error', 'Not your campaign'); end if;
  if c.settled then return jsonb_build_object('success', false, 'error', 'This campaign has ended'); end if;
  if p_action = 'pause' then
    if c.status <> 'active' then return jsonb_build_object('success', false, 'error', 'Only a running campaign can be paused'); end if;
    update public.ad_campaigns set status = 'paused', updated_at = now() where id = p_id;
  elsif p_action = 'resume' then
    if c.status <> 'paused' then return jsonb_build_object('success', false, 'error', 'This campaign is not paused'); end if;
    update public.ad_campaigns set status = 'active', updated_at = now() where id = p_id;
  elsif p_action = 'cancel' then
    perform public.ad_settle(p_id, 'cancelled');
  else
    return jsonb_build_object('success', false, 'error', 'Unknown action');
  end if;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.ad_set_status(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 8. Delivery: choose an ad, count the view, bill it
-- ---------------------------------------------------------------------------
create or replace function public.ad_serve(p_placement text, p_recent uuid[] default '{}')
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  v_country text; v_location text; v_interests text[];
  c public.ad_campaigns;
  v_rate record;
  v_price numeric;      -- cost of this one view or, for traffic, of the view needed (billed on click)
  v_cost numeric;
  v_hours numeric; v_elapsed numeric; v_allowed numeric;
  v_imp_id bigint;
  v_today date := (now() at time zone 'Africa/Lagos')::date;
  v_seen integer;
begin
  if uid is null then return null; end if;
  if p_placement not in ('feed', 'banner', 'fullscreen') then return null; end if;
  perform public.sec_rl('ad_serve', 120, 60);

  select pr.country, pr.location into v_country, v_location from public.profiles pr where pr.id = uid;
  v_interests := public.ad_user_interests(uid);
  select * into v_rate from public.ad_rates where placement = p_placement;
  if not found then return null; end if;

  for c in
    select * from public.ad_campaigns ac
     where ac.status = 'active' and ac.settled = false
       and ac.starts_at <= now() and ac.ends_at > now()
       and p_placement = any(ac.placements)
       and ac.advertiser_id <> uid
       and ac.spend < ac.total_budget
       and not (ac.id = any(coalesce(p_recent, '{}')))
       and (cardinality(ac.target_countries) = 0 or exists (
              select 1 from unnest(ac.target_countries) t
               where lower(coalesce(v_country, '')) = lower(t) or coalesce(v_location, '') ilike '%' || t || '%'))
       and (cardinality(ac.target_interests) = 0 or ac.target_interests && v_interests)
     order by random()
     limit 25
  loop
    -- frequency cap: 3 views per person per day per campaign
    select count(*) into v_seen from public.ad_impressions i where i.campaign_id = c.id and i.viewer_id = uid and i.day = v_today;
    if v_seen >= 3 then continue; end if;

    -- daily budget and pacing across the Lagos day (cannot spend the whole day's money in the first hour)
    if c.spend_day is distinct from v_today then
      update public.ad_campaigns set spend_day = v_today, spend_today = 0, imp_today = 0 where id = c.id;
      c.spend_today := 0;
    end if;
    if c.spend_today >= c.daily_budget then continue; end if;
    v_elapsed := extract(epoch from ((now() at time zone 'Africa/Lagos') - v_today::timestamp)) / 3600.0;
    v_allowed := c.daily_budget * least(1.0, (v_elapsed + 2.0) / 24.0);
    if c.spend_today >= v_allowed then continue; end if;

    if c.objective = 'awareness' then
      v_cost := v_rate.cpm * c.price_mult / 1000.0;
    else
      v_cost := 0;
    end if;
    if c.spend + v_cost > c.total_budget + 0.0001 then continue; end if;

    insert into public.ad_impressions (campaign_id, viewer_id, placement, day, cost)
      values (c.id, uid, p_placement, v_today, v_cost) returning id into v_imp_id;
    insert into public.ad_reach (campaign_id, viewer_id) values (c.id, uid) on conflict do nothing;
    update public.ad_campaigns
       set impressions = impressions + 1,
           spend = spend + v_cost,
           spend_today = spend_today + v_cost,
           imp_today = imp_today + 1,
           reach = (select count(*) from public.ad_reach r where r.campaign_id = c.id),
           last_served_at = now()
     where id = c.id;

    return jsonb_build_object(
      'impression', v_imp_id, 'campaign', c.id, 'headline', c.headline, 'body', c.description,
      'cta', c.cta, 'image', c.creative_url, 'url', c.destination_url, 'placement', p_placement);
  end loop;
  return null;
end;
$$;
grant execute on function public.ad_serve(text, uuid[]) to authenticated;

create or replace function public.ad_click(p_impression bigint)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); i public.ad_impressions; c public.ad_campaigns; v_rate record; v_cost numeric := 0;
begin
  if uid is null then return null; end if;
  perform public.sec_rl('ad_click', 60, 60);
  select * into i from public.ad_impressions x where x.id = p_impression and x.viewer_id = uid for update;
  if not found then return null; end if;
  select * into c from public.ad_campaigns ac where ac.id = i.campaign_id for update;
  if i.clicked then return jsonb_build_object('url', c.destination_url); end if;
  if c.objective = 'traffic' and c.settled = false then
    select * into v_rate from public.ad_rates where placement = i.placement;
    v_cost := least(v_rate.cpc * c.price_mult, greatest(0, c.total_budget - c.spend));
  end if;
  update public.ad_impressions set clicked = true, clicked_at = now(), click_cost = v_cost where id = i.id;
  update public.ad_campaigns
     set clicks = clicks + 1, spend = spend + v_cost, spend_today = spend_today + v_cost, updated_at = now()
   where id = c.id;
  return jsonb_build_object('url', c.destination_url);
end;
$$;
grant execute on function public.ad_click(bigint) to authenticated;

-- ---------------------------------------------------------------------------
-- 9. The advertiser's dashboard
-- ---------------------------------------------------------------------------
create or replace function public.ad_my_campaigns()
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return '[]'::jsonb; end if;
  perform public.ad_finalize_due();
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'title', c.title, 'headline', c.headline, 'body', c.description, 'cta', c.cta,
      'image', c.creative_url, 'url', c.destination_url, 'objective', c.objective, 'placements', c.placements,
      'countries', c.target_countries, 'interests', c.target_interests, 'days', c.duration_days,
      'daily_budget', c.daily_budget, 'total_budget', c.total_budget, 'spend', round(c.spend, 2),
      'impressions', c.impressions, 'clicks', c.clicks, 'reach', c.reach,
      'status', c.status, 'starts_at', c.starts_at, 'ends_at', c.ends_at, 'refunded', c.refunded,
      'review_note', c.review_note, 'flag_reason', c.flag_reason, 'created_at', c.created_at)
      order by c.created_at desc)
    from public.ad_campaigns c where c.advertiser_id = uid), '[]'::jsonb);
end;
$$;
grant execute on function public.ad_my_campaigns() to authenticated;

create or replace function public.ad_stats(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public as $$
declare uid uuid := auth.uid(); c public.ad_campaigns; v_days jsonb; v_places jsonb;
begin
  if uid is null then return null; end if;
  select * into c from public.ad_campaigns ac where ac.id = p_id;
  if not found or (c.advertiser_id <> uid and not public.sec_is_admin()) then return null; end if;
  select coalesce(jsonb_agg(jsonb_build_object('day', d.day, 'impressions', d.n, 'clicks', d.k, 'spend', round(d.s, 2)) order by d.day), '[]'::jsonb)
    into v_days
    from (select i.day, count(*) n, count(*) filter (where i.clicked) k, sum(i.cost + i.click_cost) s
            from public.ad_impressions i where i.campaign_id = p_id group by i.day) d;
  select coalesce(jsonb_agg(jsonb_build_object('placement', d.placement, 'impressions', d.n, 'clicks', d.k)), '[]'::jsonb)
    into v_places
    from (select i.placement, count(*) n, count(*) filter (where i.clicked) k
            from public.ad_impressions i where i.campaign_id = p_id group by i.placement) d;
  return jsonb_build_object(
    'impressions', c.impressions, 'clicks', c.clicks, 'reach', c.reach, 'spend', round(c.spend, 2),
    'total_budget', c.total_budget, 'remaining', greatest(0, round(c.total_budget - c.spend, 2)),
    'ctr', case when c.impressions > 0 then round(c.clicks::numeric * 100 / c.impressions, 2) else 0 end,
    'frequency', case when c.reach > 0 then round(c.impressions::numeric / c.reach, 2) else 0 end,
    'cost_per_click', case when c.clicks > 0 then round(c.spend / c.clicks, 2) else 0 end,
    'by_day', v_days, 'by_placement', v_places);
end;
$$;
grant execute on function public.ad_stats(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 10. Admin review
-- ---------------------------------------------------------------------------
create or replace function public.admin_ad_queue()
returns jsonb language plpgsql security definer set search_path = public as $$
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'id', c.id, 'title', c.title, 'headline', c.headline, 'body', c.description, 'cta', c.cta,
      'image', c.creative_url, 'url', c.destination_url, 'objective', c.objective, 'placements', c.placements,
      'countries', c.target_countries, 'interests', c.target_interests, 'days', c.duration_days,
      'total_budget', c.total_budget, 'flag_reason', c.flag_reason, 'created_at', c.created_at,
      'advertiser', coalesce(p.username, 'user'))
      order by c.created_at)
    from public.ad_campaigns c left join public.profiles p on p.id = c.advertiser_id
   where c.status = 'pending_review' and c.settled = false), '[]'::jsonb);
end;
$$;
grant execute on function public.admin_ad_queue() to authenticated;

create or replace function public.admin_ad_review(p_id uuid, p_approve boolean, p_note text default null)
returns jsonb language plpgsql security definer set search_path = public as $$
declare c public.ad_campaigns; v_dur interval;
begin
  if not public.sec_is_admin() then raise exception 'Admins only' using errcode = '42501'; end if;
  select * into c from public.ad_campaigns ac where ac.id = p_id for update;
  if not found or c.status <> 'pending_review' or c.settled then return jsonb_build_object('success', false, 'error', 'Not waiting for review'); end if;
  if p_approve then
    -- the run time is counted from approval so the advertiser gets every paid day
    v_dur := c.duration_days * interval '1 day';
    update public.ad_campaigns
       set status = 'active', approved_at = now(), review_note = nullif(btrim(coalesce(p_note, '')), ''),
           starts_at = greatest(starts_at, now()),
           ends_at = greatest(starts_at, now()) + v_dur, updated_at = now()
     where id = p_id;
    perform public.identity_notify(c.advertiser_id, 'Your ad is live',
      '"' || left(c.title, 40) || '" was approved and is now running.', jsonb_build_object('kind', 'ad_live', 'campaign', p_id));
  else
    update public.ad_campaigns set review_note = nullif(btrim(coalesce(p_note, '')), '') where id = p_id;
    perform public.ad_settle(p_id, 'rejected');
    perform public.identity_notify(c.advertiser_id, 'Your ad was not approved',
      coalesce(nullif(btrim(coalesce(p_note, '')), ''), 'It did not meet the advertising rules.') || ' Your full budget is back in your wallet.',
      jsonb_build_object('kind', 'ad_rejected', 'campaign', p_id));
  end if;
  return jsonb_build_object('success', true);
end;
$$;
grant execute on function public.admin_ad_review(uuid, boolean, text) to authenticated;

-- ---------------------------------------------------------------------------
-- 11. Storage for ad images
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('ad-creatives', 'ad-creatives', true, 5242880, array['image/jpeg', 'image/png', 'image/webp'])
on conflict (id) do update set public = true, file_size_limit = 5242880,
  allowed_mime_types = array['image/jpeg', 'image/png', 'image/webp'];

drop policy if exists "ad creatives public read" on storage.objects;
create policy "ad creatives public read" on storage.objects for select using (bucket_id = 'ad-creatives');
drop policy if exists "ad creatives owner upload" on storage.objects;
create policy "ad creatives owner upload" on storage.objects for insert to authenticated
  with check (bucket_id = 'ad-creatives' and (storage.foldername(name))[1] = auth.uid()::text);
drop policy if exists "ad creatives owner delete" on storage.objects;
create policy "ad creatives owner delete" on storage.objects for delete to authenticated
  using (bucket_id = 'ad-creatives' and (storage.foldername(name))[1] = auth.uid()::text);
