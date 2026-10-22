-- Phase 6: allow facility administrators/managers to maintain their own departments and services.
-- Records are deactivated instead of deleted so historical appointments and tickets remain intelligible.
drop policy if exists departments_insert_admin on public.departments;
create policy departments_insert_admin
on public.departments for insert to authenticated
with check ((select private.has_facility_role(facility_id, array['facility_admin','facility_manager']::text[])));

drop policy if exists departments_update_admin on public.departments;
create policy departments_update_admin
on public.departments for update to authenticated
using ((select private.has_facility_role(facility_id, array['facility_admin','facility_manager']::text[])))
with check ((select private.has_facility_role(facility_id, array['facility_admin','facility_manager']::text[])));

drop policy if exists services_insert_admin on public.services;
create policy services_insert_admin
on public.services for insert to authenticated
with check ((select private.has_facility_role(facility_id, array['facility_admin','facility_manager']::text[])));

drop policy if exists services_update_admin on public.services;
create policy services_update_admin
on public.services for update to authenticated
using ((select private.has_facility_role(facility_id, array['facility_admin','facility_manager']::text[])))
with check ((select private.has_facility_role(facility_id, array['facility_admin','facility_manager']::text[])));
