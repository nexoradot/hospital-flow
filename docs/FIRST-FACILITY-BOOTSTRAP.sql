-- OWNER-ONLY ONE-TIME SETUP
-- Sign up the first administrator in the app, then run this script in Supabase SQL Editor.
-- Replace the sample admin email, facility code and name. Never expose this as a public RPC.

begin;
do $$
declare
  v_admin_email text := lower(trim('REPLACE_WITH_ADMIN_EMAIL'));
  v_facility_code text := 'DEMO-HOSPITAL';
  v_facility_name text := 'Demo Hospital';
  v_user_id uuid;
  v_facility_id uuid;
  v_department_id uuid;
begin
  if v_admin_email = 'replace_with_admin_email' or position('@' in v_admin_email) < 2 then
    raise exception 'Replace REPLACE_WITH_ADMIN_EMAIL with the administrator email before running.';
  end if;
  select id into v_user_id from auth.users where lower(email) = v_admin_email;
  if v_user_id is null then
    raise exception 'No auth user found for %. Sign up first.', v_admin_email;
  end if;
  if exists (select 1 from public.facilities where code = v_facility_code) then
    raise exception 'Facility code % already exists. Choose a unique code.', v_facility_code;
  end if;
  insert into public.facilities(code,name,timezone,status)
  values(v_facility_code,v_facility_name,'Africa/Nairobi','active')
  returning id into v_facility_id;
  insert into public.facility_memberships(facility_id,user_id,role,status,created_by)
  values(v_facility_id,v_user_id,'facility_admin','active',v_user_id);
  insert into public.departments(facility_id,code,name,status)
  values(v_facility_id,'GENERAL','General Services','active')
  returning id into v_department_id;
  insert into public.services(facility_id,department_id,code,name,booking_enabled,walk_in_enabled,status)
  values
    (v_facility_id,v_department_id,'OPD','Outpatient Department',true,true,'active'),
    (v_facility_id,v_department_id,'TRIAGE','Triage Desk',false,true,'active');
  raise notice 'Created facility % (%) and assigned administrator %.',v_facility_name,v_facility_id,v_admin_email;
end $$;
commit;

-- Creates demo facility configuration only. Review service lists and policies before live use.
