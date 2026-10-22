# Hospital Flow

Multi-facility patient-flow and ticketing platform. Hospital Flow is designed to complement existing Hospital Management Systems (HMS), not replace every clinical or administrative function.

## Current status

Phases 1–3 establish a tenant-isolated database foundation for facility setup, patient registration, service schedules, appointments, walk-ins and the core queue engine. This remains an early development backend, not a production-ready hospital application.

- Supabase project ref: `mcjmjvulkilfpglktqqx`
- Supabase region: `ap-south-1`
- PostgreSQL: 17
- Phase 1 tables: facilities, facility memberships, departments, services, audit events
- Phase 2 tables: patients, service schedules, appointments
- Phase 3 table: queue tickets; private queue counters allocate daily ticket numbers atomically.
- RLS is enabled on all nine public tables.
- Composite foreign keys prevent patient, service, appointment, schedule and ticket links across facilities.
- Patient, appointment and queue-ticket changes write minimal audit events without putting patient details in audit metadata.
- Queue creation and transition RPCs are available only to authenticated callers and validate facility membership/role.
- Anonymous users cannot select or directly insert/update queue tickets; authenticated clients cannot directly insert/update tickets either.
- Public online booking, atomic appointment-slot capacity enforcement, encounter/clinical notes, referrals, patient notifications and the browser UI are not implemented yet.
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
- Emergency escalation must not be replaced by routine queue ticketing; queue priority deliberately excludes emergency cases.

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
2. Patient registration, service schedules, appointments and walk-in schema — applied; UI and end-to-end workflows remain.
3. Queue ticket engine — schema, atomic daily numbering and controlled transition RPCs applied; authenticated end-to-end tests and queue display UI remain.
4. Secure duplicate review, appointment availability/capacity enforcement, booking, cancellation and check-in workflows.
5. Referrals, notifications and secure patient queue-status access.
6. HMS integration adapters, operational dashboards, accessibility, load testing, backup/recovery drills and pilot governance.

Do not use real patient data in development fixtures. Complete privacy, security, clinical governance, operational resilience and regulatory reviews before live hospital deployment.
