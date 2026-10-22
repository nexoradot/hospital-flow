-- Hospital Flow Phase 2: facility-scoped patient registration, schedules, appointments and walk-ins.
-- Patient-facing online booking is intentionally not exposed to anon clients in this migration.
begin;

create table public.patients (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.facilities(id) on delete restrict,
  medical_record_number text not null check (length(trim(medical_record_number)) between 1 and 40),
  first_name text not null check (length(trim(first_name)) between 1 and 100),
  middle_name text check (middle_name is null or length(trim(middle_name)) <= 100),
  last_name text not null check (length(trim(last_name)) between 1 and 100),
  date_of_birth date,
  sex text check (sex is null or sex in ('female','male','intersex','unknown','not_recorded')),
  phone text check (phone is null or length(trim(phone)) <= 32),
  email text check (email is null or length(trim(email)) <= 254),
  status text not null default 'active' check (status in ('active','merged','inactive')),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (facility_id, medical_record_number),
  unique (facility_id, id)
);

create table public.service_schedules (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null,
  service_id uuid not null,
  day_of_week smallint not null check (day_of_week between 0 and 6),
  opens_at time not null,
  closes_at time not null,
  slot_minutes smallint not null default 15 check (slot_minutes between 5 and 240),
  capacity_per_slot smallint not null default 1 check (capacity_per_slot between 1 and 500),
  effective_from date not null default current_date,
  effective_until date,
  status text not null default 'active' check (status in ('active','inactive')),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (closes_at > opens_at),
  check (effective_until is null or effective_until >= effective_from),
  unique (facility_id, id),
  constraint service_schedules_service_same_facility_fk
    foreign key (facility_id, service_id)
    references public.services(facility_id, id) on delete restrict
);

create table public.appointments (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null,
  patient_id uuid not null,
  service_id uuid not null,
  schedule_id uuid,
  appointment_type text not null default 'scheduled' check (appointment_type in ('scheduled','walk_in')),
  source text not null default 'staff' check (source in ('staff','online','phone','integration')),
  scheduled_start timestamptz not null,
  scheduled_end timestamptz not null,
  status text not null default 'booked' check (status in ('booked','confirmed','checked_in','cancelled','no_show','completed')),
  reason text check (reason is null or length(trim(reason)) <= 500),
  checked_in_at timestamptz,
  cancelled_at timestamptz,
  cancellation_reason text check (cancellation_reason is null or length(trim(cancellation_reason)) <= 300),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (scheduled_end > scheduled_start),
  check ((status = 'cancelled') = (cancelled_at is not null)),
  unique (facility_id, id),
  constraint appointments_patient_same_facility_fk
    foreign key (facility_id, patient_id)
    references public.patients(facility_id, id) on delete restrict,
  constraint appointments_service_same_facility_fk
    foreign key (facility_id, service_id)
    references public.services(facility_id, id) on delete restrict,
  constraint appointments_schedule_same_facility_fk
    foreign key (facility_id, schedule_id)
    references public.service_schedules(facility_id, id) on delete restrict
);

create index patients_facility_name_idx
  on public.patients(facility_id, lower(last_name), lower(first_name));
create index patients_facility_phone_idx
  on public.patients(facility_id, phone) where phone is not null;
create index service_schedules_lookup_idx
  on public.service_schedules(facility_id, service_id, day_of_week, status, effective_from);
create index appointments_facility_start_idx
  on public.appointments(facility_id, scheduled_start, status);
create index appointments_facility_patient_idx
  on public.appointments(facility_id, patient_id, scheduled_start desc);
create index appointments_facility_service_idx
  on public.appointments(facility_id, service_id, scheduled_start, status);

create or replace function private.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function private.audit_patient_flow_change()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_facility_id uuid;
  v_resource_id uuid;
  v_action text;
begin
  if tg_op = 'DELETE' then
    v_facility_id := old.facility_id;
    v_resource_id := old.id;
    v_action := lower(tg_table_name) || '.delete';
  elsif tg_op = 'INSERT' then
    v_facility_id := new.facility_id;
    v_resource_id := new.id;
    v_action := lower(tg_table_name) || '.create';
  else
    v_facility_id := new.facility_id;
    v_resource_id := new.id;
    v_action := lower(tg_table_name) || '.update';
  end if;

  insert into public.audit_events
    (facility_id, actor_user_id, action, resource_type, resource_id, outcome, metadata)
  values
    (v_facility_id, (select auth.uid()), v_action, tg_table_name, v_resource_id::text,
     'success', jsonb_build_object('operation', tg_op));

  if tg_op = 'DELETE' then return old; end if;
  return new;
end;
$$;

revoke all on function private.set_updated_at() from public, anon, authenticated;
revoke all on function private.audit_patient_flow_change() from public, anon, authenticated;

create trigger patients_set_updated_at
before update on public.patients
for each row execute function private.set_updated_at();
create trigger schedules_set_updated_at
before update on public.service_schedules
for each row execute function private.set_updated_at();
create trigger appointments_set_updated_at
before update on public.appointments
for each row execute function private.set_updated_at();

create trigger patients_audit_change
after insert or update or delete on public.patients
for each row execute function private.audit_patient_flow_change();
create trigger appointments_audit_change
after insert or update or delete on public.appointments
for each row execute function private.audit_patient_flow_change();

alter table public.patients enable row level security;
alter table public.service_schedules enable row level security;
alter table public.appointments enable row level security;

revoke all on public.patients, public.service_schedules, public.appointments from anon, authenticated;
grant select on public.patients, public.service_schedules, public.appointments to authenticated;
grant insert (facility_id, medical_record_number, first_name, middle_name, last_name, date_of_birth, sex, phone, email, status, created_by)
  on public.patients to authenticated;
grant update (medical_record_number, first_name, middle_name, last_name, date_of_birth, sex, phone, email, status, updated_at)
  on public.patients to authenticated;
grant insert (facility_id, service_id, day_of_week, opens_at, closes_at, slot_minutes, capacity_per_slot, effective_from, effective_until, status, created_by)
  on public.service_schedules to authenticated;
grant update (service_id, day_of_week, opens_at, closes_at, slot_minutes, capacity_per_slot, effective_from, effective_until, status, updated_at)
  on public.service_schedules to authenticated;
grant insert (facility_id, patient_id, service_id, schedule_id, appointment_type, source, scheduled_start, scheduled_end, status, reason, checked_in_at, cancelled_at, cancellation_reason, created_by)
  on public.appointments to authenticated;
grant update (patient_id, service_id, schedule_id, appointment_type, source, scheduled_start, scheduled_end, status, reason, checked_in_at, cancelled_at, cancellation_reason, updated_at)
  on public.appointments to authenticated;

create policy patients_select_facility_member on public.patients
for select to authenticated
using ((select private.has_facility_role(facility_id, null)));

create policy patients_insert_registration_staff on public.patients
for insert to authenticated
with check ((select private.has_facility_role(facility_id,
  array['facility_admin','facility_manager','receptionist','triage_nurse']::text[]))
  and created_by = (select auth.uid()));

create policy patients_update_authorized_staff on public.patients
for update to authenticated
using ((select private.has_facility_role(facility_id,
  array['facility_admin','facility_manager','receptionist','triage_nurse','clinician']::text[])))
with check ((select private.has_facility_role(facility_id,
  array['facility_admin','facility_manager','receptionist','triage_nurse','clinician']::text[])));

create policy schedules_select_facility_member on public.service_schedules
for select to authenticated
using ((select private.has_facility_role(facility_id, null)));

create policy schedules_insert_admin on public.service_schedules
for insert to authenticated
with check ((select private.has_facility_role(facility_id,
  array['facility_admin','facility_manager']::text[]))
  and created_by = (select auth.uid()));

create policy schedules_update_admin on public.service_schedules
for update to authenticated
using ((select private.has_facility_role(facility_id,
  array['facility_admin','facility_manager']::text[])))
with check ((select private.has_facility_role(facility_id,
  array['facility_admin','facility_manager']::text[])));

create policy appointments_select_facility_member on public.appointments
for select to authenticated
using ((select private.has_facility_role(facility_id, null)));

create policy appointments_insert_front_desk on public.appointments
for insert to authenticated
with check ((select private.has_facility_role(facility_id,
  array['facility_admin','facility_manager','receptionist','triage_nurse']::text[]))
  and created_by = (select auth.uid()));

create policy appointments_update_operational_staff on public.appointments
for update to authenticated
using ((select private.has_facility_role(facility_id,
  array['facility_admin','facility_manager','receptionist','triage_nurse','queue_manager','clinician']::text[])))
with check ((select private.has_facility_role(facility_id,
  array['facility_admin','facility_manager','receptionist','triage_nurse','queue_manager','clinician']::text[])));

commit;