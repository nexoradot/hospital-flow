-- Hospital Flow Phase 3: secure queue tickets and atomic daily numbering.
begin;

create table public.queue_tickets (
  id uuid primary key default gen_random_uuid(),
  facility_id uuid not null,
  patient_id uuid not null,
  service_id uuid not null,
  appointment_id uuid,
  queue_date date not null,
  ticket_number integer not null check (ticket_number > 0),
  ticket_code text not null check (length(trim(ticket_code)) between 2 and 64),
  priority text not null default 'routine' check (priority in ('routine','urgent')),
  status text not null default 'waiting' check (status in ('waiting','called','serving','completed','cancelled','no_show')),
  created_by uuid not null references auth.users(id) on delete restrict,
  called_by uuid references auth.users(id) on delete restrict,
  called_at timestamptz,
  started_at timestamptz,
  completed_at timestamptz,
  cancelled_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (facility_id, id),
  unique (facility_id, service_id, queue_date, ticket_number),
  unique (facility_id, service_id, queue_date, ticket_code),
  constraint queue_tickets_patient_same_facility_fk
    foreign key (facility_id, patient_id)
    references public.patients(facility_id, id) on delete restrict,
  constraint queue_tickets_service_same_facility_fk
    foreign key (facility_id, service_id)
    references public.services(facility_id, id) on delete restrict,
  constraint queue_tickets_appointment_same_facility_fk
    foreign key (facility_id, appointment_id)
    references public.appointments(facility_id, id) on delete restrict
);

create index queue_tickets_facility_service_status_idx
  on public.queue_tickets(facility_id, service_id, queue_date, status, ticket_number);
create index queue_tickets_facility_patient_idx
  on public.queue_tickets(facility_id, patient_id, created_at desc);
create index queue_tickets_created_by_idx on public.queue_tickets(created_by);

create table private.queue_counters (
  facility_id uuid not null references public.facilities(id) on delete restrict,
  service_id uuid not null,
  queue_date date not null,
  last_number integer not null check (last_number > 0),
  primary key (facility_id, service_id, queue_date),
  constraint queue_counters_service_same_facility_fk
    foreign key (facility_id, service_id)
    references public.services(facility_id, id) on delete restrict
);
revoke all on table private.queue_counters from public, anon, authenticated;

create trigger queue_tickets_set_updated_at
before update on public.queue_tickets
for each row execute function private.set_updated_at();

create trigger queue_tickets_audit_change
after insert or update on public.queue_tickets
for each row execute function private.audit_patient_flow_change();

alter table public.queue_tickets enable row level security;
revoke all on public.queue_tickets from anon, authenticated;
grant select on public.queue_tickets to authenticated;

create policy queue_tickets_select_facility_member on public.queue_tickets
for select to authenticated
using ((select private.has_facility_role(facility_id, null)));

create or replace function private.create_queue_ticket(
  p_facility_id uuid,
  p_patient_id uuid,
  p_service_id uuid,
  p_appointment_id uuid default null,
  p_priority text default 'routine'
)
returns table(ticket_id uuid, ticket_number integer, ticket_code text, queue_date date, status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_timezone text;
  v_service_code text;
  v_queue_date date;
  v_ticket_number integer;
  v_ticket_code text;
  v_ticket public.queue_tickets%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  if p_priority not in ('routine','urgent') then
    raise exception 'Priority must be routine or urgent; emergencies require immediate clinical escalation' using errcode = '22023';
  end if;

  if not (select private.has_facility_role(p_facility_id,
    array['facility_admin','facility_manager','receptionist','triage_nurse','queue_manager','clinician']::text[])) then
    raise exception 'Not authorized for this facility queue' using errcode = '42501';
  end if;

  select f.timezone, s.code
    into v_timezone, v_service_code
  from public.facilities f
  join public.services s on s.facility_id = f.id
  where f.id = p_facility_id
    and s.id = p_service_id
    and f.status = 'active'
    and s.status = 'active'
    and (p_appointment_id is not null or s.walk_in_enabled);

  if not found then
    raise exception 'Active facility/service not found or walk-ins are disabled' using errcode = '22023';
  end if;

  if not exists (
    select 1 from public.patients p
    where p.id = p_patient_id and p.facility_id = p_facility_id and p.status = 'active'
  ) then
    raise exception 'Active patient not found in this facility' using errcode = '22023';
  end if;

  if p_appointment_id is not null and not exists (
    select 1 from public.appointments a
    where a.id = p_appointment_id
      and a.facility_id = p_facility_id
      and a.patient_id = p_patient_id
      and a.service_id = p_service_id
      and a.status = 'checked_in'
  ) then
    raise exception 'Appointment must belong to this patient and service and be checked in' using errcode = '22023';
  end if;

  v_queue_date := timezone(v_timezone, now())::date;

  insert into private.queue_counters as qc (facility_id, service_id, queue_date, last_number)
  values (p_facility_id, p_service_id, v_queue_date, 1)
  on conflict (facility_id, service_id, queue_date)
  do update set last_number = qc.last_number + 1
  returning last_number into v_ticket_number;

  v_ticket_code := upper(v_service_code) || '-' || lpad(v_ticket_number::text, 3, '0');

  insert into public.queue_tickets
    (facility_id, patient_id, service_id, appointment_id, queue_date, ticket_number,
     ticket_code, priority, status, created_by)
  values
    (p_facility_id, p_patient_id, p_service_id, p_appointment_id, v_queue_date,
     v_ticket_number, v_ticket_code, p_priority, 'waiting', v_user_id)
  returning * into v_ticket;

  return query select v_ticket.id, v_ticket.ticket_number, v_ticket.ticket_code,
                      v_ticket.queue_date, v_ticket.status;
end;
$$;

create or replace function private.advance_queue_ticket(
  p_ticket_id uuid,
  p_action text
)
returns table(ticket_id uuid, ticket_number integer, ticket_code text, queue_date date, status text)
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_ticket public.queue_tickets%rowtype;
begin
  if v_user_id is null then
    raise exception 'Authentication required' using errcode = '28000';
  end if;

  select * into v_ticket
  from public.queue_tickets
  where id = p_ticket_id
  for update;

  if not found then
    raise exception 'Queue ticket not found' using errcode = 'P0002';
  end if;

  if not (select private.has_facility_role(v_ticket.facility_id,
    array['facility_admin','facility_manager','receptionist','triage_nurse','queue_manager','clinician']::text[])) then
    raise exception 'Not authorized for this facility queue' using errcode = '42501';
  end if;

  case p_action
    when 'call' then
      if v_ticket.status <> 'waiting' then
        raise exception 'Only waiting tickets can be called' using errcode = '22023';
      end if;
      update public.queue_tickets
        set status = 'called', called_at = now(), called_by = v_user_id
        where id = p_ticket_id returning * into v_ticket;
    when 'start' then
      if v_ticket.status <> 'called' then
        raise exception 'Only called tickets can start service' using errcode = '22023';
      end if;
      update public.queue_tickets
        set status = 'serving', started_at = now()
        where id = p_ticket_id returning * into v_ticket;
    when 'complete' then
      if v_ticket.status <> 'serving' then
        raise exception 'Only tickets in service can be completed' using errcode = '22023';
      end if;
      update public.queue_tickets
        set status = 'completed', completed_at = now()
        where id = p_ticket_id returning * into v_ticket;
    when 'cancel' then
      if v_ticket.status not in ('waiting','called') then
        raise exception 'Only waiting or called tickets can be cancelled' using errcode = '22023';
      end if;
      update public.queue_tickets
        set status = 'cancelled', cancelled_at = now(), completed_at = now()
        where id = p_ticket_id returning * into v_ticket;
    when 'no_show' then
      if v_ticket.status <> 'called' then
        raise exception 'Only called tickets can be marked no-show' using errcode = '22023';
      end if;
      update public.queue_tickets
        set status = 'no_show', completed_at = now()
        where id = p_ticket_id returning * into v_ticket;
    else
      raise exception 'Unsupported queue action' using errcode = '22023';
  end case;

  return query select v_ticket.id, v_ticket.ticket_number, v_ticket.ticket_code,
                      v_ticket.queue_date, v_ticket.status;
end;
$$;

revoke all on function private.create_queue_ticket(uuid, uuid, uuid, uuid, text) from public, anon, authenticated;
revoke all on function private.advance_queue_ticket(uuid, text) from public, anon, authenticated;
grant execute on function private.create_queue_ticket(uuid, uuid, uuid, uuid, text) to authenticated;
grant execute on function private.advance_queue_ticket(uuid, text) to authenticated;

commit;