# Phase 6 — Department and service management

## Delivered
- Facility administrators and managers can create departments and services from the workspace.
- Service configuration includes a department, code, name, walk-in enablement and online-booking enablement.
- Departments and services can be activated/deactivated without deleting historical records.
- Database RLS policies restrict department/service insert and update to facility administrators and managers for their own facility.
- The composite facility/department foreign key continues to prevent a service being attached to another facility's department.
- The patient check-in screen filters to active departments and walk-in-enabled services, creates a ticket through the existing atomic queue RPC, and offers a printable receipt.
- Scheduled appointment booking includes a date/slot picker that filters by the selected schedule, effective dates, weekday, loaded bookings and capacity; the database remains the final authority and rechecks capacity at save time.
- Operational Reports summarize today's queue by service and status and export a CSV containing ticket/service/status fields without patient names.
- Ticket issuance still requires an authenticated, authorized facility user. The current check-in screen is staff-assisted; it is not an anonymous public patient portal.

## Migration
202610220012_phase6_department_service_management.sql

## Verification
- Migration was applied to the hosted Hospital Flow Supabase project.
- SQL verification confirmed the four manager-only policies exist.
- Supabase security advisor currently reports one warning: leaked-password protection is disabled in Auth. Enable it in the Supabase Auth security settings before a real-patient pilot.
- GitHub Actions validates JavaScript syntax and required app files. This does not substitute for browser end-to-end, concurrency, accessibility, or clinical workflow tests.

## Remaining before production
1. End-to-end test registration → department/service selection → ticket creation → print → call/start/complete.
2. Add public patient booking only after phone/email verification, anti-abuse/rate limiting, and a minimal-data design are deployed server-side.
3. Add schedule editing/deactivation, slot availability selection, and automated capacity/concurrency tests.
4. Add duplicate-patient review, role/member administration, audit/reporting dashboards, notifications, referrals, and HMS adapters.
5. Complete privacy impact assessment, clinical governance review, backups/restore drill, monitoring, incident response, and a controlled pilot.
