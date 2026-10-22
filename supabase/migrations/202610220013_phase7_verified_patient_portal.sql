-- Phase 7: verified-phone patient self-service directory and walk-in ticketing.
-- Public directory exposes only active facility/department/service catalogue data, never patient records.
create table if not exists private.patient_portal_profiles (
  user_id uuid not null references auth.users(id) on delete cascade,
  facility_id uuid not null references public.facilities(id) on delete cascade,
  patient_id uuid not null references public.patients(id) on delete cascade,
  created_at timestamptz not null default now(),
  primary key (user_id, facility_id),
  unique (facility_id, patient_id)
);
alter table private.patient_portal_profiles enable row level security;
revoke all on private.patient_portal_profiles from anon, authenticated;

create table if not exists private.patient_portal_daily_limits (
  user_id uuid not null references auth.users(id) on delete cascade,
  facility_id uuid not null references public.facilities(id) on delete cascade,
  queue_date date not null,
  request_count integer not null check (request_count between 1 and 3),
  primary key (user_id, facility_id, queue_date)
);
alter table private.patient_portal_daily_limits enable row level security;
revoke all on private.patient_portal_daily_limits from anon, authenticated;

create or replace function public.get_patient_portal_directory()
returns table (
  facility_id uuid,
  facility_code text,
  facility_name text,
  facility_timezone text,
  department_id uuid,
  department_code text,
  department_name text,
  service_id uuid,
  service_code text,
  service_name text,
  booking_enabled boolean,
  walk_in_enabled boolean
)
language sql
stable
security definer
set search_path = ''
as $function$
  select f.id, f.code, f.name, f.timezone,
         d.id, d.code, d.name,
         s.id, s.code, s.name, s.booking_enabled, s.walk_in_enabled
  from public.facilities f
  join public.departments d on d.facility_id = f.id and d.status = 'active'
  join public.services s on s.facility_id = f.id and s.department_id = d.id and s.status = 'active'
  where f.status = 'active' and s.walk_in_enabled
  order by f.name, d.name, s.name;
$function$;
revoke all on function public.get_patient_portal_directory() from public;
grant execute on function public.get_patient_portal_directory() to anon, authenticated;

create or replace function private.create_patient_portal_ticket(
  p_facility_code text,
  p_service_id uuid,
  p_first_name text,
  p_last_name text
)
returns table(ticket_code text, queue_date date, status text, service_name text, department_name text)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_phone text;
  v_facility_id uuid;
  v_timezone text;
  v_service_code text;
  v_service_name text;
  v_department_name text;
  v_patient_id uuid;
  v_mrn text;
  v_queue_date date;
  v_ticket_number integer;
  v_ticket_code text;
  v_request_count integer;
begin
  if v_user_id is null then
    raise exception 'Sign in with a verified mobile number to request a ticket' using errcode = '28000';
  end if;

  select u.phone into v_phone
  from auth.users u
  where u.id = v_user_id and u.phone_confirmed_at is not null;
  if v_phone is null then
    raise exception 'Verify your mobile number before requesting a ticket' using errcode = '42501';
  end if;

  if length(trim(coalesce(p_first_name,''))) < 1 or length(trim(p_first_name)) > 100
     or length(trim(coalesce(p_last_name,''))) < 1 or length(trim(p_last_name)) > 100 then
    raise exception 'Enter a valid first and last name' using errcode = '22023';
  end if;

  select f.id, f.timezone into v_facility_id, v_timezone
  from public.facilities f
  where f.code = upper(trim(p_facility_code)) and f.status = 'active';
  if not found then
    raise exception 'Facility not found or not accepting tickets' using errcode = '22023';
  end if;

  select s.code, s.name, d.name into v_service_code, v_service_name, v_department_name
  from public.services s
  join public.departments d on d.id = s.department_id and d.facility_id = s.facility_id
  where s.id = p_service_id and s.facility_id = v_facility_id
    and s.status = 'active' and d.status = 'active' and s.walk_in_enabled;
  if not found then
    raise exception 'Choose an active walk-in service from this facility' using errcode = '22023';
  end if;

  v_queue_date := timezone(v_timezone, now())::date;
  insert into private.patient_portal_daily_limits as lim (user_id, facility_id, queue_date, request_count)
  values (v_user_id, v_facility_id, v_queue_date, 1)
  on conflict (user_id, facility_id, queue_date)
  do update set request_count = lim.request_count + 1
  where lim.request_count < 3
  returning request_count into v_request_count;
  if not found then
    raise exception 'Daily self-service ticket limit reached. Please ask reception for assistance.' using errcode = '54000';
  end if;

  select p.patient_id into v_patient_id
  from private.patient_portal_profiles p
  where p.user_id = v_user_id and p.facility_id = v_facility_id
  for update;

  if not found then
    v_mrn := 'PORTAL-' || upper(substr(replace(gen_random_uuid()::text, '-', ''), 1, 12));
    insert into public.patients (facility_id, medical_record_number, first_name, last_name, phone, created_by)
    values (v_facility_id, v_mrn, trim(p_first_name), trim(p_last_name), v_phone, v_user_id)
    returning id into v_patient_id;

    insert into private.patient_portal_profiles (user_id, facility_id, patient_id)
    values (v_user_id, v_facility_id, v_patient_id);
  end if;

  insert into private.queue_counters as qc (facility_id, service_id, queue_date, last_number)
  values (v_facility_id, p_service_id, v_queue_date, 1)
  on conflict (facility_id, service_id, queue_date)
  do update set last_number = qc.last_number + 1
  returning last_number into v_ticket_number;

  v_ticket_code := upper(v_service_code) || '-' || lpad(v_ticket_number::text, 3, '0');
  insert into public.queue_tickets
    (facility_id, patient_id, service_id, appointment_id, queue_date, ticket_number, ticket_code, priority, status, created_by)
  values
    (v_facility_id, v_patient_id, p_service_id, null, v_queue_date, v_ticket_number, v_ticket_code, 'routine', 'waiting', v_user_id);

  return query select v_ticket_code, v_queue_date, 'waiting'::text, v_service_name, v_department_name;
end;
$function$;

create or replace function public.create_patient_portal_ticket(
  p_facility_code text,
  p_service_id uuid,
  p_first_name text,
  p_last_name text
)
returns table(ticket_code text, queue_date date, status text, service_name text, department_name text)
language sql
security definer
set search_path = ''
as $function$
  select * from private.create_patient_portal_ticket(p_facility_code, p_service_id, p_first_name, p_last_name);
$function$;
revoke all on function public.create_patient_portal_ticket(text, uuid, text, text) from public, anon;
grant execute on function public.create_patient_portal_ticket(text, uuid, text, text) to authenticated;

create or replace function private.get_patient_portal_ticket_status(
  p_facility_code text,
  p_ticket_code text
)
returns table(ticket_code text, queue_date date, status text, service_name text, department_name text, called_at timestamptz)
language plpgsql
security definer
set search_path = ''
as $function$
declare
  v_user_id uuid := (select auth.uid());
  v_facility_id uuid;
begin
  if v_user_id is null or not exists (
    select 1 from auth.users u where u.id = v_user_id and u.phone_confirmed_at is not null
  ) then
    raise exception 'A verified mobile session is required' using errcode = '42501';
  end if;
  select f.id into v_facility_id from public.facilities f
  where f.code = upper(trim(p_facility_code)) and f.status = 'active';
  if not found then
    raise exception 'Facility not found' using errcode = '22023';
  end if;
  return query
    select t.ticket_code, t.queue_date, t.status, s.name, d.name, t.called_at
    from public.queue_tickets t
    join private.patient_portal_profiles pp on pp.user_id = v_user_id and pp.facility_id = t.facility_id and pp.patient_id = t.patient_id
    join public.services s on s.id = t.service_id and s.facility_id = t.facility_id
    join public.departments d on d.id = s.department_id and d.facility_id = s.facility_id
    where t.facility_id = v_facility_id and t.ticket_code = upper(trim(p_ticket_code))
    order by t.created_at desc
    limit 1;
  if not found then
    raise exception 'Ticket not found for this verified account' using errcode = 'P0002';
  end if;
end;
$function$;

create or replace function public.get_patient_portal_ticket_status(
  p_facility_code text,
  p_ticket_code text
)
returns table(ticket_code text, queue_date date, status text, service_name text, department_name text, called_at timestamptz)
language sql
security definer
set search_path = ''
as $function$
  select * from private.get_patient_portal_ticket_status(p_facility_code, p_ticket_code);
$function$;
revoke all on function public.get_patient_portal_ticket_status(text, text) from public, anon;
grant execute on function public.get_patient_portal_ticket_status(text, text) to authenticated;
