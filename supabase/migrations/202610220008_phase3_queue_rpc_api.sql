-- Expose authenticated-only RPC wrappers through Supabase's public Data API schema.
-- The underlying privileged logic remains in the private schema and validates membership.
begin;

create or replace function public.create_queue_ticket(
  p_facility_id uuid,
  p_patient_id uuid,
  p_service_id uuid,
  p_appointment_id uuid default null,
  p_priority text default 'routine'
)
returns table(ticket_id uuid, ticket_number integer, ticket_code text, queue_date date, status text)
language sql
security invoker
set search_path = ''
as $$
  select * from private.create_queue_ticket(
    p_facility_id, p_patient_id, p_service_id, p_appointment_id, p_priority
  );
$$;

create or replace function public.advance_queue_ticket(
  p_ticket_id uuid,
  p_action text
)
returns table(ticket_id uuid, ticket_number integer, ticket_code text, queue_date date, status text)
language sql
security invoker
set search_path = ''
as $$
  select * from private.advance_queue_ticket(p_ticket_id, p_action);
$$;

revoke all on function public.create_queue_ticket(uuid, uuid, uuid, uuid, text) from public, anon;
revoke all on function public.advance_queue_ticket(uuid, text) from public, anon;
grant execute on function public.create_queue_ticket(uuid, uuid, uuid, uuid, text) to authenticated;
grant execute on function public.advance_queue_ticket(uuid, text) to authenticated;

commit;