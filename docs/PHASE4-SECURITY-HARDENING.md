# Phase 4 security hardening

## Change applied
Migration `202610220009_phase4_patient_data_role_hardening` replaces broad member-read policies for patients, appointments and queue tickets with an explicit operational-role allowlist:
- facility_admin
- facility_manager
- receptionist
- triage_nurse
- clinician
- queue_manager

This excludes other facility memberships from direct access to these patient-bearing tables unless a future purpose-specific policy is added. The schedule and service configuration read policies remain facility-member scoped.

## Verification
- Hosted migration applied successfully.
- Queried `pg_policies` and confirmed the three explicit operational-role SELECT policies exist.
- Supabase security advisor returned no security lint findings.

## Remaining work
- Integration tests should prove an excluded role cannot read patient-bearing tables and an allowed role can only see rows from its own facility.
- This is not a complete clinical data-access model. Diagnostics, pharmacy, billing and integration workflows need purpose-specific, minimum-necessary access before implementation.
- Browser end-to-end tests, capacity enforcement, deployment and production readiness checks remain outstanding.
