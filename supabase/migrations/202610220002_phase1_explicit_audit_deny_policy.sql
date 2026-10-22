-- Explicit defense-in-depth: browser roles must never read audit events.
begin;
create policy audit_events_no_client_access
  on public.audit_events
  as restrictive
  for all
  to anon, authenticated
  using (false)
  with check (false);
commit;
