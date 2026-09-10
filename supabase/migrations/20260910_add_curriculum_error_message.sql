-- Adds a human-readable error/status message column so the institution
-- dashboard can show WHY a curriculum generation stalled or failed,
-- instead of just a bare status badge.
alter table institution_curricula
  add column if not exists error_message text;
