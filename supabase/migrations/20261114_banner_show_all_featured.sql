-- Featured competitions show on every signed-in user's home feed. Eligibility is enforced when joining.
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
       and (c.kind = 'edu' or c.is_featured)
     order by c.starts_at
     limit 5
  ) x;
  return res;
end $$;
grant execute on function public.edu_comp_banners() to authenticated;

notify pgrst, 'reload schema';
