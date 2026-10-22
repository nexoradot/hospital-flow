# Hospital Flow

Multi-facility patient-flow and ticketing platform designed to complement existing Hospital Management Systems (HMS).

## Current status

The development database and first browser application have been committed. Patient-bearing SELECT policies are limited to explicit operational/clinical roles by the Phase 4 security-hardening migration. The browser app includes email/password authentication, facility selection, overview metrics, patient registration/search, manager-only department/service management, schedule activation/deactivation, appointment/walk-in creation, a staff-assisted department/service patient check-in flow, printable queue receipts, operational reports with a privacy-conscious queue CSV export, check-in/cancellation and queue ticket call/start/complete/cancel/no-show controls. Scheduled appointments require a schedule, and a database trigger validates slot alignment and uses transaction advisory locks to enforce per-slot capacity.

- Supabase project ref: `mcjmjvulkilfpglktqqx` (region `ap-south-1`)
- PostgreSQL 17
- Phase 1: facilities, facility memberships, departments, services, audit events
- Phase 2: patients, service schedules, appointments
- Phase 3: queue tickets and private atomic daily counters
- Phase 4: least-privilege read policies for patient, appointment and queue-ticket data
- Phase 5: service schedules and database-enforced appointment slot capacity
- Phase 6: facility-scoped department/service administration and manager-only RLS policies
- Phase 7: verified-phone patient self-service walk-in ticket portal (SMS provider configuration and end-to-end testing still required)
- Phase 8: facility-scoped team access dashboard, role assignment for existing accounts, membership suspend/reactivate/revoke controls, and audit events
- Phase 9: administrator/manager-only audit activity feed and serialized membership status changes to protect the last active facility administrator
- Patient records now support controlled edits with a duplicate-MRN block and a possible-duplicate warning based on name, date of birth, and/or phone
- Phase 10: privileged membership and audit implementations moved into the private schema behind SECURITY INVOKER public RPC wrappers
- Phase 11: explicit deny policies for private patient-portal profile and rate-limit tables
- Phase 12: serialize role changes and prevent demoting the last active facility administrator
- CI now checks the Phase 8–11 migration files and new team/audit functionality; JavaScript syntax has been checked for both browser scripts
- Remaining production gate: enable leaked-password protection in Supabase Auth, configure/test SMS delivery and deployed auth URLs, then complete browser end-to-end, concurrency, backup/restore, privacy and clinical-governance testing
- Operational navigation and create/edit controls are filtered by facility role; database policies and RPC checks remain the enforcement boundary

- Phase 4 UI shell: `index.html`, `styles.css`, `app.js`, `config.js`
- `config.js` contains a browser-safe publishable key. No service-role key is used in the browser.
- RLS and composite facility-scoped foreign keys are enabled. Queue writes must go through authenticated RPCs.
- GitHub Pages deployment workflow: `.github/workflows/deploy-pages.yml`. The repository owner may need to enable **Settings → Pages → Build and deployment → Source: GitHub Actions** before the first deployment.
- Initial facility setup guide: `docs/FIRST-FACILITY-BOOTSTRAP.sql`. Run only in Supabase SQL Editor using an authorized owner account after the first admin signs up.
- The latest application code passes GitHub Actions JavaScript syntax and required-file checks. A GitHub Pages build is running; verify the deploy job and public URL before treating the site as live.
- This is still a development preview. Browser flows have not yet been end-to-end tested.

## Known limitations

- Automated concurrent booking tests and browser end-to-end tests have not yet been run.
- Duplicate patient detection/review, public online booking and independent patient self-service, public queue boards, SMS/email notifications, referrals, clinical notes and HMS integration adapters are not implemented. Reports currently cover today's tickets and appointments only. The staff-assisted check-in remains available, and a verified-phone public patient portal now supports walk-in ticket creation and ticket-status checks. Ticket printing is available from both workflows.
- Service schedules can be activated/deactivated, but editing a schedule and schedule-based slot availability selection are not yet available.
- Facility membership administration and facility onboarding remain owner/bootstrap workflows.
- The app should not be used with real patient information until the remaining security, privacy, clinical governance, recovery and operational tests are completed.

## Repository layout

- `supabase/migrations/` — database migrations
- `supabase/tests/` — starter database tests; full local suite has not been run
- `docs/` — security and verification notes
- `.env.example` — safe environment template for local development

## Security principles

- Facility-owned data is isolated by authenticated membership and row-level security.
- Never commit service-role keys, access tokens, credentials or patient data.
- Cross-facility patient identity matching must never grant cross-facility clinical-record access.
- Public booking must use a rate-limited server-side workflow, not anonymous access to patient tables.
- Emergency escalation must not be replaced by routine queue ticketing.

## Local setup

1. Install Node.js LTS and the Supabase CLI.
2. Serve the static app locally or use GitHub Pages after enabling the Pages source.
3. Use a disposable local Supabase project to run migrations and tests.
4. Review migrations and complete integration/security testing before a pilot.

## Roadmap

1. Tenant foundation — hosted security checks completed; full automated isolation tests remain.
2. Patient registration and appointments — schema and initial UI committed; end-to-end verification remains.
3. Queue engine — atomic daily numbering and guarded transitions implemented; concurrency and authenticated workflow tests remain.
4. Department/service management and staff-assisted patient check-in/ticket printing are implemented; schedule editing, duplicate review, verified public booking and capacity concurrency tests remain. The slot picker is client-side assistance only; the database trigger enforces actual capacity.
5. Referrals, notifications and secure patient queue status.
6. HMS integration, reporting, accessibility, load/restore testing and controlled pilot.
