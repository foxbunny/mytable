-- Get all reservations for a specific date (excludes completed/no_show/cancelled)
drop function if exists get_reservations_for_date(date);
create function get_reservations_for_date(p_date date) returns jsonb as $$
	with reservation_tables as (
		select
			rt.reservation_id,
			jsonb_agg(rt.floorplan_table_id order by rt.floorplan_table_id) as table_ids,
			jsonb_agg(t.name order by rt.floorplan_table_id) as table_names
		from reservation_table rt
		join floorplan_table t on rt.floorplan_table_id = t.id
		group by rt.reservation_id
	)
	select coalesce(jsonb_agg(jsonb_build_object(
		'id', r.id,
		'guestName', r.guest_name,
		'guestPhone', r.guest_phone,
		'guestEmail', r.guest_email,
		'partySize', r.party_size,
		'reservationDate', r.reservation_date,
		'reservationTime', r.reservation_time,
		'durationMinutes', r.duration_minutes,
		'tableIds', coalesce(rt.table_ids, '[]'),
		'tableNames', coalesce(rt.table_names, '[]'),
		'status', r.status,
		'source', r.source,
		'notes', r.notes,
		'createdAt', r.created_at
	) order by r.reservation_time, r.created_at), '[]')
	from reservation r
	left join reservation_tables rt on r.id = rt.reservation_id
	where r.reservation_date = p_date
		and r.status not in ('completed', 'no_show', 'cancelled', 'declined');
$$ language sql;

comment on function get_reservations_for_date(date) is 'HTTP GET
Get all reservations for a specific date';

-- Get pending reservations (queue)
drop function if exists get_pending_reservations();
create function get_pending_reservations() returns jsonb as $$
	with reservation_tables as (
		select
			rt.reservation_id,
			jsonb_agg(rt.floorplan_table_id order by rt.floorplan_table_id) as table_ids,
			jsonb_agg(t.name order by rt.floorplan_table_id) as table_names
		from reservation_table rt
		join floorplan_table t on rt.floorplan_table_id = t.id
		group by rt.reservation_id
	)
	select coalesce(jsonb_agg(jsonb_build_object(
		'id', r.id,
		'guestName', r.guest_name,
		'guestPhone', r.guest_phone,
		'guestEmail', r.guest_email,
		'partySize', r.party_size,
		'reservationDate', r.reservation_date,
		'reservationTime', r.reservation_time,
		'durationMinutes', r.duration_minutes,
		'tableIds', coalesce(rt.table_ids, '[]'),
		'tableNames', coalesce(rt.table_names, '[]'),
		'notes', r.notes,
		'createdAt', r.created_at
	) order by r.reservation_date, r.reservation_time, r.created_at), '[]')
	from reservation r
	left join reservation_tables rt on r.id = rt.reservation_id
	where r.status = 'pending';
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
create function get_pending_dates() returns jsonb as $$
	select coalesce(jsonb_agg(distinct r.reservation_date order by r.reservation_date), '[]')
	from reservation r
	where r.status = 'pending';
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
) returns jsonb as $$
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
	returning id into v_id;

	-- Assign tables if provided
	if p_table_ids is not null and array_length(p_table_ids, 1) > 0 then
		insert into reservation_table (reservation_id, floorplan_table_id)
		select v_id, unnest(p_table_ids);
	end if;

	return jsonb_build_object('id', v_id, 'status', v_status);
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

-- Drop old function signatures
drop function if exists create_reservation(text, int, date, time, text, text, int, int, text, text);
drop function if exists update_reservation(int, text, text, text, int, date, time, int, int, text);
drop function if exists assign_reservation_table(int, int);

-- Tests
begin;

do $$
declare
	v_result jsonb;
	res_id int;
	fp_id int;
	t1_id int;
	t2_id int;
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

	-- get_reservations_for_date returns empty array when no reservations
	v_result := get_reservations_for_date('2026-01-20');
	assert jsonb_array_length(v_result) = 0, 'should return empty array';

	-- get_pending_count returns 0 when no reservations
	assert (get_pending_count()->>'count')::int = 0, 'pending count should be 0';

	-- create_reservation with single table
	v_result := create_reservation(
		'John Doe', 4, '2026-01-20', '18:00',
		'555-1234', 'john@example.com', 90, array[t1_id], 'online', 'Birthday'
	);
	assert v_result->>'status' = 'pending', 'online should be pending';
	res_id := (v_result->>'id')::int;

	-- get_reservations_for_date shows table
	v_result := get_reservations_for_date('2026-01-20');
	assert v_result->0->'tableNames'->>0 = '1', 'table name should match';

	-- assign_reservation_tables with multiple tables
	perform assign_reservation_tables(res_id, array[t1_id, t2_id]);

	-- Verify multiple tables assigned
	v_result := get_reservations_for_date('2026-01-20');
	assert jsonb_array_length(v_result->0->'tableIds') = 2, 'should have 2 tables';

	-- create_reservation auto-confirms phone reservations
	v_result := create_reservation('Jane Doe', 2, '2026-01-20', '19:00', null, null, 90, null, 'phone');
	assert v_result->>'status' = 'confirmed', 'phone should be auto-confirmed';

	-- Reservation without table should have empty arrays
	v_result := get_reservations_for_date('2026-01-20');
	assert jsonb_array_length(v_result) = 2, 'should have 2 reservations';

	-- get_pending_dates returns dates with pending reservations
	v_result := get_pending_dates();
	assert jsonb_array_length(v_result) = 1, 'should have 1 pending date';

	raise notice 'All reservation tests passed!';
end;
$$;

rollback;
