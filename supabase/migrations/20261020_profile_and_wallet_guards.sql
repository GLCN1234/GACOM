-- 20261020 profile and wallet guards: SUPERSEDED, intentionally a no-op.
--
-- The profile guard (role / wallet / ban / verification) and the paid-competition entry
-- (join_paid_competition + the participant guard) are implemented once, in
-- 20261020_security_hardening.sql (sec_profiles_guard, sec_participants_guard,
-- join_paid_competition). This file used to add a second, overlapping set of triggers; running
-- both guards would have been redundant. The hardening file also drops those older objects
-- (trg_guard_profile_protected_columns, trg_guard_participant_payment_status, is_caller_admin)
-- if an earlier version of this file was ever applied. Safe to run any number of times.
do $$ begin null; end $$;
