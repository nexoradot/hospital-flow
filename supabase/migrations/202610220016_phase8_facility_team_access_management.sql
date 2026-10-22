-- Phase 8: facility-scoped team and access management.
create or replace function public.list_facility_members(p_facility_id uuid)
returns table (membership_id uuid,user_id uuid,email text,full_name text,role text,status text,created_at timestamptz)
language plpgsql stable security definer set search_path=''
as $$
begin
 if auth.uid() is null or not private.has_facility_role(p_facility_id,array['facility_admin','facility_manager']::text[]) then
  raise exception 'Facility administrator or manager access required';
 end if;
 return query select fm.id,u.id,u.email::text,coalesce(u.raw_user_meta_data->>'full_name','')::text,fm.role::text,fm.status::text,fm.created_at
 from public.facility_memberships fm join auth.users u on u.id=fm.user_id
 where fm.facility_id=p_facility_id
 order by case fm.status when 'active' then 0 when 'suspended' then 1 else 2 end,lower(coalesce(u.email,''));
end; $$;

create or replace function public.assign_facility_member(p_facility_id uuid,p_email text,p_role text)
returns uuid language plpgsql security definer set search_path=''
as $$
declare actor uuid:=auth.uid(); actor_is_admin boolean; target_user uuid; existing_role text; membership_id uuid; normalized_email text:=lower(trim(coalesce(p_email,'')));
begin
 if actor is null then raise exception 'Authentication required'; end if;
 actor_is_admin:=private.has_facility_role(p_facility_id,array['facility_admin']::text[]);
 if not actor_is_admin and not private.has_facility_role(p_facility_id,array['facility_manager']::text[]) then raise exception 'Facility administrator or manager access required'; end if;
 if normalized_email='' then raise exception 'Email address is required'; end if;
 if p_role not in ('facility_admin','facility_manager','receptionist','triage_nurse','clinician','queue_manager','diagnostics_staff','pharmacy_staff','billing_staff','integration_service') then raise exception 'Invalid facility role'; end if;
 if p_role in ('facility_admin','facility_manager') and not actor_is_admin then raise exception 'Only a facility administrator can assign administrator or manager roles'; end if;
 select u.id into target_user from auth.users u where lower(u.email)=normalized_email limit 1;
 if target_user is null then raise exception 'No registered account matches this email. Ask the person to create an account first.'; end if;
 select fm.id,fm.role into membership_id,existing_role from public.facility_memberships fm where fm.facility_id=p_facility_id and fm.user_id=target_user for update;
 if existing_role in ('facility_admin','facility_manager') and not actor_is_admin then raise exception 'Only a facility administrator can change an administrator or manager membership'; end if;
 if membership_id is null then
  insert into public.facility_memberships(facility_id,user_id,role,status,created_by) values(p_facility_id,target_user,p_role,'active',actor) returning id into membership_id;
 else
  update public.facility_memberships set role=p_role,status='active' where id=membership_id and facility_id=p_facility_id;
 end if;
 insert into public.audit_events(facility_id,actor_user_id,action,resource_type,resource_id,outcome,metadata)
 values(p_facility_id,actor,'facility_membership.assigned','facility_membership',membership_id::text,'success',jsonb_build_object('role',p_role,'target_user_id',target_user));
 return membership_id;
end; $$;

create or replace function public.set_facility_member_status(p_facility_id uuid,p_membership_id uuid,p_status text)
returns boolean language plpgsql security definer set search_path=''
as $$
declare actor uuid:=auth.uid(); actor_is_admin boolean; target_user uuid; target_role text; target_status text; active_admins bigint;
begin
 if actor is null then raise exception 'Authentication required'; end if;
 actor_is_admin:=private.has_facility_role(p_facility_id,array['facility_admin']::text[]);
 if not actor_is_admin and not private.has_facility_role(p_facility_id,array['facility_manager']::text[]) then raise exception 'Facility administrator or manager access required'; end if;
 if p_status not in ('active','suspended','revoked') then raise exception 'Invalid membership status'; end if;
 select fm.user_id,fm.role,fm.status into target_user,target_role,target_status from public.facility_memberships fm where fm.id=p_membership_id and fm.facility_id=p_facility_id for update;
 if target_user is null then raise exception 'Membership not found for this facility'; end if;
 if target_user=actor and p_status<>'active' then raise exception 'You cannot suspend or revoke your own membership'; end if;
 if target_role in ('facility_admin','facility_manager') and not actor_is_admin then raise exception 'Only a facility administrator can change an administrator or manager membership'; end if;
 if target_role='facility_admin' and p_status<>'active' then
  select count(*) into active_admins from public.facility_memberships fm where fm.facility_id=p_facility_id and fm.role='facility_admin' and fm.status='active';
  if active_admins<=1 then raise exception 'The last active facility administrator cannot be suspended or revoked'; end if;
 end if;
 update public.facility_memberships set status=p_status where id=p_membership_id and facility_id=p_facility_id;
 insert into public.audit_events(facility_id,actor_user_id,action,resource_type,resource_id,outcome,metadata)
 values(p_facility_id,actor,'facility_membership.status_changed','facility_membership',p_membership_id::text,'success',jsonb_build_object('old_status',target_status,'new_status',p_status,'target_user_id',target_user));
 return true;
end; $$;

revoke all on function public.list_facility_members(uuid) from public,anon;
revoke all on function public.assign_facility_member(uuid,text,text) from public,anon;
revoke all on function public.set_facility_member_status(uuid,uuid,text) from public,anon;
grant execute on function public.list_facility_members(uuid) to authenticated;
grant execute on function public.assign_facility_member(uuid,text,text) to authenticated;
grant execute on function public.set_facility_member_status(uuid,uuid,text) to authenticated;
