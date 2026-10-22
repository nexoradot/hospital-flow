-- Phase 12: serialize role assignments and prevent demoting the final active facility administrator.
create or replace function private.assign_facility_member(p_facility_id uuid,p_email text,p_role text)
returns uuid
language plpgsql
security definer
set search_path=''
as $$
declare
 actor uuid:=auth.uid();
 actor_is_admin boolean;
 target_user uuid;
 existing_role text;
 membership_id uuid;
 normalized_email text:=lower(trim(coalesce(p_email,'')));
 active_admins bigint;
begin
 if actor is null then raise exception 'Authentication required'; end if;
 actor_is_admin:=private.has_facility_role(p_facility_id,array['facility_admin']::text[]);
 if not actor_is_admin and not private.has_facility_role(p_facility_id,array['facility_manager']::text[]) then
  raise exception 'Facility administrator or manager access required';
 end if;
 if normalized_email='' then raise exception 'Email address is required'; end if;
 if p_role not in ('facility_admin','facility_manager','receptionist','triage_nurse','clinician','queue_manager','diagnostics_staff','pharmacy_staff','billing_staff','integration_service') then
  raise exception 'Invalid facility role';
 end if;
 if p_role in ('facility_admin','facility_manager') and not actor_is_admin then
  raise exception 'Only a facility administrator can assign administrator or manager roles';
 end if;

 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_facility_id::text,0));
 select u.id into target_user from auth.users u where lower(u.email)=normalized_email limit 1;
 if target_user is null then raise exception 'No registered account matches this email. Ask the person to create an account first.'; end if;

 select fm.id,fm.role into membership_id,existing_role
 from public.facility_memberships fm
 where fm.facility_id=p_facility_id and fm.user_id=target_user
 for update;
 if existing_role in ('facility_admin','facility_manager') and not actor_is_admin then
  raise exception 'Only a facility administrator can change an administrator or manager membership';
 end if;
 if existing_role='facility_admin' and p_role<>'facility_admin' then
  select count(*) into active_admins from public.facility_memberships fm
  where fm.facility_id=p_facility_id and fm.role='facility_admin' and fm.status='active';
  if active_admins<=1 then raise exception 'The last active facility administrator cannot be demoted'; end if;
 end if;

 if membership_id is null then
  insert into public.facility_memberships(facility_id,user_id,role,status,created_by)
  values(p_facility_id,target_user,p_role,'active',actor)
  returning id into membership_id;
 else
  update public.facility_memberships set role=p_role,status='active'
  where id=membership_id and facility_id=p_facility_id;
 end if;

 insert into public.audit_events(facility_id,actor_user_id,action,resource_type,resource_id,outcome,metadata)
 values(p_facility_id,actor,'facility_membership.assigned','facility_membership',membership_id::text,'success',
        jsonb_build_object('role',p_role,'target_user_id',target_user));
 return membership_id;
end;
$$;
revoke all on function private.assign_facility_member(uuid,text,text) from public,anon;
grant execute on function private.assign_facility_member(uuid,text,text) to authenticated;
