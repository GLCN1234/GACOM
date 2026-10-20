-- School, state and country matching for competitions now ignores capital letters, a trailing
-- " State", and treats a school with no country recorded as Nigeria. Without this, "Ogun" and
-- "Ogun State" counted as different places and eligible students were turned away.
create or replace function public.comp_norm_place(p text)
returns text language sql immutable as $$
  select nullif(btrim(regexp_replace(lower(btrim(coalesce(p, ''))), '\s+state$', '')), '')
$$;

create or replace function check_competition_eligibility(p_competition_id uuid, p_user_id uuid)
returns boolean language plpgsql stable security definer set search_path = public, pg_temp as $$
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

  select si.institution_id, i.state, coalesce(i.country, 'Nigeria')
    into v_user_institution_id, v_user_state, v_user_country
    from student_institutions si
    join institutions i on i.id = si.institution_id
    where si.student_id = p_user_id;

  if v_user_institution_id is null then
    return false;
  end if;

  if v_scope_type = 'institution' then
    return v_user_institution_id = v_institution_id;
  elsif v_scope_type = 'state' then
    return public.comp_norm_place(v_user_state) is not null
       and public.comp_norm_place(v_user_state) = public.comp_norm_place(v_scope_state);
  elsif v_scope_type = 'country' then
    return public.comp_norm_place(v_user_country) = public.comp_norm_place(v_scope_country);
  end if;
  return false;
end $$;
grant execute on function check_competition_eligibility(uuid, uuid) to authenticated;
notify pgrst, 'reload schema';
