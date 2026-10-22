# Hospital Flow

Multi-facility patient-flow and ticketing platform. Hospital Flow is designed to complement existing Hospital Management Systems (HMS), not replace every clinical or administrative function.

## Current status

Phase 1 establishes the initial tenant-isolated database foundation in the dedicated Supabase project. This is an early development foundation, not a production-ready hospital application.

- Supabase project ref: `mcjmjvulkilfpglktqqx`
- Supabase region: `ap-south-1` (Mumbai)
- PostgreSQL: 17
- Initial tables: facilities, facility memberships, departments, services, audit events
- Row-level security enabled on all five public tables
- Patient, appointment, encounter, queue-ticket, and referral tables are not implemented yet
- No real patient data is included

## Repository layout

- `supabase/migrations/` — database schema migrations applied to the dedicated development project
- `supabase/tests/` — starter pgTAP tenant-isolation tests; not yet run locally
- `docs/` — security review and verification notes
- `.env.example` — safe configuration template; never put real secrets here

## Security principles

- Facility-owned data must be isolated by facility and authenticated membership.
- Never commit Supabase service-role keys, access tokens, credentials, or patient data.
- Browser clients must use only a publishable/anon key and rely on RLS; privileged operations belong in trusted server-side code.
- Cross-facility patient identity matching must not grant cross-facility clinical-record access.
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

1. Tenant foundation and security review — initial foundation applied; further automated tests remain.
2. Patient registration, duplicate checks, service schedules, appointments, walk-in registration and check-in.
3. Atomic queue ticket allocation, queue state transitions, call-forward and display board.
4. Referrals, notifications and secure patient queue-status access.
5. HMS integration adapters and integration event tracking.
6. Operational dashboards, accessibility, load testing, backup/recovery drills and pilot governance.

Do not use real patient data in development fixtures. Complete privacy, security, clinical governance, operational resilience and regulatory reviews before live hospital deployment.
