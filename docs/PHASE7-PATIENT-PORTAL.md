# Phase 7 — Verified-phone patient self-service

## Delivered
- A public patient portal page lets a patient browse active facilities, departments and walk-in-enabled services before signing in.
- Patients request an SMS one-time code using an international-format mobile number. Ticket creation requires an authenticated session with a confirmed phone number.
- The database creates a facility-scoped portal patient profile on first use and issues the next queue ticket through the atomic daily counter.
- A user can check status only for tickets linked to that user's verified account. The public directory exposes catalogue information only, not patient records.
- A database-side limit allows at most three self-service tickets per verified user, facility and local queue date.
- Public RPC wrappers use SECURITY INVOKER. Only the internal helper functions are SECURITY DEFINER and those helpers are not in an exposed API schema. Anonymous access is limited to the safe catalogue query.
- Internal portal profile and rate-limit tables have no direct client privileges.

## Migrations
- 202610220013_phase7_verified_patient_portal.sql
- 202610220014_phase7_private_portal_grants_hardening.sql
- 202610220015_phase7_public_catalog_invoker_hardening.sql

## Required configuration before use
1. Configure and test an SMS provider in Supabase Auth phone authentication. The UI cannot send OTPs until the project's SMS provider is configured and funded/available.
2. Confirm the public GitHub Pages deployment is live and the Supabase Auth allowed URLs include the deployed patient portal URL.
3. Add facility departments and walk-in-enabled services before expecting them to appear in the public directory.

## Known limitations and safety
- The portal creates a new portal-linked patient record on first use. It does not automatically link to an existing hospital record because phone numbers may be shared and identity matching needs a controlled workflow. Patients who already have an MRN are directed to reception to avoid duplicates.
- This is a walk-in ticket flow, not an appointment booking flow. Online appointment booking needs a separate verified booking workflow.
- No live SMS delivery, browser end-to-end test, abuse/load test, or independent penetration test has been performed in this environment.
- The security advisor still reports leaked-password protection disabled for email/password authentication. Enable it before a real-patient pilot. It also reports informational notices for private tables with RLS and no policies; those tables are in the private schema, have no direct client grants, and are accessed by controlled functions.
- Do not use with real patient information until SMS delivery, authorization, clinical governance, privacy, backups, monitoring and recovery have been tested.
