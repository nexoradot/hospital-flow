-- Phase 9: restricted audit activity feed and membership concurrency hardening.
create or replace function public.list_facility_audit_events(p_facility_id uuid,p_limit integer default 100)
returns table (
  event_id uuid,
  occurred_at timestamptz,
  actor_user_id uuid,
  actor_email text,
  action text,
  resource_type text,
  resource_id text,
  outcome text
)
language plpgsql
stable
security definer
set search_path=''
as $$
begin
  if auth.uid() is null
     or not private.has_facility_role(p_facility_id,array['facility_admin','facility_manager']::text[]) then
    raise exception 'Facility administrator or manager access required';
  end if;
  return query
  select e.id,e.occurred_at,e.actor_user_id,u.email::text,e.action,e.resource_type,e.resource_id,e.outcome
  from public.audit_events e
  left join auth.users u on u.id=e.actor_user_id
  where e.facility_id=p_facility_id
  order by e.occurred_at desc
  limit greatest(1,least(coalesce(p_limit,100),200));
end;
$$;
revoke all on function public.list_facility_audit_events(uuid,integer) from public,anon;
grant execute on function public.list_facility_audit_events(uuid,integer) to authenticated;

-- Serialize membership changes within a facility so simultaneous requests cannot remove its final active administrator.
create or replace function public.set_facility_member_status(p_facility_id uuid,p_membership_id uuid,p_status text)
returns boolean language plpgsql security definer set search_path=''
as $$
declare actor uuid:=auth.uid(); actor_is_admin boolean; target_user uuid; target_role text; target_status text; active_admins bigint;
begin
 if actor is null then raise exception 'Authentication required'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(p_facility_id::text,0));
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
revoke all on function public.set_facility_member_status(uuid,uuid,text) from public,anon;
grant execute on function public.set_facility_member_status(uuid,uuid,text) to authenticated;
