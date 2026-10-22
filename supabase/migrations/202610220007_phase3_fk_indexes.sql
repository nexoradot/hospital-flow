-- Cover queue-ticket foreign keys for appointment lookups and user references.
begin;
create index queue_tickets_facility_appointment_idx on public.queue_tickets(facility_id, appointment_id);
create index queue_tickets_called_by_idx on public.queue_tickets(called_by);
commit;