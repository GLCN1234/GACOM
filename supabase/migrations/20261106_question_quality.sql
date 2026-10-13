-- Curriculum question quality guard.
--
-- A game draws questions one at a time, in any order, with the options shuffled.
-- A question must therefore stand on its own. These rules keep out questions that
-- lean on a passage, poem, diagram or table the player cannot see, options that
-- only work in a fixed order ("All of the above", "Both A and B"), and questions
-- whose stored answer is not one of their options.
--
-- Nothing is deleted. Questions that fail are moved into
-- institution_curricula.quarantined_questions so they can be rewritten and put
-- back. The check runs on every insert or update of generated_questions, so a
-- hand-written insert or the question generator can no longer bring them back.
--
-- Safe to run more than once.

alter table public.institution_curricula
  add column if not exists quarantined_questions jsonb not null default '[]'::jsonb;

-- ---------------------------------------------------------------- rules

-- Words that point at something outside the question.
create or replace function public.edu_q_unseen(t text)
returns boolean
language plpgsql
immutable
as $$
declare
  pre text := '(?:according to|based on|from|in|using|refer to|read|reading|within|throughout)';
  vn  text := '(?:diagram|figure|picture|image|graph|chart|illustration|table)';
  re  text;
begin
  re := '\y(?:the|this)\s+(?:passage|extract|excerpt|article)\y'
     || '|\y(?:why|how) does the (?:author|writer|poet|narrator)\y'
     || '|\ythe\s+(?:author|writer|poet|narrator)(?:[''’]s)?\s+(?:choice|decision|use of|description of|mention of|inclusion|reason|says|states|tells|describes|mentions|implies|suggests|uses|intends|means)\y'
     || '|\yin this context\y'
     || '|\y' || pre || '\s+(?:the|this)\s+(?:poem|paragraph|text|dialogue|comprehension)\y(?![''’]s)'
     || '|\y(?:poem|paragraph|text|passage|extract|excerpt|dialogue)\s+(?:above|below)\y'
     || '|\y(?:above|below|following)\s+(?:passage|poem|text|extract|excerpt|dialogue|paragraph)\y'
     || '|\y' || vn || '\y[^.?!]{0,25}\y(?:above|below)\y'
     || '|\y(?:above|below|following|given)\s+' || vn || '\y'
     || '|\yin the (?:diagram|figure|picture|image|graph|chart|illustration)\y'
     || '|\ythe (?:diagram|figure|picture|image|graph|chart|illustration) (?:shows|above|below)\y'
     || '|\y(?:shown|given|drawn)\s+(?:above|below)\y';
  return t ~* re;
end;
$$;

-- Text quoted inside the question, so the question carries its own material.
create or replace function public.edu_q_quoted(t text)
returns boolean
language sql
immutable
as $$
  select t ~ '[“"][^”"]{25,}[”"]'
      or t ~ '(^|[\s:(])''([^'']|(?<=\w)''(?=\w)){25,}''([\s.,;:?!)]|$)';
$$;

create or replace function public.edu_q_long_quoted(t text)
returns boolean
language sql
immutable
as $$
  select t ~ '[“"][^”"]{150,}[”"]';
$$;

-- Options that only make sense in one fixed order.
create or replace function public.edu_q_positional(o text)
returns boolean
language sql
immutable
as $$
  select o ~* '\y(?:all|none|both|neither)\s+of\s+the\s+above\y'
      or o ~* '\yboth\s+[a-d]\s+and\s+[a-d]\y'
      or o ~* '\y[a-d]\s+and\s+[a-d]\s+only\y'
      or o ~* '^\s*[a-d]\s+and\s+[a-d]\s*$'
      or o ~* '\yabove\s+options?\y';
$$;

-- True when the question can be played on its own.
create or replace function public.edu_q_usable(q jsonb)
returns boolean
language plpgsql
immutable
as $$
declare
  t text := coalesce(q->>'question', q->>'q', '');
  opts jsonb := coalesce(q->'options', q->'opts');
  ans jsonb := coalesce(q->'answer', q->'a', q->'correct');
  o jsonb;
  found boolean := false;
  idx int;
begin
  if btrim(t) = '' then return false; end if;
  if public.edu_q_unseen(t) and not public.edu_q_quoted(t) then return false; end if;
  if opts is not null and jsonb_typeof(opts) = 'array' then
    for o in select * from jsonb_array_elements(opts) loop
      if public.edu_q_positional(o #>> '{}') then return false; end if;
    end loop;
    -- the stored answer must be one of the options, an index, or a letter
    if ans is not null and jsonb_typeof(ans) <> 'null' then
      if jsonb_typeof(ans) = 'number' then
        idx := (ans #>> '{}')::numeric::int;
        found := idx >= 0 and idx < jsonb_array_length(opts);
      else
        for o in select * from jsonb_array_elements(opts) loop
          if (o #>> '{}') = (ans #>> '{}') then found := true; end if;
        end loop;
        if not found and length(btrim(ans #>> '{}')) = 1 then
          idx := ascii(upper(btrim(ans #>> '{}'))) - 65;
          found := idx >= 0 and idx < jsonb_array_length(opts);
        end if;
      end if;
      if not found then return false; end if;
    end if;
  end if;
  return true;
end;
$$;

-- Splits one topic's questions into the playable ones and the rest.
-- A topic that carries a full passage inside one question has its other
-- questions asked about that passage, so only questions with their own quoted
-- text stay.
create or replace function public.edu_q_split(qs jsonb, out good jsonb, out bad jsonb)
language plpgsql
immutable
as $$
declare
  e jsonb;
  t text;
  anchored boolean := false;
begin
  good := '[]'::jsonb;
  bad := '[]'::jsonb;
  if qs is null or jsonb_typeof(qs) <> 'array' then
    good := coalesce(qs, '[]'::jsonb);
    return;
  end if;
  for e in select * from jsonb_array_elements(qs) loop
    t := coalesce(e->>'question', e->>'q', '');
    if public.edu_q_long_quoted(t) then anchored := true; end if;
  end loop;
  for e in select * from jsonb_array_elements(qs) loop
    t := coalesce(e->>'question', e->>'q', '');
    if public.edu_q_usable(e) and (not anchored or public.edu_q_quoted(t)) then
      good := good || jsonb_build_array(e);
    else
      bad := bad || jsonb_build_array(e);
    end if;
  end loop;
end;
$$;

-- ---------------------------------------------------------------- guard

create or replace function public.edu_curricula_guard()
returns trigger
language plpgsql
as $$
declare
  g jsonb;
  b jsonb;
begin
  if NEW.generated_questions is null or jsonb_typeof(NEW.generated_questions) <> 'array' then
    return NEW;
  end if;
  select s.good, s.bad into g, b from public.edu_q_split(NEW.generated_questions) s;
  if jsonb_array_length(b) > 0 then
    NEW.generated_questions := g;
    NEW.quarantined_questions := coalesce(NEW.quarantined_questions, '[]'::jsonb) || b;
    NEW.total_questions := jsonb_array_length(g);
  end if;
  return NEW;
end;
$$;

drop trigger if exists edu_curricula_guard on public.institution_curricula;
create trigger edu_curricula_guard
  before insert or update of generated_questions on public.institution_curricula
  for each row execute function public.edu_curricula_guard();

-- ---------------------------------------------------------------- clean what is already there

update public.institution_curricula
   set generated_questions = generated_questions
 where generated_questions is not null
   and jsonb_typeof(generated_questions) = 'array'
   and jsonb_array_length(generated_questions) > 0;

-- What was set aside, topic by topic. Rewrite these and add them back.
create or replace view public.edu_quarantine_report as
select id, subject, class_level, topic,
       jsonb_array_length(generated_questions) as playable,
       jsonb_array_length(quarantined_questions) as set_aside
  from public.institution_curricula
 where jsonb_array_length(quarantined_questions) > 0
 order by set_aside desc;
