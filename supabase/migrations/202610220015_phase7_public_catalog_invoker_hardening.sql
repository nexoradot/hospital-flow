-- Phase 7 hardening: keep exposed portal wrappers SECURITY INVOKER and make only the safe directory public.
-- Public catalogue data contains no patient information.
drop policy if exists facilities_public_catalog on public.facilities;
create policy facilities_public_catalog on public.facilities
for select to anon using (status = 'active');

drop policy if exists departments_public_catalog on public.departments;
create policy departments_public_catalog on public.departments
for select to anon using (
  status = 'active' and exists (
    select 1 from public.facilities f
    where f.id = departments.facility_id and f.status = 'active'
  )
);

drop policy if exists services_public_catalog on public.services;
create policy services_public_catalog on public.services
for select to anon using (
  status = 'active' and walk_in_enabled and exists (
    select 1 from public.facilities f
    join public.departments d on d.facility_id = f.id
    where f.id = services.facility_id
      and f.status = 'active'
      and d.id = services.department_id
      and d.status = 'active'
  )
);

grant select on public.facilities, public.departments, public.services to anon;

create or replace function public.get_patient_portal_directory()
returns table (
  facility_id uuid, facility_code text, facility_name text, facility_timezone text,
  department_id uuid, department_code text, department_name text,
  service_id uuid, service_code text, service_name text, booking_enabled boolean, walk_in_enabled boolean
)
language sql stable security invoker set search_path = ''
as $function$
  select f.id, f.code, f.name, f.timezone, d.id, d.code, d.name,
         s.id, s.code, s.name, s.booking_enabled, s.walk_in_enabled
  from public.facilities f
  join public.departments d on d.facility_id = f.id and d.status = 'active'
  join public.services s on s.facility_id = f.id and s.department_id = d.id and s.status = 'active'
  where f.status = 'active' and s.walk_in_enabled
  order by f.name, d.name, s.name;
$function$;
revoke all on function public.get_patient_portal_directory() from public;
grant execute on function public.get_patient_portal_directory() to anon, authenticated;

-- Private SECURITY DEFINER helpers are not in an exposed API schema; the public RPC wrappers run as invokers.
grant usage on schema private to authenticated;
grant execute on function private.create_patient_portal_ticket(text, uuid, text, text) to authenticated;
grant execute on function private.get_patient_portal_ticket_status(text, text) to authenticated;

create or replace function public.create_patient_portal_ticket(
  p_facility_code text, p_service_id uuid, p_first_name text, p_last_name text
)
returns table(ticket_code text, queue_date date, status text, service_name text, department_name text)
language sql security invoker set search_path = ''
as $function$
  select * from private.create_patient_portal_ticket(p_facility_code, p_service_id, p_first_name, p_last_name);
$function$;
revoke all on function public.create_patient_portal_ticket(text, uuid, text, text) from public, anon;
grant execute on function public.create_patient_portal_ticket(text, uuid, text, text) to authenticated;

create or replace function public.get_patient_portal_ticket_status(p_facility_code text, p_ticket_code text)
returns table(ticket_code text, queue_date date, status text, service_name text, department_name text, called_at timestamptz)
language sql security invoker set search_path = ''
as $function$
  select * from private.get_patient_portal_ticket_status(p_facility_code, p_ticket_code);
$function$;
revoke all on function public.get_patient_portal_ticket_status(text, text) from public, anon;
grant execute on function public.get_patient_portal_ticket_status(text, text) to authenticated;
