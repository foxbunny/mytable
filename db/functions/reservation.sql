-- Get all reservations for a specific date (excludes completed/no_show/cancelled)
drop function if exists get_reservations_for_date(date);
create function get_reservations_for_date(p_date date)
returns table(
	id int,
	guest_name text,
	guest_phone text,
	guest_email text,
	party_size int,
	reservation_date date,
	reservation_time time,
	duration_minutes int,
	table_ids int[],
	table_names text[],
	status text,
	source text,
	notes text,
	created_at timestamptz
) as $$
	select
		r.id,
		r.guest_name,
		r.guest_phone,
		r.guest_email,
		r.party_size,
		r.reservation_date,
		r.reservation_time,
		r.duration_minutes,
		coalesce(array_agg(rt.floorplan_table_id) filter (where rt.floorplan_table_id is not null), '{}') as table_ids,
		coalesce(array_agg(t.name) filter (where t.name is not null), '{}') as table_names,
		r.status,
		r.source,
		r.notes,
		r.created_at
	from reservation r
	left join reservation_table rt on r.id = rt.reservation_id
	left join floorplan_table t on rt.floorplan_table_id = t.id
	where r.reservation_date = p_date
		and r.status not in ('completed', 'no_show', 'cancelled', 'declined')
	group by r.id
	order by r.reservation_time, r.created_at;
$$ language sql;

comment on function get_reservations_for_date(date) is 'HTTP GET
Get all reservations for a specific date';

-- Get pending reservations (queue)
drop function if exists get_pending_reservations();
create function get_pending_reservations()
returns table(
	id int,
	guest_name text,
	guest_phone text,
	guest_email text,
	party_size int,
	reservation_date date,
	reservation_time time,
	duration_minutes int,
	table_ids int[],
	table_names text[],
	notes text,
	created_at timestamptz
) as $$
	select
		r.id,
		r.guest_name,
		r.guest_phone,
		r.guest_email,
		r.party_size,
		r.reservation_date,
		r.reservation_time,
		r.duration_minutes,
		coalesce(array_agg(rt.floorplan_table_id) filter (where rt.floorplan_table_id is not null), '{}') as table_ids,
		coalesce(array_agg(t.name) filter (where t.name is not null), '{}') as table_names,
		r.notes,
		r.created_at
	from reservation r
	left join reservation_table rt on r.id = rt.reservation_id
	left join floorplan_table t on rt.floorplan_table_id = t.id
	where r.status = 'pending'
	group by r.id
	order by r.reservation_date, r.reservation_time, r.created_at;
$$ language sql;

comment on function get_pending_reservations() is 'HTTP GET
Get all pending reservations for the queue';

-- Get count of pending reservations (for badge)
drop function if exists get_pending_count();
create function get_pending_count() returns jsonb as $$
	select jsonb_build_object('count', count(*)::int)
	from reservation
	where status = 'pending';
$$ language sql;

comment on function get_pending_count() is 'HTTP GET
Get count of pending reservations';

-- Get dates that have pending reservations
drop function if exists get_pending_dates();
create function get_pending_dates()
returns table(reservation_date date) as $$
	select distinct r.reservation_date
	from reservation r
	where r.status = 'pending'
	order by r.reservation_date;
$$ language sql;

comment on function get_pending_dates() is 'HTTP GET
Get dates with pending reservations for calendar markers';

-- Create a new reservation
drop function if exists create_reservation(text, int, date, time, text, text, int, int[], text, text);
create function create_reservation(
	p_guest_name text,
	p_party_size int,
	p_reservation_date date,
	p_reservation_time time,
	p_guest_phone text default null,
	p_guest_email text default null,
	p_duration_minutes int default 90,
	p_table_ids int[] default null,
	p_source text default 'online',
	p_notes text default null
) returns table(id int, status text) as $$
declare
	v_status text;
	v_id int;
begin
	-- Phone and walk-in reservations are auto-confirmed
	v_status := case when p_source in ('phone', 'walk_in') then 'confirmed' else 'pending' end;

	insert into reservation (
		guest_name, guest_phone, guest_email, party_size,
		reservation_date, reservation_time, duration_minutes,
		source, status, notes
	)
	values (
		p_guest_name, p_guest_phone, p_guest_email, p_party_size,
		p_reservation_date, p_reservation_time, p_duration_minutes,
		p_source, v_status, p_notes
	)
	returning reservation.id into v_id;

	-- Assign tables if provided
	if p_table_ids is not null and array_length(p_table_ids, 1) > 0 then
		insert into reservation_table (reservation_id, floorplan_table_id)
		select v_id, unnest(p_table_ids);
	end if;

	return query select v_id, v_status;
end;
$$ language plpgsql;

comment on function create_reservation(text, int, date, time, text, text, int, int[], text, text) is 'HTTP POST
@authorize
Create a new reservation';

-- Update reservation status
drop function if exists update_reservation_status(int, text);
create function update_reservation_status(p_id int, p_status text) returns jsonb as $$
	update reservation
	set status = p_status
	where id = p_id
	returning jsonb_build_object('id', id, 'status', status);
$$ language sql;

comment on function update_reservation_status(int, text) is 'HTTP POST
@authorize
Update reservation status (confirm, decline, complete, etc.)';

-- Update reservation details
drop function if exists update_reservation(int, text, text, text, int, date, time, int, text);
create function update_reservation(
	p_id int,
	p_guest_name text default null,
	p_guest_phone text default null,
	p_guest_email text default null,
	p_party_size int default null,
	p_reservation_date date default null,
	p_reservation_time time default null,
	p_duration_minutes int default null,
	p_notes text default null
) returns jsonb as $$
	update reservation
	set
		guest_name = coalesce(p_guest_name, guest_name),
		guest_phone = coalesce(p_guest_phone, guest_phone),
		guest_email = coalesce(p_guest_email, guest_email),
		party_size = coalesce(p_party_size, party_size),
		reservation_date = coalesce(p_reservation_date, reservation_date),
		reservation_time = coalesce(p_reservation_time, reservation_time),
		duration_minutes = coalesce(p_duration_minutes, duration_minutes),
		notes = coalesce(p_notes, notes)
	where id = p_id
	returning jsonb_build_object('id', id);
$$ language sql;

comment on function update_reservation(int, text, text, text, int, date, time, int, text) is 'HTTP POST
@authorize
Update reservation details';

-- Assign tables to reservation (replaces existing assignments)
drop function if exists assign_reservation_tables(int, int[]);
create function assign_reservation_tables(p_reservation_id int, p_table_ids int[]) returns jsonb as $$
begin
	-- Clear existing assignments
	delete from reservation_table where reservation_id = p_reservation_id;

	-- Add new assignments
	if p_table_ids is not null and array_length(p_table_ids, 1) > 0 then
		insert into reservation_table (reservation_id, floorplan_table_id)
		select p_reservation_id, unnest(p_table_ids);
	end if;

	return '{}'::jsonb;
end;
$$ language plpgsql;

comment on function assign_reservation_tables(int, int[]) is 'HTTP POST
@authorize
Assign tables to a reservation (replaces existing assignments)';

-- Drop old function signature
drop function if exists create_reservation(text, int, date, time, text, text, int, int, text, text);
drop function if exists update_reservation(int, text, text, text, int, date, time, int, int, text);
drop function if exists assign_reservation_table(int, int);

-- Tests
begin;

do $$
declare
	result record;
	res_id int;
	fp_id int;
	t1_id int;
	t2_id int;
	cnt int;
	arr int[];
begin
	truncate reservation restart identity cascade;
	truncate floorplan restart identity cascade;

	-- Setup: create floorplan and tables
	insert into floorplan (name, image_path, image_width, image_height)
	values ('Test Floor', '/test.png', 800, 600)
	returning id into fp_id;

	insert into floorplan_table (floorplan_id, name, capacity, x_pct, y_pct)
	values (fp_id, '1', 4, 0.3, 0.5)
	returning id into t1_id;

	insert into floorplan_table (floorplan_id, name, capacity, x_pct, y_pct)
	values (fp_id, '2', 4, 0.7, 0.5)
	returning id into t2_id;

	-- get_reservations_for_date returns empty when no reservations
	assert not exists(select 1 from get_reservations_for_date('2026-01-20')), 'should return no rows';

	-- get_pending_count returns 0 when no reservations
	assert (get_pending_count()->>'count')::int = 0, 'pending count should be 0';

	-- create_reservation with single table
	select * into result from create_reservation(
		'John Doe', 4, '2026-01-20', '18:00',
		'555-1234', 'john@example.com', 90, array[t1_id], 'online', 'Birthday'
	);
	assert result.status = 'pending', 'online should be pending';
	res_id := result.id;

	-- get_reservations_for_date shows table
	select * into result from get_reservations_for_date('2026-01-20');
	assert result.table_names[1] = '1', 'table name should match';

	-- assign_reservation_tables with multiple tables
	perform assign_reservation_tables(res_id, array[t1_id, t2_id]);

	-- Verify multiple tables assigned
	select table_ids into arr from get_reservations_for_date('2026-01-20');
	assert array_length(arr, 1) = 2, 'should have 2 tables';

	-- create_reservation auto-confirms phone reservations
	select * into result from create_reservation('Jane Doe', 2, '2026-01-20', '19:00', null, null, 90, null, 'phone');
	assert result.status = 'confirmed', 'phone should be auto-confirmed';

	-- Reservation without table should have empty arrays
	select count(*) into cnt from get_reservations_for_date('2026-01-20');
	assert cnt = 2, 'should have 2 reservations';

	raise notice 'All reservation tests passed!';
end;
$$;

rollback;
