-- A notifications table already existed in this database (recipient_id,
-- sender_id, a notification_type enum, is_read, a data jsonb column) —
-- adapting to that real, pre-existing structure instead of creating a
-- conflicting one. No table creation here; only RLS, realtime, and the
-- triggers that actually populate it.
alter table notifications enable row level security;
drop policy if exists "users see own notifications" on notifications;
create policy "users see own notifications" on notifications for select using (auth.uid() = recipient_id);
drop policy if exists "users update own notifications" on notifications;
create policy "users update own notifications" on notifications for update using (auth.uid() = recipient_id);

create index if not exists notifications_recipient_unread_idx on notifications(recipient_id, is_read, created_at desc);

alter publication supabase_realtime add table notifications;

-- Real trigger: notify a house's creator when someone new joins.
-- 'community' is the closest existing enum value — this schema's
-- notification_type has no 'house' option, and adding one isn't
-- necessary when an existing value already fits well enough.
create or replace function notify_house_join()
returns trigger language plpgsql security definer as $$
declare v_creator uuid; v_house_name text; v_joiner_name text;
begin
  select created_by, name into v_creator, v_house_name from houses where id = new.house_id;
  if v_creator is null or v_creator = new.user_id then return new; end if;
  select display_name into v_joiner_name from profiles where id = new.user_id;
  insert into notifications (recipient_id, sender_id, type, title, body, data)
  values (v_creator, new.user_id, 'community', 'New house member',
    coalesce(v_joiner_name, 'Someone') || ' joined ' || coalesce(v_house_name, 'your house'),
    jsonb_build_object('link_route', '/houses'));
  return new;
end;
$$;
drop trigger if exists on_house_join_notify on house_members;
create trigger on_house_join_notify after insert on house_members for each row execute function notify_house_join();

-- Real trigger: notify house members (other than the sender) of a new
-- chat message — a real, working example of what the bell is for.
create or replace function notify_house_message()
returns trigger language plpgsql security definer as $$
declare v_house_name text; v_sender_name text;
begin
  select name into v_house_name from houses where id = new.house_id;
  select display_name into v_sender_name from profiles where id = new.user_id;
  insert into notifications (recipient_id, sender_id, type, title, body, data)
  select hm.user_id, new.user_id, 'community', coalesce(v_house_name, 'House chat'),
    coalesce(v_sender_name, 'Someone') || ': ' || left(new.message, 80),
    jsonb_build_object('link_route', '/houses/chat')
  from house_members hm
  where hm.house_id = new.house_id and hm.user_id != new.user_id;
  return new;
end;
$$;
drop trigger if exists on_house_message_notify on house_messages;
create trigger on_house_message_notify after insert on house_messages for each row execute function notify_house_message();

-- Real trigger: notify a student when a competition matching their
-- exact school/state/country scope goes live — the actual reason a
-- Ogun State competition should reach Ogun State students.
create or replace function notify_matching_competition()
returns trigger language plpgsql security definer as $$
begin
  if new.scope_type is null or new.scope_type = 'all' then
    insert into notifications (recipient_id, type, title, body, data)
    select p.id, 'competition', 'New competition: ' || new.title,
      'Open to everyone — ₦' || coalesce(new.prize_pool, 0) || ' prize pool',
      jsonb_build_object('link_route', '/competitions/' || new.id)
    from profiles p;
  elsif new.scope_type = 'institution' then
    insert into notifications (recipient_id, type, title, body, data)
    select si.student_id, 'competition', 'New competition: ' || new.title,
      'For your school — ₦' || coalesce(new.prize_pool, 0) || ' prize pool',
      jsonb_build_object('link_route', '/competitions/' || new.id)
    from student_institutions si where si.institution_id = new.institution_id;
  elsif new.scope_type = 'state' then
    insert into notifications (recipient_id, type, title, body, data)
    select si.student_id, 'competition', 'New competition: ' || new.title,
      'For schools in ' || new.scope_state || ' — ₦' || coalesce(new.prize_pool, 0) || ' prize pool',
      jsonb_build_object('link_route', '/competitions/' || new.id)
    from student_institutions si join institutions i on i.id = si.institution_id where i.state = new.scope_state;
  elsif new.scope_type = 'country' then
    insert into notifications (recipient_id, type, title, body, data)
    select si.student_id, 'competition', 'New competition: ' || new.title,
      'For schools in ' || new.scope_country || ' — ₦' || coalesce(new.prize_pool, 0) || ' prize pool',
      jsonb_build_object('link_route', '/competitions/' || new.id)
    from student_institutions si join institutions i on i.id = si.institution_id where i.country = new.scope_country;
  end if;
  return new;
end;
$$;
drop trigger if exists on_competition_created_notify on competitions;
create trigger on_competition_created_notify after insert on competitions for each row execute function notify_matching_competition();
