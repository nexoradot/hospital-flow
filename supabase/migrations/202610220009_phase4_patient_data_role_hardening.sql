-- Phase 4 security hardening: limit patient-bearing reads to operational/clinical roles.
begin;

drop policy if exists patients_select_facility_member on public.patients;
create policy patients_select_operational_roles on public.patients
for select to authenticated
using ((select private.has_facility_role(facility_id,
  array['facility_admin','facility_manager','receptionist','triage_nurse','clinician','queue_manager']::text[])));

drop policy if exists appointments_select_facility_member on public.appointments;
create policy appointments_select_operational_roles on public.appointments
for select to authenticated
using ((select private.has_facility_role(facility_id,
  array['facility_admin','facility_manager','receptionist','triage_nurse','clinician','queue_manager']::text[])));

drop policy if exists queue_tickets_select_facility_member on public.queue_tickets;
create policy queue_tickets_select_operational_roles on public.queue_tickets
for select to authenticated
using ((select private.has_facility_role(facility_id,
  array['facility_admin','facility_manager','receptionist','triage_nurse','clinician','queue_manager']::text[])));

commit;