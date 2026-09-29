-- Institutions didn't have a country field — needed for country-wide
-- competition scoping. Defaults to Nigeria since that's the current
-- market; existing rows get backfilled to match.
alter table institutions add column if not exists country text default 'Nigeria';
update institutions set country = 'Nigeria' where country is null;

-- Competitions can now be scoped four ways: open to everyone, one
-- specific school, an entire state, or an entire country — not just
-- the single-school-or-nothing model from before. institution_id stays
-- for the 'institution' scope specifically.
alter table competitions add column if not exists scope_type text not null default 'all';
alter table competitions add column if not exists scope_state text;
alter table competitions add column if not exists scope_country text;

-- Real registration, not just automatic counting — needed so
-- eligibility (does this student's school/state/country actually
-- match the competition's scope) is checked once at signup, not
-- silently every time scores are queried.
create table if not exists competition_registrations (
  id uuid primary key default gen_random_uuid(),
  competition_id uuid not null references competitions(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  registered_at timestamptz not null default now(),
  unique (competition_id, user_id)
);
alter table competition_registrations enable row level security;
drop policy if exists "anyone views registrations" on competition_registrations;
create policy "anyone views registrations" on competition_registrations for select using (true);
drop policy if exists "users register themselves" on competition_registrations;
create policy "users register themselves" on competition_registrations for insert with check (auth.uid() = user_id);

-- Checks whether a user is actually eligible for a competition's
-- scope — the real "are you compliant with where this competition is
-- restricted to" check, run once at registration time.
create or replace function check_competition_eligibility(p_competition_id uuid, p_user_id uuid)
returns boolean language plpgsql stable as $$
declare
  v_scope_type text; v_scope_state text; v_scope_country text; v_institution_id uuid;
  v_user_institution_id uuid; v_user_state text; v_user_country text;
begin
  select scope_type, scope_state, scope_country, institution_id
    into v_scope_type, v_scope_state, v_scope_country, v_institution_id
    from competitions where id = p_competition_id;

  if v_scope_type is null or v_scope_type = 'all' then
    return true;
  end if;

  select si.institution_id, i.state, i.country
    into v_user_institution_id, v_user_state, v_user_country
    from student_institutions si
    join institutions i on i.id = si.institution_id
    where si.student_id = p_user_id;

  if v_user_institution_id is null then
    return false; -- no school registered at all — can't be eligible for any scoped competition
  end if;

  if v_scope_type = 'institution' then
    return v_user_institution_id = v_institution_id;
  elsif v_scope_type = 'state' then
    return v_user_state = v_scope_state;
  elsif v_scope_type = 'country' then
    return v_user_country = v_scope_country;
  end if;

  return false;
end;
$$;

-- Updated standings function — respects all four scope types, not
-- just the single-institution case from before.
create or replace function get_competition_standings(p_competition_id uuid)
returns table(user_id uuid, display_name text, avatar_url text, score integer, created_at timestamptz)
language sql stable as $$
  select gs.user_id, p.display_name, p.avatar_url, gs.score, gs.created_at
  from game_scores gs
  join competitions c on c.id = p_competition_id
  join profiles p on p.id = gs.user_id
  where gs.game_name = c.game_name
    and gs.created_at >= c.starts_at
    and gs.created_at <= c.ends_at
    and (
      c.scope_type is null or c.scope_type = 'all'
      or (c.scope_type = 'institution' and exists (
        select 1 from student_institutions si where si.student_id = gs.user_id and si.institution_id = c.institution_id
      ))
      or (c.scope_type = 'state' and exists (
        select 1 from student_institutions si join institutions i on i.id = si.institution_id
        where si.student_id = gs.user_id and i.state = c.scope_state
      ))
      or (c.scope_type = 'country' and exists (
        select 1 from student_institutions si join institutions i on i.id = si.institution_id
        where si.student_id = gs.user_id and i.country = c.scope_country
      ))
    )
  order by gs.score desc
  limit 10;
$$;
