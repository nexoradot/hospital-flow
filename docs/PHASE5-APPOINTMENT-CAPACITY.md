# Phase 5: appointment schedule capacity

## Delivered
- Facility admins/managers can create service schedules in the browser app.
- Schedules define service, weekday, opening/closing times, slot duration, capacity and effective dates.
- Scheduled appointments require a schedule.
- A database trigger validates service/facility match, active schedule, date, weekday, opening hours and slot alignment.
- PostgreSQL transaction advisory locks serialize concurrent booking attempts for the same slot before capacity is checked.
- Cancellation, no-show, completion and check-in status transitions are not blocked just because a schedule later becomes inactive.

## Applied migrations
- `202610220010_phase5_schedule_capacity`
- `202610220011_phase5_state_transition_fix`

## Hosted checks
- Both migrations applied successfully.
- Confirmed the appointment capacity trigger exists.
- Confirmed the scheduled-appointment schedule constraint exists.
- Supabase security advisor returned no security lint findings.

## Remaining validation
- Automated concurrent booking tests and browser end-to-end tests have not been run.
- Schedule creation is implemented; editing/deactivation is not yet available in the UI.
- Walk-ins use the queue process and are not counted against scheduled slot capacity.
- This remains a development preview, not a production hospital system.