-- Phase 11: make the private portal tables' deny-by-default posture explicit to the database linter.
drop policy if exists patient_portal_profiles_deny_client on private.patient_portal_profiles;
create policy patient_portal_profiles_deny_client
on private.patient_portal_profiles
for all to anon, authenticated
using (false)
with check (false);

drop policy if exists patient_portal_daily_limits_deny_client on private.patient_portal_daily_limits;
create policy patient_portal_daily_limits_deny_client
on private.patient_portal_daily_limits
for all to anon, authenticated
using (false)
with check (false);
