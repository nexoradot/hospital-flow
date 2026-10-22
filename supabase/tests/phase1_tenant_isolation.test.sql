begin;
select plan(5);

select has_table('public', 'facilities', 'facilities table exists');
select has_table('public', 'facility_memberships', 'facility memberships table exists');
select has_table('public', 'departments', 'departments table exists');
select has_table('public', 'services', 'services table exists');
select has_table('public', 'audit_events', 'audit events table exists');

select * from finish();
rollback;
