begin;
create table if not exists public.clinical_encounters (
 id uuid primary key default gen_random_uuid(), facility_id uuid not null references public.facilities(id) on delete restrict,
 patient_id uuid not null, appointment_id uuid, clinician_id uuid not null references auth.users(id),
 encounter_date timestamptz not null default now(), chief_complaint text not null, history_notes text,
 examination_notes text, assessment text, diagnosis text, plan text,
 disposition text not null default 'follow_up' check(disposition in ('follow_up','discharge','refer','admit')),
 status text not null default 'draft' check(status in ('draft','signed')), signed_at timestamptz,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 constraint clinical_encounters_patient_fk foreign key(facility_id,patient_id) references public.patients(facility_id,id),
 constraint clinical_encounters_appointment_fk foreign key(facility_id,appointment_id) references public.appointments(facility_id,id)
);
create table if not exists public.nursing_observations (
 id uuid primary key default gen_random_uuid(), facility_id uuid not null references public.facilities(id) on delete restrict,
 patient_id uuid not null, recorded_by uuid not null references auth.users(id), recorded_at timestamptz not null default now(),
 temperature_c numeric(4,1) check(temperature_c between 25 and 45), pulse_bpm integer check(pulse_bpm between 20 and 250),
 respiratory_rate integer check(respiratory_rate between 4 and 80), systolic_bp integer check(systolic_bp between 40 and 300),
 diastolic_bp integer check(diastolic_bp between 20 and 200), spo2_percent integer check(spo2_percent between 50 and 100),
 weight_kg numeric(6,2) check(weight_kg between 0 and 500), pain_score integer check(pain_score between 0 and 10),
 notes text, created_at timestamptz not null default now(),
 constraint nursing_observations_patient_fk foreign key(facility_id,patient_id) references public.patients(facility_id,id)
);
create table if not exists public.customer_care_cases (
 id uuid primary key default gen_random_uuid(), facility_id uuid not null references public.facilities(id) on delete restrict,
 patient_id uuid, created_by uuid not null references auth.users(id), assigned_to uuid references auth.users(id),
 subject text not null check(length(trim(subject)) between 3 and 180),
 category text not null default 'general' check(category in ('general','appointment','billing','complaint','feedback','records','other')),
 priority text not null default 'normal' check(priority in ('low','normal','high','urgent')),
 details text not null, status text not null default 'open' check(status in ('open','in_progress','resolved','closed')),
 resolution_notes text, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 constraint customer_care_patient_fk foreign key(facility_id,patient_id) references public.patients(facility_id,id)
);
create index if not exists clinical_encounters_facility_date_idx on public.clinical_encounters(facility_id,encounter_date desc);
create index if not exists nursing_observations_facility_patient_idx on public.nursing_observations(facility_id,patient_id,recorded_at desc);
create index if not exists customer_care_cases_facility_status_idx on public.customer_care_cases(facility_id,status,created_at desc);
alter table public.clinical_encounters enable row level security;
alter table public.nursing_observations enable row level security;
alter table public.customer_care_cases enable row level security;
drop policy if exists clinical_encounters_read on public.clinical_encounters;
create policy clinical_encounters_read on public.clinical_encounters for select to authenticated using (private.has_facility_role(facility_id,array['facility_admin','facility_manager','clinician']::text[]) or clinician_id=auth.uid());
drop policy if exists clinical_encounters_insert on public.clinical_encounters;
create policy clinical_encounters_insert on public.clinical_encounters for insert to authenticated with check (private.has_facility_role(facility_id,array['facility_admin','facility_manager','clinician']::text[]) and clinician_id=auth.uid());
drop policy if exists clinical_encounters_update on public.clinical_encounters;
create policy clinical_encounters_update on public.clinical_encounters for update to authenticated using (private.has_facility_role(facility_id,array['facility_admin','facility_manager','clinician']::text[]) and (clinician_id=auth.uid() or private.has_facility_role(facility_id,array['facility_admin','facility_manager']::text[]))) with check (private.has_facility_role(facility_id,array['facility_admin','facility_manager','clinician']::text[]));
drop policy if exists nursing_observations_read on public.nursing_observations;
create policy nursing_observations_read on public.nursing_observations for select to authenticated using (private.has_facility_role(facility_id,array['facility_admin','facility_manager','triage_nurse','clinician']::text[]));
drop policy if exists nursing_observations_insert on public.nursing_observations;
create policy nursing_observations_insert on public.nursing_observations for insert to authenticated with check (private.has_facility_role(facility_id,array['facility_admin','facility_manager','triage_nurse']::text[]) and recorded_by=auth.uid());
drop policy if exists customer_care_cases_read on public.customer_care_cases;
create policy customer_care_cases_read on public.customer_care_cases for select to authenticated using (private.has_facility_role(facility_id,array['facility_admin','facility_manager','receptionist']::text[]));
drop policy if exists customer_care_cases_insert on public.customer_care_cases;
create policy customer_care_cases_insert on public.customer_care_cases for insert to authenticated with check (private.has_facility_role(facility_id,array['facility_admin','facility_manager','receptionist']::text[]) and created_by=auth.uid());
drop policy if exists customer_care_cases_update on public.customer_care_cases;
create policy customer_care_cases_update on public.customer_care_cases for update to authenticated using (private.has_facility_role(facility_id,array['facility_admin','facility_manager','receptionist']::text[])) with check (private.has_facility_role(facility_id,array['facility_admin','facility_manager','receptionist']::text[]));
grant select,insert,update on public.clinical_encounters,public.nursing_observations,public.customer_care_cases to authenticated;
commit;
