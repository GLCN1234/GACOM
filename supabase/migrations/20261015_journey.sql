-- Journey: zones, quests, stars and mastery gates on top of the learning
-- realms. A run of any realm reports a few numbers (questions asked, correct,
-- best streak); the server turns them into stars on quests. A zone's gate opens
-- when enough stars are earned in that zone, and clearing the gate opens the
-- next zone. Journey never affects competition scoring, and progress is
-- cosmetic and motivational only.

create table if not exists public.journey_worlds (
  realm_id text primary key,
  name text not null,
  subject text,
  logline text,
  story text,
  ideology text,
  boss text,
  accent text not null default '#2ED3E6',
  is_new boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0
);

create table if not exists public.journey_zones (
  realm_id text not null references public.journey_worlds(realm_id) on delete cascade,
  zone_no integer not null check (zone_no >= 1),
  name text not null,
  story text,
  gate_stars_needed integer not null default 4,
  reward_item_id uuid references public.cosmetic_items(id) on delete set null,
  primary key (realm_id, zone_no)
);

create table if not exists public.journey_quests (
  id uuid primary key default gen_random_uuid(),
  realm_id text not null,
  zone_no integer not null,
  title text not null,
  description text,
  kind text not null default 'answer', -- label shown to players: answer | streak | accuracy | gate
  metric text not null check (metric in ('correct_answers', 'best_streak', 'accuracy')),
  min_asked integer not null default 0,
  t1 integer not null,
  t2 integer not null,
  t3 integer not null,
  is_gate boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  foreign key (realm_id, zone_no) references public.journey_zones(realm_id, zone_no) on delete cascade
);
create index if not exists journey_quests_zone_idx on public.journey_quests (realm_id, zone_no, sort_order);

create table if not exists public.user_journey_quests (
  user_id uuid not null references auth.users(id) on delete cascade,
  quest_id uuid not null references public.journey_quests(id) on delete cascade,
  stars integer not null default 0 check (stars between 0 and 3),
  best integer not null default 0,
  updated_at timestamptz not null default now(),
  primary key (user_id, quest_id)
);

alter table public.journey_worlds enable row level security;
alter table public.journey_zones enable row level security;
alter table public.journey_quests enable row level security;
alter table public.user_journey_quests enable row level security;
drop policy if exists "anyone views journey worlds" on public.journey_worlds;
create policy "anyone views journey worlds" on public.journey_worlds for select using (true);
drop policy if exists "anyone views journey zones" on public.journey_zones;
create policy "anyone views journey zones" on public.journey_zones for select using (true);
drop policy if exists "anyone views journey quests" on public.journey_quests;
create policy "anyone views journey quests" on public.journey_quests for select using (true);
drop policy if exists "own journey progress" on public.user_journey_quests;
create policy "own journey progress" on public.user_journey_quests for select using (auth.uid() = user_id);
drop policy if exists "admins manage journey worlds" on public.journey_worlds;
create policy "admins manage journey worlds" on public.journey_worlds for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());
drop policy if exists "admins manage journey zones" on public.journey_zones;
create policy "admins manage journey zones" on public.journey_zones for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());
drop policy if exists "admins manage journey quests" on public.journey_quests;
create policy "admins manage journey quests" on public.journey_quests for all
  using (public.identity_is_admin()) with check (public.identity_is_admin());

insert into public.trophy_defs (key, name, description, icon, rarity, sort_order) values
  ('world_cleared', 'World Cleared', 'Clear the final gate of any world', 'castle_rounded', 'epic', 13)
on conflict (key) do nothing;

-- A zone is open when it is zone 1 or the previous zone's gate has at least one star.
create or replace function public.journey_zone_open(p_user uuid, p_realm text, p_zone integer)
returns boolean language sql stable security definer set search_path = public as $$
  select p_zone <= 1 or exists (
    select 1 from public.journey_quests q
    join public.user_journey_quests u on u.quest_id = q.id and u.user_id = p_user
    where q.realm_id = p_realm and q.zone_no = p_zone - 1 and q.is_gate and q.is_active and u.stars >= 1
  );
$$;

create or replace function public.journey_zone_stars(p_user uuid, p_realm text, p_zone integer)
returns integer language sql stable security definer set search_path = public as $$
  select coalesce(sum(u.stars), 0)::int
  from public.journey_quests q join public.user_journey_quests u on u.quest_id = q.id and u.user_id = p_user
  where q.realm_id = p_realm and q.zone_no = p_zone and not q.is_gate and q.is_active;
$$;

create or replace function public.journey_get(p_realm text)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  w public.journey_worlds;
  zones jsonb;
  total integer := 0;
  mx integer := 0;
begin
  if uid is null then return null; end if;
  select * into w from public.journey_worlds where realm_id = p_realm and is_active;
  if not found then return jsonb_build_object('world', null); end if;

  select coalesce(jsonb_agg(zj order by (zj ->> 'zone_no')::int), '[]'::jsonb) into zones from (
    select jsonb_build_object(
      'zone_no', z.zone_no, 'name', z.name, 'story', z.story,
      'gate_stars_needed', z.gate_stars_needed,
      'open', public.journey_zone_open(uid, p_realm, z.zone_no),
      'stars', public.journey_zone_stars(uid, p_realm, z.zone_no),
      'max_stars', (select coalesce(sum(3), 0) from public.journey_quests q where q.realm_id = z.realm_id and q.zone_no = z.zone_no and not q.is_gate and q.is_active),
      'gate_cleared', exists (select 1 from public.journey_quests q join public.user_journey_quests u on u.quest_id = q.id and u.user_id = uid
                              where q.realm_id = z.realm_id and q.zone_no = z.zone_no and q.is_gate and u.stars >= 1),
      'reward', (select jsonb_build_object('id', c.id, 'name', c.name, 'category', c.category, 'rarity', c.rarity)
                 from public.cosmetic_items c where c.id = z.reward_item_id),
      'quests', coalesce((
        select jsonb_agg(jsonb_build_object(
          'id', q.id, 'title', q.title, 'description', q.description, 'kind', q.kind, 'metric', q.metric,
          'min_asked', q.min_asked, 't1', q.t1, 't2', q.t2, 't3', q.t3, 'is_gate', q.is_gate,
          'stars', coalesce(u.stars, 0), 'best', coalesce(u.best, 0)
        ) order by q.is_gate, q.sort_order)
        from public.journey_quests q
        left join public.user_journey_quests u on u.quest_id = q.id and u.user_id = uid
        where q.realm_id = z.realm_id and q.zone_no = z.zone_no and q.is_active), '[]'::jsonb)
    ) as zj
    from public.journey_zones z where z.realm_id = p_realm
  ) t;

  select coalesce(sum(u.stars), 0)::int into total
    from public.user_journey_quests u join public.journey_quests q on q.id = u.quest_id
    where u.user_id = uid and q.realm_id = p_realm and not q.is_gate;
  select coalesce(sum(3), 0)::int into mx from public.journey_quests q where q.realm_id = p_realm and not q.is_gate and q.is_active;

  return jsonb_build_object(
    'world', jsonb_build_object('realm_id', w.realm_id, 'name', w.name, 'subject', w.subject, 'logline', w.logline,
                                'story', w.story, 'ideology', w.ideology, 'boss', w.boss, 'accent', w.accent, 'is_new', w.is_new),
    'total_stars', total, 'max_stars', mx, 'zones', zones);
end;
$$;
grant execute on function public.journey_get(text) to authenticated;

create or replace function public.journey_worlds_list()
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare uid uuid := auth.uid();
begin
  if uid is null then return '[]'::jsonb; end if;
  return coalesce((
    select jsonb_agg(jsonb_build_object(
      'realm_id', w.realm_id, 'name', w.name, 'subject', w.subject, 'logline', w.logline, 'accent', w.accent, 'is_new', w.is_new,
      'stars', (select coalesce(sum(u.stars), 0)::int from public.user_journey_quests u join public.journey_quests q on q.id = u.quest_id
                where u.user_id = uid and q.realm_id = w.realm_id and not q.is_gate),
      'max_stars', (select coalesce(sum(3), 0)::int from public.journey_quests q where q.realm_id = w.realm_id and not q.is_gate and q.is_active)
    ) order by w.sort_order)
    from public.journey_worlds w where w.is_active), '[]'::jsonb);
end;
$$;
grant execute on function public.journey_worlds_list() to authenticated;

-- A finished run: {asked, correct, best_streak}. Returns what changed so the app can show it.
create or replace function public.journey_report_run(p_realm text, p_metrics jsonb)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  asked integer;
  correct integer;
  streak integer;
  acc integer;
  q record;
  val integer;
  newstars integer;
  old integer;
  changes jsonb := '[]'::jsonb;
  opened jsonb := '[]'::jsonb;
  cleared jsonb := '[]'::jsonb;
  open_zones integer[];
begin
  if uid is null then return jsonb_build_object('success', false); end if;
  if not exists (select 1 from public.journey_worlds where realm_id = p_realm and is_active) then
    return jsonb_build_object('success', false, 'error', 'Unknown world');
  end if;
  asked := greatest(0, least(coalesce((p_metrics ->> 'asked')::numeric, 0), 200))::int;
  correct := greatest(0, least(coalesce((p_metrics ->> 'correct')::numeric, 0), asked))::int;
  streak := greatest(0, least(coalesce((p_metrics ->> 'best_streak')::numeric, 0), correct))::int;
  acc := case when asked > 0 then floor(correct * 100.0 / asked)::int else 0 end;

  -- zones open at the start of the run: one run opens at most one new zone
  select coalesce(array_agg(zone_no), array[]::integer[]) into open_zones
  from public.journey_zones where realm_id = p_realm and public.journey_zone_open(uid, p_realm, zone_no);

  for q in
    select jq.*, jz.gate_stars_needed, jz.reward_item_id
    from public.journey_quests jq join public.journey_zones jz on jz.realm_id = jq.realm_id and jz.zone_no = jq.zone_no
    where jq.realm_id = p_realm and jq.is_active
    order by jq.zone_no, jq.is_gate, jq.sort_order
  loop
    continue when not (q.zone_no = any(open_zones));
    continue when q.is_gate and public.journey_zone_stars(uid, p_realm, q.zone_no) < q.gate_stars_needed;
    continue when asked < q.min_asked;
    val := case q.metric when 'correct_answers' then correct when 'best_streak' then streak else acc end;
    newstars := case when val >= q.t3 then 3 when val >= q.t2 then 2 when val >= q.t1 then 1 else 0 end;
    select stars into old from public.user_journey_quests where user_id = uid and quest_id = q.id;
    old := coalesce(old, 0);
    insert into public.user_journey_quests (user_id, quest_id, stars, best)
    values (uid, q.id, newstars, val)
    on conflict (user_id, quest_id) do update set
      stars = greatest(public.user_journey_quests.stars, excluded.stars),
      best = greatest(public.user_journey_quests.best, excluded.best),
      updated_at = now();
    if newstars > old then
      changes := changes || jsonb_build_object('id', q.id, 'title', q.title, 'zone_no', q.zone_no, 'is_gate', q.is_gate,
                                               'before', old, 'after', newstars);
      if q.is_gate and old = 0 then
        cleared := cleared || to_jsonb(q.zone_no);
        if q.reward_item_id is not null then
          perform public.grant_cosmetic(uid, q.reward_item_id, 'journey', p_realm || ':' || q.zone_no);
          perform public.identity_notify(uid, 'Reward unlocked', 'You cleared a gate and earned a new item.',
            jsonb_build_object('kind', 'journey', 'realm', p_realm));
        end if;
        if q.zone_no = (select max(zone_no) from public.journey_zones where realm_id = p_realm) then
          perform public.grant_trophy(uid, 'world_cleared');
        end if;
      end if;
    end if;
  end loop;

  select coalesce(jsonb_agg(zone_no order by zone_no), '[]'::jsonb) into opened
  from public.journey_zones z
  where z.realm_id = p_realm and z.zone_no > 1 and public.journey_zone_open(uid, p_realm, z.zone_no)
    and exists (select 1 from jsonb_array_elements(cleared) c where (c #>> '{}')::int = z.zone_no - 1);

  perform public.grant_set_bonuses(uid);
  return jsonb_build_object('success', true, 'changes', changes, 'cleared', cleared, 'opened', opened,
    'gained', (select coalesce(sum((c ->> 'after')::int - (c ->> 'before')::int) filter (where not (c ->> 'is_gate')::boolean), 0)
               from jsonb_array_elements(changes) c));
end;
$$;
grant execute on function public.journey_report_run(text, jsonb) to authenticated;

-- ---------------------------------------------------------------------------
-- Seed: worlds, zones and a generated set of quests (edit any of it later)
-- ---------------------------------------------------------------------------
insert into public.journey_worlds (realm_id, name, subject, logline, story, ideology, boss, accent, is_new, sort_order) values
  ('odyssey',  'Odyssey',  'Mixed subjects', 'Roam an endless world and answer at the checkpoints.', null, null, null, '#2ED3E6', false, 1),
  ('biome',    'Biome',    'Sciences', 'Find creatures, tame them and build a team.', null, null, null, '#8BD86A', false, 2),
  ('windward', 'Windward', 'Mixed subjects', 'Sail the open water and answer to keep moving.', null, null, null, '#3C9DFF', false, 3),
  ('delve',    'Delve',    'Mixed subjects', 'Go deeper into the caves with every right answer.', null, null, null, '#B060FF', false, 4),
  ('casefiles','Case Files','Reading and reasoning', 'Weigh the evidence and close the case.', null, null, null, '#C9A24A', false, 5),
  ('frontier', 'Frontier', 'Mixed subjects', 'Build up an outpost at the edge of the map.', null, null, null, '#FF8A3D', false, 6),
  ('ember',    'Ember Archipelago', 'Mathematics', 'Relight the island beacons before the long night.',
     'The sea-lights that guide traders between the islands have gone dark. You are a navigator''s apprentice with a patched boat and one working lantern. Island by island you rebuild lighthouses and reopen trade routes, and learn the beacons failed because the islands stopped sharing the Ledger of Tides. At Beacon Isle you relight the master beacon, then teach a new apprentice to read the Ledger so it never goes dark again.',
     'Light is shared or it fades. Knowledge grows when you pass it on, and honest numbers make fair trade.',
     'The Night Tide: rising water where each step raises or lowers the level.', '#2ED3E6', true, 7),
  ('sundial',  'Sundial City', 'English', 'A city that lost its voice gets it back one sentence at a time.',
     'Every noon the Great Bell tells the city the hour and its laws. It has cracked, and now every sign, notice and speech comes out garbled. You are a word-smith''s apprentice. You repair signs, take witness statements and write letters that open doors, and find that a badly written false notice has split two districts. You write the true public address that reunites them, and the bell is recast.',
     'Clear words build fair cities. Everyone deserves to be heard, and telling the truth plainly is a duty.',
     'The Rumour: a false notice taken apart with evidence and rewritten clearly.', '#F6B93B', true, 8),
  ('skyroot',  'Skyroot Frontier', 'Science', 'Heal a failing forest canopy before the rains fail.',
     'Research stations in the rainforest canopy have stopped reporting, and the water cycle below them is breaking. You are a junior field scientist. You trace pollution, erosion and invasive growth, rebuild habitats and restore a river, then bring the stations back online and present your findings to the village council.',
     'We inherit the land and answer for it. Look at the evidence before acting, and decide as a community.',
     'The Blight: a spreading contamination traced to its source before it reaches the river.', '#4BD37B', true, 9),
  ('signal',   'Signal Ridge', 'Technology', 'Reconnect the mountain villages by rebuilding the signal network.',
     'A storm has cut the relay line across the ridge, and the villages can no longer call for help or share news. You are a relay-tech apprentice. You climb station by station, routing signals, fixing circuits and writing step-by-step instructions for relay bots. At Summit Tower you program the last relay so every village comes online at once.',
     'Build things that connect people. Technology serves the community, and big problems are solved in small steps.',
     'The Whiteout: nothing is visible, so the player gives the relay bot a correct sequence of instructions.', '#FF8A3D', true, 10)
on conflict (realm_id) do nothing;

insert into public.journey_zones (realm_id, zone_no, name, story)
select v.realm, v.n, v.name, null
from (values
  ('odyssey',1,'Sunrise Shore'),('odyssey',2,'Dune Road'),('odyssey',3,'Teal Lagoon'),('odyssey',4,'Cloud Ridge'),('odyssey',5,'Starfall Peak'),
  ('biome',1,'Fern Hollow'),('biome',2,'Mud Flats'),('biome',3,'River Bend'),('biome',4,'Canopy Walk'),('biome',5,'Heart Grove'),
  ('windward',1,'Harbour'),('windward',2,'Open Sea'),('windward',3,'Gull Rocks'),('windward',4,'Storm Belt'),('windward',5,'Far Light'),
  ('delve',1,'Upper Caves'),('delve',2,'Glow Tunnels'),('delve',3,'Violet Deep'),('delve',4,'Crystal Hall'),('delve',5,'Core Vault'),
  ('casefiles',1,'Front Desk'),('casefiles',2,'Alley Row'),('casefiles',3,'The Archive'),('casefiles',4,'Rooftops'),('casefiles',5,'Courtroom'),
  ('frontier',1,'Outpost'),('frontier',2,'Dust Flats'),('frontier',3,'Relay Hill'),('frontier',4,'Ore Canyon'),('frontier',5,'Frontier Gate'),
  ('ember',1,'Lantern Cove'),('ember',2,'Trade Winds'),('ember',3,'Coral Market'),('ember',4,'Storm Gate'),('ember',5,'Beacon Isle'),
  ('sundial',1,'Bell Square'),('sundial',2,'Scribe Quarter'),('sundial',3,'Archive Hall'),('sundial',4,'Rumour Row'),('sundial',5,'Speaker''s Steps'),
  ('skyroot',1,'Understory'),('skyroot',2,'River Bend'),('skyroot',3,'Canopy Station'),('skyroot',4,'Erosion Ridge'),('skyroot',5,'Heart Tree'),
  ('signal',1,'Base Camp'),('signal',2,'Cable Pass'),('signal',3,'Relay One'),('signal',4,'Whiteout Col'),('signal',5,'Summit Tower')
) as v(realm, n, name)
on conflict do nothing;

-- Final-zone rewards for the new worlds: earned titles
insert into public.cosmetic_items (category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
select * from (values
  ('title','Navigator','Navigator','{}'::jsonb,0,'epic',false,'user','Relit the Ember Archipelago.',90,'earned','Clear Beacon Isle in Ember Archipelago'),
  ('title','Word-Smith','Word-Smith','{}'::jsonb,0,'epic',false,'user','Gave Sundial City its voice back.',91,'earned','Clear Speaker''s Steps in Sundial City'),
  ('title','Steward','Steward','{}'::jsonb,0,'epic',false,'user','Protected the Skyroot canopy.',92,'earned','Clear Heart Tree in Skyroot Frontier'),
  ('title','Relay Tech','Relay Tech','{}'::jsonb,0,'epic',false,'user','Reconnected Signal Ridge.',93,'earned','Clear Summit Tower in Signal Ridge')
) as seed(category, name, value, asset, price, rarity, requires_premium, scope, description, sort_order, source, earn_hint)
where not exists (select 1 from public.cosmetic_items c where c.category = seed.category and c.name = seed.name);

update public.journey_zones z set reward_item_id = (select id from public.cosmetic_items where category = 'title' and name = v.item)
from (values ('ember','Navigator'),('sundial','Word-Smith'),('skyroot','Steward'),('signal','Relay Tech')) as v(realm, item)
where z.realm_id = v.realm and z.zone_no = 5;

-- Generated quests: three per zone plus a mastery gate. Targets grow with the zone number.
insert into public.journey_quests (realm_id, zone_no, title, description, kind, metric, min_asked, t1, t2, t3, is_gate, sort_order)
select z.realm_id, z.zone_no, k.title, k.descr, k.kind, k.metric,
  case k.idx when 3 then 8 + z.zone_no when 4 then 10 + 2 * z.zone_no else 0 end,
  case k.idx when 1 then 4 + 2 * z.zone_no when 2 then 2 + z.zone_no when 3 then 60 + 2 * z.zone_no else 62 + 3 * z.zone_no end,
  case k.idx when 1 then 8 + 3 * z.zone_no when 2 then 4 + 2 * z.zone_no when 3 then 72 + 2 * z.zone_no else 78 + 2 * z.zone_no end,
  case k.idx when 1 then 12 + 4 * z.zone_no when 2 then 6 + 3 * z.zone_no when 3 then 85 + 2 * z.zone_no else 90 + z.zone_no end,
  k.idx = 4, k.idx
from public.journey_zones z
cross join (values
  (1, 'Sharp mind', 'Answer questions correctly in one run.', 'answer', 'correct_answers'),
  (2, 'On a roll', 'Get answers right in a row.', 'streak', 'best_streak'),
  (3, 'Clean run', 'Finish a run with high accuracy.', 'accuracy', 'accuracy'),
  (4, 'Mastery gate', 'A timed mastery run. Open it with enough stars in this zone.', 'gate', 'accuracy')
) as k(idx, title, descr, kind, metric)
where not exists (select 1 from public.journey_quests q where q.realm_id = z.realm_id and q.zone_no = z.zone_no);

notify pgrst, 'reload schema';
