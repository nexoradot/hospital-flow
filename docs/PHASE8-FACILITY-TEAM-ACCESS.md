# Phase 8 — Facility team and access management

- Facility administrators and managers can list current facility memberships and assign an existing registered account by email.
- Members must sign up first; this browser app does not expose service-role credentials or attempt to send administrative invitations.
- Facility managers may assign operational roles but cannot grant or modify administrator/manager roles.
- Only facility administrators can assign manager/admin roles or change their memberships.
- Membership suspension/revocation is facility-scoped, self-lockout is blocked, and the last active facility administrator cannot be suspended or revoked.
- Assignment and status changes are written to the restricted audit log.
- Access is enforced in database functions; hiding a menu is not the security boundary.

Before production, verify this workflow with test accounts for every role and complete the remaining end-to-end, SMS, recovery, privacy, and clinical-governance checks.