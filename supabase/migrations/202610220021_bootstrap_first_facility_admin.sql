-- Bootstrap the first Hospital Flow facility and its initial administrator.
-- This migration is intentionally guarded: it only runs on an empty facility setup
-- with exactly one registered auth account.
do $$
declare
  account_count integer;
  facility_count integer;
  membership_count integer;
  owner_user_id uuid;
  new_facility_id uuid;
begin
  select count(*), min(id::text)::uuid into account_count, owner_user_id
  from auth.users;

  select count(*) into facility_count from public.facilities;
  select count(*) into membership_count from public.facility_memberships;

  if facility_count <> 0 or membership_count <> 0 then
    raise exception 'Bootstrap stopped: facilities or memberships already exist.';
  end if;

  if account_count <> 1 or owner_user_id is null then
    raise exception 'Bootstrap stopped: expected exactly one registered auth account; found %.', account_count;
  end if;

  insert into public.facilities (code, name, timezone, status)
  values ('HF-DEMO', 'Hospital Flow Demo Facility', 'Africa/Nairobi', 'active')
  returning id into new_facility_id;

  insert into public.facility_memberships (facility_id, user_id, role, status, created_by)
  values (new_facility_id, owner_user_id, 'facility_admin', 'active', owner_user_id);
end $$;