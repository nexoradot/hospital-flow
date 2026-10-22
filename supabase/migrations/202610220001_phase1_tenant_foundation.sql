-- Hospital Flow — Phase 1 tenant foundation
-- No patient data is seeded. Apply only to the dedicated Hospital Flow project.

begin;

create extension if not exists pgcrypto with schema extensions;
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table if not exists public.facilities (
  id uuid primary key default gen_random_uuid(),
  code text not null unique check (code ~ '^[A-Z0-9][A-Z0-9_-]{1,31}$'),
  name text not null check (length(trim(name)) between 2 and 160),
  timezone text not null default 'Africa/Nairobi',
  status text not null default 'active' check (status in ('active','suspended','closed')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.facility_memberships (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.facilities(id) on delete restrict,
  user_id uuid not null references auth.users(id) on delete restrict,
  role text not null check (role in (
    'facility_admin','receptionist','triage_nurse','clinician',
    'queue_manager','diagnostics_staff','pharmacy_staff','billing_staff',
    'facility_manager','integration_service'
  )),
  status text not null default 'active' check (status in ('active','suspended','revoked')),
  created_at timestamptz not null default now(),
  created_by uuid references auth.users(id) on delete set null,
  unique (facility_id, user_id, role),
  unique (facility_id, id)
);

create table if not exists public.departments (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.facilities(id) on delete restrict,
  code text not null check (length(trim(code)) between 2 and 40),
  name text not null check (length(trim(name)) between 2 and 120),
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  unique (facility_id, code),
  unique (facility_id, id)
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null references public.facilities(id) on delete restrict,
  department_id uuid not null,
  code text not null check (length(trim(code)) between 2 and 40),
  name text not null check (length(trim(name)) between 2 and 160),
  booking_enabled boolean not null default true,
  walk_in_enabled boolean not null default true,
  status text not null default 'active' check (status in ('active','inactive')),
  created_at timestamptz not null default now(),
  unique (facility_id, code),
  unique (facility_id, id),
  constraint services_department_same_facility_fk
    foreign key (facility_id, department_id)
    references public.departments(facility_id, id) on delete restrict
);

create table if not exists public.audit_events (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid references public.facilities(id) on delete restrict,
  actor_user_id uuid references auth.users(id) on delete set null,
  action text not null check (length(trim(action)) between 2 and 120),
  resource_type text not null check (length(trim(resource_type)) between 2 and 80),
  resource_id text,
  outcome text not null default 'success' check (outcome in ('success','denied','failure')),
  correlation_id uuid,
  occurred_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb
);

create index if not exists facility_memberships_user_status_idx
  on public.facility_memberships(user_id, status, facility_id);
create index if not exists facility_memberships_facility_role_idx
  on public.facility_memberships(facility_id, role, status);
create index if not exists departments_facility_status_idx
  on public.departments(facility_id, status);
create index if not exists services_facility_department_status_idx
  on public.services(facility_id, department_id, status);
create index if not exists audit_events_facility_occurred_idx
  on public.audit_events(facility_id, occurred_at desc);
create index if not exists audit_events_actor_occurred_idx
  on public.audit_events(actor_user_id, occurred_at desc);

-- Read memberships as owner to avoid recursive RLS policy evaluation.
create or replace function private.has_facility_role(
  p_facility_id uuid,
  p_allowed_roles text[] default null
)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.facility_memberships fm
    where fm.facility_id = p_facility_id
      and fm.user_id = (select auth.uid())
      and fm.status = 'active'
      and (p_allowed_roles is null or fm.role = any(p_allowed_roles))
  );
$$;
revoke all on function private.has_facility_role(uuid, text[]) from public, anon;
grant execute on function private.has_facility_role(uuid, text[]) to authenticated;

alter table public.facilities enable row level security;
alter table public.facility_memberships enable row level security;
alter table public.departments enable row level security;
alter table public.services enable row level security;
alter table public.audit_events enable row level security;

-- Initial configuration tables are read-only to browser clients.
revoke all on table public.facilities from anon, authenticated;
revoke all on table public.facility_memberships from anon, authenticated;
revoke all on table public.departments from anon, authenticated;
revoke all on table public.services from anon, authenticated;
revoke all on table public.audit_events from anon, authenticated;
grant select on table public.facilities, public.facility_memberships,
  public.departments, public.services to authenticated;

create policy facilities_select_member
  on public.facilities for select to authenticated
  using ((select private.has_facility_role(id, null)));

create policy memberships_select_self_or_facility_admin
  on public.facility_memberships for select to authenticated
  using (
    user_id = (select auth.uid())
    or (select private.has_facility_role(facility_id, array['facility_admin','facility_manager']::text[]))
  );

create policy departments_select_facility_member
  on public.departments for select to authenticated
  using ((select private.has_facility_role(facility_id, null)));

create policy services_select_facility_member
  on public.services for select to authenticated
  using ((select private.has_facility_role(facility_id, null)));

-- No client policy or grant is defined for audit_events.

commit;
