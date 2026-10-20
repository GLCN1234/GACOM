-- Admin edit and delete for competitions, flyer upload for admins, and GACOM Edu
-- competitions: registration, a banner feed, and automatic Maths and English scoring.
--
-- How Edu scoring works
--   * Every Edu game (open worlds, Odyssey, quests, school topics) already reports its result per
--     subject through EduProgressRecorder -> record_edu_session. The app now also calls
--     edu_comp_record(subject, questions, correct) from that same place.
--   * edu_comp_record finds the student's live Edu competitions, keeps only the competition's subjects
--     (Maths and English by default), turns correct answers into points, applies the caps, and writes
--     a row to edu_comp_log. Standings are always summed from that log.
--   * The result is reported by the phone, so the caps (per session, per hour, per day) limit what a
--     modified app could add. If real prizes depend on it, questions must be checked on the server.

-- ---------------------------------------------------------------------------
-- 1. New competition columns
-- ---------------------------------------------------------------------------
alter table public.competitions add column if not exists kind text not null default 'general';
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'competitions_kind_chk') then
    alter table public.competitions add constraint competitions_kind_chk check (kind in ('general', 'edu'));
  end if;
end $$;
alter table public.competitions add column if not exists edu_subjects text[] not null default array['math', 'english'];
alter table public.competitions add column if not exists points_per_correct integer not null default 10;
alter table public.competitions add column if not exists daily_point_cap integer not null default 1500;
do $$ begin
  if not exists (select 1 from pg_constraint where conname = 'competitions_points_chk') then
    alter table public.competitions add constraint competitions_points_chk
      check (points_per_correct between 1 and 1000 and daily_point_cap between 10 and 100000);
  end if;
end $$;

-- Hosts must not be able to change how Edu points work.
create or replace function public.sec_competitions_guard()
returns trigger language plpgsql set search_path = public, pg_temp as $$
begin
  if not public.sec_client() or public.sec_is_admin() then return new; end if;
  if tg_op = 'INSERT' then
    raise exception 'Competitions are created by verified hosts from the Host screen' using errcode = '42501';
  end if;
  if new.prize_pool is distinct from old.prize_pool
     or new.entry_fee is distinct from old.entry_fee
     or new.competition_type is distinct from old.competition_type
     or new.status is distinct from old.status
     or new.winner_id is distinct from old.winner_id
     or new.winner_announced_at is distinct from old.winner_announced_at
     or new.created_by is distinct from old.created_by
     or new.is_admin_created is distinct from old.is_admin_created
     or new.platform_fee_percent is distinct from old.platform_fee_percent
     or new.max_participants is distinct from old.max_participants
     or new.starts_at is distinct from old.starts_at
     or new.ends_at is distinct from old.ends_at
     or new.hosted is distinct from old.hosted
     or new.prize_secured is distinct from old.prize_secured
     or new.is_featured is distinct from old.is_featured
     or new.kind is distinct from old.kind
     or new.edu_subjects is distinct from old.edu_subjects
     or new.points_per_correct is distinct from old.points_per_correct
     or new.daily_point_cap is distinct from old.daily_point_cap then
    raise exception 'permission denied: protected competition field' using errcode = '42501';
  end if;
  return new;
end $$;

-- ---------------------------------------------------------------------------
-- 2. Flyer uploads by admins (the bucket already exists for hosts)
-- ---------------------------------------------------------------------------
insert into storage.buckets (id, name, public) values ('competition-banners', 'competition-banners', true)
on conflict (id) do nothing;
-- If the bucket already existed as private, flyers upload but never display. Force it public.
update storage.buckets set public = true where id = 'competition-banners';
drop policy if exists "comp banners read" on storage.objects;
create policy "comp banners read" on storage.objects for select using (bucket_id = 'competition-banners');
drop policy if exists "comp banners admin insert" on storage.objects;
create policy "comp banners admin insert" on storage.objects for insert to authenticated
  with check (bucket_id = 'competition-banners' and public.sec_is_admin());
drop policy if exists "comp banners admin update" on storage.objects;
create policy "comp banners admin update" on storage.objects for update to authenticated
  using (bucket_id = 'competition-banners' and public.sec_is_admin());
drop policy if exists "comp banners admin delete" on storage.objects;
create policy "comp banners admin delete" on storage.objects for delete to authenticated
  using (bucket_id = 'competition-banners' and public.sec_is_admin());

-- ---------------------------------------------------------------------------
-- 3. Status follows the clock for Edu competitions
-- ---------------------------------------------------------------------------
create or replace function public.comp_sync_status()
returns void language sql security definer set search_path = public, pg_temp as $$
  update public.competitions set status = 'live'
   where kind = 'edu' and status = 'upcoming' and starts_at <= now() and ends_at > now();
  update public.competitions set status = 'ended'
   where kind = 'edu' and status in ('upcoming', 'live') and ends_at <= now();
$$;
revoke all on function public.comp_sync_status() from public, anon, authenticated;

-- ---------------------------------------------------------------------------
-- 4. Admin edit and delete
-- ---------------------------------------------------------------------------
create or replace function public.admin_update_competition(p_id uuid, p jsonb)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  c public.competitions;
  n_start timestamptz; n_end timestamptz;
  n_scope text; n_inst uuid; n_state text; n_country text;
  n_status text; n_kind text; n_subjects text[];
begin
  if not public.sec_is_admin() then return jsonb_build_object('success', false, 'error', 'Admins only'); end if;
  select * into c from public.competitions where id = p_id;
  if not found then return jsonb_build_object('success', false, 'error', 'Competition not found'); end if;

  if p ? 'title' and btrim(coalesce(p ->> 'title', '')) = '' then
    return jsonb_build_object('success', false, 'error', 'Title is required');
  end if;
  if p ? 'game_name' and btrim(coalesce(p ->> 'game_name', '')) = '' then
    return jsonb_build_object('success', false, 'error', 'Game name is required');
  end if;

  n_start := case when p ? 'starts_at' then (p ->> 'starts_at')::timestamptz else c.starts_at end;
  n_end   := case when p ? 'ends_at'   then (p ->> 'ends_at')::timestamptz   else c.ends_at end;
  if n_end <= n_start then return jsonb_build_object('success', false, 'error', 'The end must be after the start'); end if;

  n_scope   := case when p ? 'scope_type' then p ->> 'scope_type' else c.scope_type end;
  n_inst    := case when p ? 'institution_id' then nullif(p ->> 'institution_id', '')::uuid else c.institution_id end;
  n_state   := case when p ? 'scope_state' then nullif(p ->> 'scope_state', '') else c.scope_state end;
  n_country := case when p ? 'scope_country' then nullif(p ->> 'scope_country', '') else c.scope_country end;
  if n_scope not in ('all', 'institution', 'state', 'country') then
    return jsonb_build_object('success', false, 'error', 'Unknown audience');
  end if;
  if (n_scope = 'institution' and n_inst is null) or (n_scope = 'state' and n_state is null) or (n_scope = 'country' and n_country is null) then
    return jsonb_build_object('success', false, 'error', 'Choose who can compete (school, state or country)');
  end if;
  if n_scope <> 'institution' then n_inst := null; end if;
  if n_scope <> 'state' then n_state := null; end if;
  if n_scope <> 'country' then n_country := null; end if;

  n_kind := case when p ? 'kind' then p ->> 'kind' else c.kind end;
  if n_kind not in ('general', 'edu') then return jsonb_build_object('success', false, 'error', 'Unknown competition kind'); end if;

  n_subjects := c.edu_subjects;
  if p ? 'edu_subjects' then
    n_subjects := array(select lower(btrim(x)) from jsonb_array_elements_text(p -> 'edu_subjects') x where btrim(x) <> '');
    if coalesce(array_length(n_subjects, 1), 0) = 0 then
      return jsonb_build_object('success', false, 'error', 'Pick at least one subject');
    end if;
  end if;

  n_status := case when p ? 'status' then p ->> 'status' else c.status::text end;
  if n_status not in ('upcoming', 'live', 'ended', 'cancelled') then
    return jsonb_build_object('success', false, 'error', 'Unknown status');
  end if;
  -- Changing the dates moves an unfinished competition to the right state for the new dates.
  if not (p ? 'status') and (p ? 'starts_at' or p ? 'ends_at') and c.status::text in ('upcoming', 'live') then
    n_status := case when n_start > now() then 'upcoming' when n_end > now() then 'live' else 'ended' end;
  end if;

  update public.competitions set
    title = case when p ? 'title' then btrim(p ->> 'title') else title end,
    description = case when p ? 'description' then nullif(btrim(coalesce(p ->> 'description', '')), '') else description end,
    rules = case when p ? 'rules' then nullif(btrim(coalesce(p ->> 'rules', '')), '') else rules end,
    game_name = case when p ? 'game_name' then btrim(p ->> 'game_name') else game_name end,
    banner_url = case when p ? 'banner_url' then nullif(btrim(coalesce(p ->> 'banner_url', '')), '') else banner_url end,
    starts_at = n_start,
    ends_at = n_end,
    registration_deadline = case when p ? 'registration_deadline' then nullif(p ->> 'registration_deadline', '')::timestamptz else registration_deadline end,
    prize_pool = case when p ? 'prize_pool' then coalesce(nullif(p ->> 'prize_pool', '')::numeric, 0) else prize_pool end,
    entry_fee = case when p ? 'entry_fee' then coalesce(nullif(p ->> 'entry_fee', '')::numeric, 0) else entry_fee end,
    competition_type = case when p ? 'competition_type' then (p ->> 'competition_type')::competition_type else competition_type end,
    max_participants = case when p ? 'max_participants' then nullif(p ->> 'max_participants', '')::integer else max_participants end,
    target_score = case when p ? 'target_score' then nullif(p ->> 'target_score', '')::integer else target_score end,
    is_featured = case when p ? 'is_featured' then coalesce((p ->> 'is_featured')::boolean, false) else is_featured end,
    scope_type = n_scope, institution_id = n_inst, scope_state = n_state, scope_country = n_country,
    kind = n_kind,
    edu_subjects = n_subjects,
    points_per_correct = case when p ? 'points_per_correct' then coalesce(nullif(p ->> 'points_per_correct', '')::integer, points_per_correct) else points_per_correct end,
    daily_point_cap = case when p ? 'daily_point_cap' then coalesce(nullif(p ->> 'daily_point_cap', '')::integer, daily_point_cap) else daily_point_cap end,
    status = n_status::competition_status
  where id = p_id;
  return jsonb_build_object('success', true, 'status', n_status);
exception
  when check_violation then
    return jsonb_build_object('success', false, 'error', 'A value is outside the allowed range (points 1 to 1000, daily cap 10 to 100000)');
  when invalid_text_representation or datetime_field_overflow or invalid_datetime_format or numeric_value_out_of_range then
    return jsonb_build_object('success', false, 'error', 'One of the values is not valid');
end $$;
grant execute on function public.admin_update_competition(uuid, jsonb) to authenticated;

create or replace function public.admin_delete_competition(p_id uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
begin
  if not public.sec_is_admin() then return jsonb_build_object('success', false, 'error', 'Admins only'); end if;
  delete from public.competitions where id = p_id;
  if not found then return jsonb_build_object('success', false, 'error', 'Competition not found'); end if;
  return jsonb_build_object('success', true);
exception
  when insufficient_privilege then
    return jsonb_build_object('success', false, 'error', sqlerrm);
  when foreign_key_violation then
    return jsonb_build_object('success', false, 'error', 'This competition has linked records (entries, payments or hosting). Set its status to cancelled instead.');
end $$;
grant execute on function public.admin_delete_competition(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- 5. Edu points log
-- ---------------------------------------------------------------------------
create table if not exists public.edu_comp_log (
  id bigserial primary key,
  competition_id uuid not null references public.competitions(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  subject text not null,
  questions integer not null,
  correct integer not null,
  points integer not null,
  created_at timestamptz not null default now()
);
create index if not exists edu_comp_log_comp_user on public.edu_comp_log (competition_id, user_id);
create index if not exists edu_comp_log_user_time on public.edu_comp_log (user_id, created_at);
alter table public.edu_comp_log enable row level security;
revoke all on public.edu_comp_log from anon, authenticated;

create or replace function public.edu_comp_subject(p text)
returns text language sql immutable as $$
  select case lower(btrim(coalesce(p, '')))
    when 'math' then 'math' when 'mathematics' then 'math' when 'algebra' then 'math' when 'geometry' then 'math'
    when 'statistics' then 'math' when 'simultaneous' then 'math' when 'simultaneous eqns' then 'math'
    when 'english' then 'english' when 'english language' then 'english'
    else lower(btrim(coalesce(p, ''))) end
$$;

-- ---------------------------------------------------------------------------
-- 6. Register, banners, record, standings
-- ---------------------------------------------------------------------------
create or replace function public.edu_comp_register(p_comp uuid)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  c public.competitions;
  tag text;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  perform public.comp_sync_status();
  select * into c from public.competitions where id = p_comp and kind = 'edu';
  if not found then return jsonb_build_object('success', false, 'error', 'Competition not found'); end if;
  if c.status in ('ended', 'cancelled') or c.ends_at <= now() then
    return jsonb_build_object('success', false, 'error', 'This competition is closed');
  end if;
  if c.registration_deadline is not null and now() > c.registration_deadline then
    return jsonb_build_object('success', false, 'error', 'Registration has closed');
  end if;
  if exists (select 1 from public.competition_participants where competition_id = p_comp and user_id = uid) then
    return jsonb_build_object('success', true, 'already', true);
  end if;
  if not exists (select 1 from public.student_institutions where student_id = uid) then
    return jsonb_build_object('success', false, 'code', 'need_school', 'error', 'Choose your school in Edu setup first');
  end if;
  if not public.check_competition_eligibility(p_comp, uid) then
    return jsonb_build_object('success', false, 'code', 'not_eligible', 'error', 'This competition is not open to your school');
  end if;
  if coalesce(c.entry_fee, 0) > 0 then
    return jsonb_build_object('success', false, 'error', 'This competition has an entry fee. Join it from the Competitions page.');
  end if;
  if c.max_participants is not null
     and (select count(*) from public.competition_participants where competition_id = p_comp) >= c.max_participants then
    return jsonb_build_object('success', false, 'error', 'This competition is full');
  end if;
  select gamer_tag into tag from public.profiles where id = uid;
  insert into public.competition_participants (competition_id, user_id, payment_status, gamer_tag_used)
  values (p_comp, uid, 'free', tag);
  return jsonb_build_object('success', true);
end $$;
grant execute on function public.edu_comp_register(uuid) to authenticated;

create or replace function public.edu_comp_banners()
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  has_school boolean;
  res jsonb;
begin
  if uid is null then return '[]'::jsonb; end if;
  perform public.comp_sync_status();
  select exists (select 1 from public.student_institutions where student_id = uid) into has_school;
  select coalesce(jsonb_agg(x.j order by x.starts_at), '[]'::jsonb) into res from (
    select c.starts_at,
           jsonb_build_object(
             'id', c.id, 'title', c.title, 'description', c.description, 'rules', c.rules,
             'banner_url', c.banner_url, 'kind', c.kind, 'status', c.status,
             'starts_at', c.starts_at, 'ends_at', c.ends_at, 'registration_deadline', c.registration_deadline,
             'prize_pool', c.prize_pool, 'entry_fee', c.entry_fee,
             'subjects', c.edu_subjects, 'points_per_correct', c.points_per_correct, 'daily_point_cap', c.daily_point_cap,
             'participants', (select count(*) from public.competition_participants cp where cp.competition_id = c.id),
             'registered', exists (select 1 from public.competition_participants cp where cp.competition_id = c.id and cp.user_id = uid),
             'has_school', has_school,
             'my_points', coalesce((select sum(l.points) from public.edu_comp_log l where l.competition_id = c.id and l.user_id = uid), 0)
           ) as j
      from public.competitions c
     where c.status in ('upcoming', 'live') and c.ends_at > now()
       and (c.kind = 'edu' or (c.is_featured and public.check_competition_eligibility(c.id, uid)))
     order by c.starts_at
     limit 5
  ) x;
  return res;
end $$;
grant execute on function public.edu_comp_banners() to authenticated;

create or replace function public.edu_comp_record(p_subject text, p_questions integer, p_correct integer)
returns jsonb language plpgsql security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  subj text := public.edu_comp_subject(p_subject);
  q integer; cr integer; pts integer; used integer; added integer := 0; recent integer;
  c record;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  q := least(greatest(coalesce(p_questions, 0), 0), 200);
  cr := least(greatest(coalesce(p_correct, 0), 0), q);
  if q = 0 then return jsonb_build_object('success', true, 'added', 0); end if;
  perform public.comp_sync_status();
  -- Games report one question at a time, so the hourly limit counts questions, not rows.
  select coalesce(sum(questions), 0) into recent from public.edu_comp_log where user_id = uid and created_at > now() - interval '1 hour';
  if recent >= 600 then return jsonb_build_object('success', false, 'error', 'Too many answers in the last hour'); end if;
  for c in
    select comp.id, comp.points_per_correct, comp.daily_point_cap
      from public.competitions comp
      join public.competition_participants cp on cp.competition_id = comp.id and cp.user_id = uid
     where comp.kind = 'edu' and comp.status = 'live' and comp.starts_at <= now() and comp.ends_at > now()
       and subj = any (comp.edu_subjects)
  loop
    select coalesce(sum(points), 0) into used from public.edu_comp_log
     where competition_id = c.id and user_id = uid
       and created_at >= (date_trunc('day', now() at time zone 'Africa/Lagos') at time zone 'Africa/Lagos');
    pts := least(cr * c.points_per_correct, greatest(c.daily_point_cap - used, 0));
    if pts > 0 then
      insert into public.edu_comp_log (competition_id, user_id, subject, questions, correct, points)
      values (c.id, uid, subj, q, cr, pts);
      update public.competition_participants set score = coalesce(score, 0) + pts
       where competition_id = c.id and user_id = uid;
      added := added + pts;
    end if;
  end loop;
  return jsonb_build_object('success', true, 'added', added);
end $$;
grant execute on function public.edu_comp_record(text, integer, integer) to authenticated;

create or replace function public.edu_comp_standings(p_comp uuid, p_limit integer default 50)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare
  uid uuid := auth.uid();
  lim integer := least(greatest(coalesce(p_limit, 50), 1), 200);
  res jsonb;
begin
  if uid is null then return jsonb_build_object('rows', '[]'::jsonb, 'me', null, 'total', 0); end if;
  with t as (
    select cp.user_id,
           coalesce(sum(l.points), 0)::int as pts,
           coalesce(sum(l.correct), 0)::int as cor,
           coalesce(sum(l.questions), 0)::int as qs,
           coalesce(sum(l.points) filter (where l.subject = 'math'), 0)::int as mp,
           coalesce(sum(l.points) filter (where l.subject = 'english'), 0)::int as ep,
           max(l.created_at) as last_at
      from public.competition_participants cp
      left join public.edu_comp_log l on l.competition_id = cp.competition_id and l.user_id = cp.user_id
     where cp.competition_id = p_comp
     group by cp.user_id),
  r as (
    select t.*, row_number() over (order by t.pts desc, t.last_at asc nulls last, t.user_id) as rk from t),
  j as (
    select r.*, p.display_name, p.avatar_url,
           (select i.name from public.student_institutions si join public.institutions i on i.id = si.institution_id
             where si.student_id = r.user_id limit 1) as school
      from r left join public.profiles p on p.id = r.user_id)
  select jsonb_build_object(
    'rows', coalesce((select jsonb_agg(to_jsonb(j) - 'last_at' order by j.rk) from j where j.rk <= lim), '[]'::jsonb),
    'me', (select to_jsonb(j) - 'last_at' from j where j.user_id = uid),
    'total', (select count(*) from j))
  into res;
  return res;
end $$;
grant execute on function public.edu_comp_standings(uuid, integer) to authenticated;

create or replace function public.edu_comp_school_standings(p_comp uuid)
returns jsonb language plpgsql stable security definer set search_path = public, pg_temp as $$
declare res jsonb;
begin
  if auth.uid() is null then return '[]'::jsonb; end if;
  select coalesce(jsonb_agg(z.j order by z.pts desc, z.name), '[]'::jsonb) into res from (
    select i.name, coalesce(sum(l.points), 0)::int as pts,
           jsonb_build_object('school', i.name, 'students', count(distinct cp.user_id),
                              'points', coalesce(sum(l.points), 0)::int) as j
      from public.competition_participants cp
      join public.student_institutions si on si.student_id = cp.user_id
      join public.institutions i on i.id = si.institution_id
      left join public.edu_comp_log l on l.competition_id = cp.competition_id and l.user_id = cp.user_id
     where cp.competition_id = p_comp
     group by i.id, i.name
     limit 100) z;
  return res;
end $$;
grant execute on function public.edu_comp_school_standings(uuid) to authenticated;

notify pgrst, 'reload schema';
