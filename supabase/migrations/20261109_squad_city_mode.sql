-- City Patrol: a second squad mode. The host picks the mode while the squad is open.
-- 'arena' = free for all match (existing), 'city' = co-op patrol of the open city.
create or replace function public.darkom_set_squad_mode(p_squad uuid, p_mode text)
returns jsonb language plpgsql security definer set search_path = public as $$
declare
  uid uuid := auth.uid();
  s public.darkom_squads;
begin
  if uid is null then return jsonb_build_object('success', false, 'error', 'Please sign in'); end if;
  if p_mode is null or p_mode not in ('arena', 'city') then
    return jsonb_build_object('success', false, 'error', 'Unknown mode');
  end if;
  select * into s from public.darkom_squads where id = p_squad for update;
  if not found then return jsonb_build_object('success', false, 'error', 'Squad not found'); end if;
  if s.host_id <> uid then return jsonb_build_object('success', false, 'error', 'Only the host can change the mode'); end if;
  if s.status <> 'open' then return jsonb_build_object('success', false, 'error', 'This squad already started or closed'); end if;
  update public.darkom_squads set mode = p_mode, updated_at = now() where id = p_squad;
  return jsonb_build_object('success', true, 'squad', public.darkom_squad_json(p_squad));
end;
$$;

grant execute on function public.darkom_set_squad_mode(uuid, text) to authenticated;
notify pgrst, 'reload schema';
