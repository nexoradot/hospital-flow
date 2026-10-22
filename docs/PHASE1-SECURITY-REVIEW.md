# Phase 1 security review

## Scope
Initial multi-facility foundation only: facilities, memberships, departments, services and audit events. This review does not establish production readiness.

## Controls included
- Row-level security enabled on all five public tables.
- Authenticated users receive read-only grants for initial configuration tables.
- No anonymous grants to configuration data.
- No browser-client grants or policies for audit events; a restrictive deny policy is also applied.
- Facility membership helper is in a non-exposed schema, uses SECURITY DEFINER with an empty pinned search path, and is executable only by authenticated users.
- Service-to-department relationship uses a composite foreign key including facility_id, preventing a service from referencing a department belonging to another facility.
- Membership role and status values are constrained.
- No client-side membership provisioning is allowed in this phase.

## Known gaps / follow-up
- Run the pgTAP test suite in a local Supabase environment; it has not yet been run.
- Expand automated tests to every operation on every tenant-owned table as the schema grows.
- Review platform-level roles, staff lifecycle, invitation flow, recovery, rate limiting and privileged server functions.
- Add patient/appointment/queue tables only with facility_id, RLS, appropriate constraints and tested policies.
- Complete privacy impact, threat model, audit retention, backup/restore, monitoring and incident response reviews before live use.

## Operational safety
Never place real patient information, credentials, access tokens or service-role keys in this repository. The repository is currently public, so all committed content must be safe for public disclosure.
