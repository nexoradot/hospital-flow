# Phase 1 verification report

## Environment
- Supabase project: Hospital Flow
- Project ref: `mcjmjvulkilfpglktqqx`
- Region: `ap-south-1`
- PostgreSQL: 17
- Test data: synthetic only; no patient information

## Checks completed against hosted project
- Applied migrations `202610220001_phase1_tenant_foundation`, `202610220002_phase1_explicit_audit_deny_policy`, and `202610220003_phase1_membership_creator_index`.
- Confirmed RLS enabled on all five Phase 1 public tables.
- Used two synthetic authenticated users in separate facilities. Each could see only their own facility, department, service and membership.
- Cross-facility service-to-department reference was rejected by the composite foreign key.
- Anonymous role did not have SELECT on facilities.
- Authenticated client did not have SELECT on audit_events or INSERT on facilities.
- Removed synthetic users and facility fixtures; all five Phase 1 tables were empty after cleanup.
- Supabase security advisor returned no security lint findings after adding the explicit audit deny policy.

## Not yet completed
- Full local pgTAP suite has not been run.
- No browser UI, sign-in, invitation or end-to-end workflow has been tested.
- No patient registration, appointment, queue, referral, notification or HMS integration workflows exist yet.
- No load, backup/restore, disaster recovery, accessibility or clinical safety validation has been completed.
- This is not production-ready.

## Advisor note
A performance advisor flagged the membership creator foreign key; an index was added. On a fresh empty database the advisor may report the index as unused. Reassess with representative workload before production tuning.
