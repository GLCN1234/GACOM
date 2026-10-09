-- 20261021 Support desk: team members for a team LEAD (idempotent).
--
-- The desk's "assign" sheet needs the member list of the ticket's team. The admin-named RPC
-- (support_admin_team_members) is the wrong thing for the app to depend on, so team leads get
-- their own callable: lead of that team (or admin) only, active and inactive members, with the
-- number of open tickets each person is holding.
-- Columns user_id, name, role, active, open_ticket_count are the contract; username and cap are
-- extras so the admin screens can use the same call.

create or replace function public.support_team_members_for_lead(team_key text)
returns table (user_id uuid, name text, role text, active boolean, open_ticket_count integer, username text, cap integer)
language plpgsql stable security definer set search_path = public, pg_temp as $$
#variable_conflict use_column
declare tid uuid;
begin
  select tm.id into tid from public.support_teams tm where tm.key = support_team_members_for_lead.team_key;
  if auth.uid() is null or tid is null or not public.support_is_lead(tid) then   -- support_is_lead admits admins
    raise exception 'support: not authorised' using errcode = '42501';
  end if;
  return query
    select m.user_id,
           coalesce(p.display_name, p.username, 'Unknown')::text,
           m.role::text,
           m.active,
           (select count(*)::integer from public.support_tickets x
             where x.assigned_agent_id = m.user_id
               and x.status in ('new', 'open', 'pending_user', 'escalated')),
           p.username::text,
           m.cap
      from public.support_team_members m
      left join public.profiles p on p.id = m.user_id
     where m.team_id = tid
     order by m.role desc, p.display_name;
end $$;

revoke all on function public.support_team_members_for_lead(text) from public, anon;
grant execute on function public.support_team_members_for_lead(text) to authenticated, service_role;

notify pgrst, 'reload schema';
