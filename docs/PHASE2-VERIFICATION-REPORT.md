# Phase 2 verification report

## Environment
- Supabase project: Hospital Flow
- Project ref: `mcjmjvulkilfpglktqqx`
- Region: `ap-south-1`
- PostgreSQL: 17
- No patient or facility test fixtures were created.

## Applied migrations
- `202610220004_phase2_patient_appointments`
- `202610220005_phase2_fk_indexes`

## Schema delivered
- `patients`: facility-local medical record number, basic demographic/contact fields and status.
- `service_schedules`: weekly service opening times, slot length/capacity and effective dates.
- `appointments`: scheduled visit or walk-in, service, timing, status, check-in/cancellation fields.
- Composite foreign keys prevent an appointment from referencing a patient, service or schedule in another facility.
- Medical record numbers are unique within a facility, not globally.
- Patient and appointment insert/update events write minimal audit entries; audit metadata intentionally excludes patient details.
- Facility ID is excluded from browser-client UPDATE column grants to prevent moving existing records between facilities.

## Hosted checks completed
- Confirmed all three Phase 2 tables exist and have RLS enabled.
- Confirmed anonymous role has no SELECT privilege on patients, service_schedules or appointments.
- Confirmed authenticated role has SELECT privilege on those tables, with row visibility still controlled by RLS membership policies.
- Confirmed audit_events remains unavailable to authenticated SELECT and anonymous SELECT.
- Security advisor returned no security lint findings after the Phase 2 migration.
- Added indexes for the four foreign-key performance findings from the initial performance advisor.
- Migration history shows both Phase 2 migrations applied successfully.

## Not yet verified / not implemented
- Full local pgTAP tenant-isolation suite has not been run.
- No browser login or end-to-end create/update workflow has been tested.
- No authenticated synthetic insert was performed in this check, so trigger auditing and actual RLS behavior still need automated integration tests.
- Duplicate patient suggestions beyond facility-local MRN uniqueness are not implemented.
- Service schedule capacity is descriptive only; there is no atomic slot reservation/overbooking protection yet.
- Public/online booking is intentionally not enabled.
- Queue tickets, referrals, notifications, HMS integrations, load tests, backup/restore and clinical safety validation remain outstanding.
- This is not production-ready and must not be used with real patient information until the remaining controls and reviews are completed.
