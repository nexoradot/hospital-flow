# Phase 3 verification report

## Applied migrations
- `202610220006_phase3_queue_engine`
- `202610220007_phase3_fk_indexes`
- `202610220008_phase3_queue_rpc_api`

## Delivered
- `queue_tickets` stores facility-local tickets, patient/service/appointment references, queue date, token number/code, priority, status and timestamps.
- `private.queue_counters` allocates the next number per facility, service and facility-local date using a single atomic upsert.
- `private.create_queue_ticket` validates authenticated identity, facility role, active facility/service, active facility-local patient, walk-in configuration and checked-in appointment association when an appointment is supplied.
- `private.advance_queue_ticket` row-locks the ticket and allows only valid state transitions: waiting → called → serving → completed; cancellation and no-show paths are constrained.
- Queue priority allows routine and urgent only. Emergency cases are explicitly excluded from the routine queue priority system.
- Public-schema RPC wrappers expose queue actions through the Supabase Data API while the privileged implementation remains in the private schema.
- Direct client INSERT/UPDATE on queue tickets is revoked; clients must use the RPCs.
- Queue ticket create/update events are written to audit_events with operation metadata only.

## Hosted checks completed
- Confirmed queue_tickets exists and RLS is enabled.
- Security advisor returned no security lint findings after Phase 3.
- Confirmed anon cannot execute either public queue RPC; authenticated can execute them.
- Confirmed anon cannot SELECT queue_tickets and authenticated cannot directly INSERT or UPDATE queue_tickets.
- Confirmed all Phase 3 migrations are recorded in hosted migration history.
- Added indexes for queue-ticket foreign keys flagged by the performance advisor.

## Not yet verified / outstanding
- No authenticated end-to-end test has yet created a synthetic facility/user/patient and exercised concurrent ticket allocation.
- Full pgTAP tests and UI/API integration tests remain outstanding.
- Display-board access, public ticket lookup, printing, SMS/email notifications and patient self-service are not implemented.
- Appointment slot capacity/overbooking enforcement is not implemented.
- The performance advisor may report indexes as unused because the database has no representative workload.
- This remains a development backend, not production-ready; do not load real patient data.
