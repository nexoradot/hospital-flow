-- Hospital Flow queue ticket RPC fix, deployed to Supabase.
-- Keep this migration in source control so a new environment gets the same fix.
create or replace function private.create_queue_ticket(
  p_facility_id uuid,
  p_patient_id uuid,
  p_service_id uuid,
  p_appointment_id uuid default null,
  p_priority text default 'routine'
)
returns table(ticket_id uuid, ticket_number integer, ticket_code text, queue_date date, status text)
language plpgsql security definer set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_timezone text;
  v_service_code text;
  v_local_queue_date date;
  v_ticket_number integer;
  v_ticket_code text;
  v_ticket public.queue_tickets%rowtype;
begin
  if v_user_id is null then raise exception 'Authentication required' using errcode = '28000'; end if;
  if p_priority not in ('routine','urgent') then raise exception 'Priority must be routine or urgent; emergencies require immediate clinical escalation' using errcode = '22023'; end if;
  if not (select private.has_facility_role(p_facility_id,array['facility_admin','facility_manager','receptionist','triage_nurse','queue_manager','clinician']::text[])) then
    raise exception 'Not authorized for this facility queue' using errcode = '42501';
  end if;
  select f.timezone,s.code into v_timezone,v_service_code
  from public.facilities as f join public.services as s on s.facility_id=f.id
  where f.id=p_facility_id and s.id=p_service_id and f.status='active' and s.status='active'
    and (p_appointment_id is not null or s.walk_in_enabled);
  if not found then raise exception 'Active facility/service not found or walk-ins are disabled' using errcode = '22023'; end if;
  if not exists(select 1 from public.patients as p where p.id=p_patient_id and p.facility_id=p_facility_id and p.status='active') then
    raise exception 'Active patient not found in this facility' using errcode = '22023';
  end if;
  if p_appointment_id is not null and not exists(select 1 from public.appointments as a
    where a.id=p_appointment_id and a.facility_id=p_facility_id and a.patient_id=p_patient_id
      and a.service_id=p_service_id and a.status='checked_in') then
    raise exception 'Appointment must belong to this patient and service and be checked in' using errcode = '22023';
  end if;
  v_local_queue_date:=timezone(v_timezone,now())::date;
  insert into private.queue_counters as qc(facility_id,service_id,queue_date,last_number)
  values(p_facility_id,p_service_id,v_local_queue_date,1)
  on conflict on constraint queue_counters_pkey do update set last_number=qc.last_number+1
  returning qc.last_number into v_ticket_number;
  v_ticket_code:=upper(v_service_code)||'-'||lpad(v_ticket_number::text,3,'0');
  insert into public.queue_tickets(facility_id,patient_id,service_id,appointment_id,queue_date,ticket_number,ticket_code,priority,status,created_by)
  values(p_facility_id,p_patient_id,p_service_id,p_appointment_id,v_local_queue_date,v_ticket_number,v_ticket_code,p_priority,'waiting',v_user_id)
  returning * into v_ticket;
  return query select v_ticket.id,v_ticket.ticket_number,v_ticket.ticket_code,v_ticket.queue_date,v_ticket.status;
end;
$$;
