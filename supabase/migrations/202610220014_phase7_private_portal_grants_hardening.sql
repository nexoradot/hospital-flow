-- Keep internal patient portal helpers inaccessible as direct RPCs.
revoke all on function private.create_patient_portal_ticket(text, uuid, text, text) from public, anon, authenticated;
revoke all on function private.get_patient_portal_ticket_status(text, text) from public, anon, authenticated;
revoke all on table private.patient_portal_profiles from public, anon, authenticated;
revoke all on table private.patient_portal_daily_limits from public, anon, authenticated;
