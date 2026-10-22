-- Correct schedule trigger behavior: state-only transitions must not fail just because a schedule was later deactivated.
create or replace function private.enforce_appointment_schedule_capacity()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_timezone text;
  v_day_of_week integer;
  v_opens time;
  v_closes time;
  v_slot_minutes integer;
  v_capacity integer;
  v_schedule_status text;
  v_effective_from date;
  v_effective_until date;
  v_schedule_service_id uuid;
  v_local_start timestamp;
  v_local_end timestamp;
  v_duration_minutes integer;
  v_offset integer;
  v_slot_start timestamptz;
  v_existing_count integer;
  v_lock_key bigint;
begin
  if tg_op = 'UPDATE'
     and new.facility_id = old.facility_id
     and new.service_id = old.service_id
     and new.schedule_id is not distinct from old.schedule_id
     and new.appointment_type = old.appointment_type
     and new.scheduled_start = old.scheduled_start
     and new.scheduled_end = old.scheduled_end
     and new.status in ('checked_in','completed','cancelled','no_show') then
    return new;
  end if;

  if new.appointment_type <> 'scheduled' then
    return new;
  end if;
  if new.schedule_id is null then
    raise exception 'Scheduled appointments must select a service schedule' using errcode = '23514';
  end if;

  select f.timezone, ss.day_of_week, ss.opens_at, ss.closes_at, ss.slot_minutes,
         ss.capacity_per_slot, ss.status, ss.effective_from, ss.effective_until, ss.service_id
    into v_timezone, v_day_of_week, v_opens, v_closes, v_slot_minutes,
         v_capacity, v_schedule_status, v_effective_from, v_effective_until, v_schedule_service_id
  from public.service_schedules ss
  join public.facilities f on f.id = ss.facility_id
  where ss.id = new.schedule_id and ss.facility_id = new.facility_id;

  if not found then
    raise exception 'Service schedule not found in this facility' using errcode = '23503';
  end if;
  if v_schedule_status <> 'active' or v_schedule_service_id <> new.service_id then
    raise exception 'Choose an active schedule for the selected service' using errcode = '23514';
  end if;

  v_local_start := new.scheduled_start at time zone v_timezone;
  v_local_end := new.scheduled_end at time zone v_timezone;
  if v_local_start::date < v_effective_from
     or (v_effective_until is not null and v_local_start::date > v_effective_until) then
    raise exception 'Appointment date is outside the schedule effective dates' using errcode = '23514';
  end if;
  if extract(dow from v_local_start)::integer <> v_day_of_week
     or v_local_start::date <> v_local_end::date
     or v_local_start::time < v_opens
     or v_local_end::time > v_closes then
    raise exception 'Appointment time is outside this schedule day or opening hours' using errcode = '23514';
  end if;

  v_duration_minutes := (extract(epoch from (new.scheduled_end - new.scheduled_start)) / 60)::integer;
  if v_duration_minutes <= 0
     or mod(v_duration_minutes, v_slot_minutes) <> 0
     or extract(second from v_local_start) <> 0
     or mod((extract(epoch from (v_local_start::time - v_opens)) / 60)::integer, v_slot_minutes) <> 0 then
    raise exception 'Appointment must align to the schedule slot length' using errcode = '23514';
  end if;

  for v_offset in 0..((v_duration_minutes / v_slot_minutes) - 1) loop
    v_slot_start := new.scheduled_start + make_interval(mins => v_offset * v_slot_minutes);
    v_lock_key := pg_catalog.hashtextextended(
      new.facility_id::text || ':' || new.schedule_id::text || ':' || v_slot_start::text, 0
    );
    perform pg_catalog.pg_advisory_xact_lock(v_lock_key);
    if new.status in ('booked','confirmed','checked_in') then
      select count(*)::integer into v_existing_count
      from public.appointments a
      where a.facility_id = new.facility_id
        and a.schedule_id = new.schedule_id
        and a.status in ('booked','confirmed','checked_in')
        and a.id is distinct from new.id
        and a.scheduled_start < v_slot_start + make_interval(mins => v_slot_minutes)
        and a.scheduled_end > v_slot_start;
      if v_existing_count >= v_capacity then
        raise exception 'This appointment slot is full; choose another available time' using errcode = '23514';
      end if;
    end if;
  end loop;
  return new;
end;
$$;

revoke all on function private.enforce_appointment_schedule_capacity() from public, anon, authenticated;