-- Phase 10: keep privileged implementation functions outside the exposed public API schema.
alter function public.list_facility_members(uuid) set schema private;
alter function public.assign_facility_member(uuid,text,text) set schema private;
alter function public.set_facility_member_status(uuid,uuid,text) set schema private;
alter function public.list_facility_audit_events(uuid,integer) set schema private;

revoke all on function private.list_facility_members(uuid) from public,anon;
revoke all on function private.assign_facility_member(uuid,text,text) from public,anon;
revoke all on function private.set_facility_member_status(uuid,uuid,text) from public,anon;
revoke all on function private.list_facility_audit_events(uuid,integer) from public,anon;
grant usage on schema private to authenticated;
grant execute on function private.list_facility_members(uuid) to authenticated;
grant execute on function private.assign_facility_member(uuid,text,text) to authenticated;
grant execute on function private.set_facility_member_status(uuid,uuid,text) to authenticated;
grant execute on function private.list_facility_audit_events(uuid,integer) to authenticated;

create or replace function public.list_facility_members(p_facility_id uuid)
returns table (membership_id uuid,user_id uuid,email text,full_name text,role text,status text,created_at timestamptz)
language sql stable security invoker set search_path=''
as $$ select * from private.list_facility_members(p_facility_id); $$;

create or replace function public.assign_facility_member(p_facility_id uuid,p_email text,p_role text)
returns uuid language sql security invoker set search_path=''
as $$ select private.assign_facility_member(p_facility_id,p_email,p_role); $$;

create or replace function public.set_facility_member_status(p_facility_id uuid,p_membership_id uuid,p_status text)
returns boolean language sql security invoker set search_path=''
as $$ select private.set_facility_member_status(p_facility_id,p_membership_id,p_status); $$;

create or replace function public.list_facility_audit_events(p_facility_id uuid,p_limit integer default 100)
returns table (event_id uuid,occurred_at timestamptz,actor_user_id uuid,actor_email text,action text,resource_type text,resource_id text,outcome text)
language sql stable security invoker set search_path=''
as $$ select * from private.list_facility_audit_events(p_facility_id,p_limit); $$;

revoke all on function public.list_facility_members(uuid) from public,anon;
revoke all on function public.assign_facility_member(uuid,text,text) from public,anon;
revoke all on function public.set_facility_member_status(uuid,uuid,text) from public,anon;
revoke all on function public.list_facility_audit_events(uuid,integer) from public,anon;
grant execute on function public.list_facility_members(uuid) to authenticated;
grant execute on function public.assign_facility_member(uuid,text,text) to authenticated;
grant execute on function public.set_facility_member_status(uuid,uuid,text) to authenticated;
grant execute on function public.list_facility_audit_events(uuid,integer) to authenticated;
