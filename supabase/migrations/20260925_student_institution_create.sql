-- Lets any signed-in student add their school if a search turns up
-- nothing — the exact "search first, create if genuinely missing" flow
-- requested, rather than students being stuck with only what's already
-- in the list. No approval gate by design (matches the described flow),
-- but every new row is a normal institutions row, immediately visible
-- and searchable for the next student from that same school.
alter table institutions enable row level security;
drop policy if exists "students can add new institutions" on institutions;
create policy "students can add new institutions" on institutions for insert
  with check (auth.uid() is not null);
