-- Covers the created_by FK's ON DELETE SET NULL path.
create index if not exists facility_memberships_created_by_idx
  on public.facility_memberships(created_by);
