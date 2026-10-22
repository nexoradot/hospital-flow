# Hospital Flow

Multi-facility patient-flow and ticketing platform. Hospital Flow is designed to complement existing Hospital Management Systems (HMS), not replace every clinical or administrative function.

## Current status

Phases 1 and 2 have established the tenant-isolated database foundation and the initial patient-registration, service-schedule and appointment schema in the dedicated Supabase project. This remains an early development foundation, not a production-ready hospital application.

- Supabase project ref: `mcjmjvulkilfpglktqqx`
- Supabase region: `ap-south-1` (Mumbai)
- PostgreSQL: 17
- Phase 1 tables: facilities, facility memberships, departments, services, audit events
- Phase 2 tables: patients, service schedules, appointments
- RLS is enabled on all eight operational/configuration tables plus audit_events.
- Patient, schedule and appointment tables have facility-scoped RLS and same-facility foreign keys.
- Patient and appointment create/update changes write minimal audit events without storing patient details in audit metadata.
- Anonymous SELECT is not granted on patient, schedule or appointment tables; audit_events remains unavailable to browser clients.
- Queue tickets, atomic slot-capacity enforcement, public online booking, encounter/clinical notes, referrals and notifications are not implemented yet.
- No real patient data is included.

## Repository layout

- `supabase/migrations/` — database schema migrations applied to the dedicated development project
- `supabase/tests/` — starter pgTAP tenant-isolation tests; full local suite has not been run
- `docs/` — security review and verification notes
- `.env.example` — safe configuration template; never put real secrets here

## Security principles

- Facility-owned data must be isolated by facility and authenticated membership.
- Never commit Supabase service-role keys, access tokens, credentials, or patient data.
- Browser clients must use only a publishable/anon key and rely on RLS; privileged operations belong in trusted server-side code.
- Cross-facility patient identity matching must not grant cross-facility clinical-record access.
- Public online booking must be implemented through a rate-limited, abuse-resistant server-side workflow; do not expose patient tables to anonymous clients.
- Appointment slot capacity must be enforced atomically before real booking traffic is enabled.
- Emergency escalation must not be replaced by routine queue ticketing.

## Local setup

1. Install Node.js LTS and the Supabase CLI.
2. Copy `.env.example` to `.env.local` and add development values locally. Do not commit `.env.local`.
3. Start a disposable local Supabase environment and run migrations/tests with the CLI.
4. Review each migration before applying it to a hosted environment.

Typical local database checks:

```sh
supabase start
supabase db reset
supabase test db
```

## Roadmap

1. Tenant foundation and security review — hosted checks completed; full automated isolation tests remain.
2. Patient registration, service schedules, appointments and walk-in data model — schema applied; UI and end-to-end workflows remain.
3. Secure duplicate review, appointment availability/capacity enforcement, booking, cancellation and check-in workflows.
4. Atomic queue ticket allocation, queue state transitions, call-forward and display board.
5. Referrals, notifications and secure patient queue-status access.
6. HMS integration adapters, operational dashboards, accessibility, load testing, backup/recovery drills and pilot governance.

Do not use real patient data in development fixtures. Complete privacy, security, clinical governance, operational resilience and regulatory reviews before live hospital deployment.
