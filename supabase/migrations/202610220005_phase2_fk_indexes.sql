-- Cover foreign keys used by appointments and audit trails.
begin;
create index appointments_created_by_idx on public.appointments(created_by);
create index appointments_facility_schedule_idx on public.appointments(facility_id, schedule_id);
create index patients_created_by_idx on public.patients(created_by);
create index service_schedules_created_by_idx on public.service_schedules(created_by);
commit;