-- Clean up old custom type (no longer used)
drop type if exists reservation_summary cascade;

-- Get table status for a specific date (includes reservations and block status)
-- Block duration: 30 min base + 30 min per seat
drop function if exists get_table_status_for_date(date);
create function get_table_status_for_date(p_date date) returns jsonb as $$
	with table_reservations as (
		select
			rt.floorplan_table_id,
			jsonb_agg(jsonb_build_object(
				'id', r.id,
				'guestName', r.guest_name,
				'partySize', r.party_size,
				'reservationTime', r.reservation_time,
				'durationMinutes', r.duration_minutes,
				'status', r.status
			) order by r.reservation_time) as reservations
		from reservation r
		join reservation_table rt on r.id = rt.reservation_id
		where r.reservation_date = p_date
			and r.status in ('pending', 'confirmed')
		group by rt.floorplan_table_id
	),
	active_blocks as (
		select
			b.id,
			b.floorplan_table_id,
			b.blocked_at,
			b.notes,
			b.blocked_at + make_interval(mins => 30 + 30 * ft.capacity) as block_ends_at
		from table_block b
		join floorplan_table ft on b.floorplan_table_id = ft.id
		where b.blocked_at < (p_date + 1)::timestamptz
			and b.blocked_at + make_interval(mins => 30 + 30 * ft.capacity) > p_date::timestamptz
	)
	select coalesce(
		jsonb_agg(jsonb_build_object(
		'id', ft.id,
		'floorplanId', ft.floorplan_id,
		'name', ft.name,
		'capacity', ft.capacity,
		'xPct', ft.x_pct,
		'yPct', ft.y_pct,
		'isBlocked', ab.id is not null,
		'blockNotes', ab.notes,
		'blockEndsAt', ab.block_ends_at,
		'reservations', coalesce(tr.reservations, '[]')
	) order by ft.floorplan_id, ft.name), '[]')
	from floorplan_table ft
	left join active_blocks ab on ft.id = ab.floorplan_table_id
	left join table_reservations tr on ft.id = tr.floorplan_table_id;
$$ language sql;

comment on function get_table_status_for_date(date) is 'HTTP GET
Get all tables with their reservation and block status for a date';

-- Check table availability for a specific time slot
-- Block duration: 30 min base + 30 min per seat
drop function if exists check_table_availability(date, time, int, int);
create function check_table_availability(
	p_date date,
	p_time time,
	p_duration int,
	p_party_size int
) returns jsonb as $$
	with slot_times as (
		select
			(p_date + p_time)::timestamptz as slot_start,
			(p_date + p_time + (p_duration || ' minutes')::interval)::timestamptz as slot_end
	),
	conflicting_reservations as (
		select distinct rt.floorplan_table_id
		from reservation r
		join reservation_table rt on r.id = rt.reservation_id
		cross join slot_times
		where r.reservation_date = p_date
			and r.status in ('pending', 'confirmed')
			-- Overlap check: start1 < end2 AND end1 > start2
			and r.reservation_time < slot_times.slot_end::time
			and (r.reservation_time + (r.duration_minutes || ' minutes')::interval) > p_time
	),
	blocked_tables as (
		select b.floorplan_table_id
		from table_block b
		join floorplan_table ft on b.floorplan_table_id = ft.id
		cross join slot_times
		-- Block overlaps with slot if: block_start < slot_end AND block_end > slot_start
		where b.blocked_at < slot_times.slot_end
			and b.blocked_at + make_interval(mins => 30 + 30 * ft.capacity) > slot_times.slot_start
	)
	select coalesce(jsonb_agg(jsonb_build_object(
		'id', ft.id,
		'floorplanId', ft.floorplan_id,
		'floorplanName', f.name,
		'name', ft.name,
		'capacity', ft.capacity
	) order by f.sort_order, f.id, ft.name), '[]')
	from floorplan_table ft
	join floorplan f on ft.floorplan_id = f.id
	where ft.capacity >= p_party_size
		and ft.id not in (select floorplan_table_id from blocked_tables)
		and ft.id not in (select floorplan_table_id from conflicting_reservations);
$$ language sql;

comment on function check_table_availability(date, time, int, int) is 'HTTP GET
Get available tables for a specific time slot and party size';

-- Get ALL tables with availability flags for a time slot (for booking UI)
-- Block duration: 30 min base + 30 min per seat
drop function if exists get_tables_for_slot(date, time, int, int);
create function get_tables_for_slot(
	p_date date,
	p_time time,
	p_duration int,
	p_exclude_reservation_id int default null
) returns jsonb as $$
	with slot_times as (
		select
			(p_date + p_time)::timestamptz as slot_start,
			(p_date + p_time + (p_duration || ' minutes')::interval)::timestamptz as slot_end
	),
	conflicting_reservations as (
		select distinct rt.floorplan_table_id
		from reservation r
		join reservation_table rt on r.id = rt.reservation_id
		cross join slot_times
		where r.reservation_date = p_date
			and r.status in ('pending', 'confirmed')
			and r.id is distinct from p_exclude_reservation_id
			-- Overlap check: start1 < end2 AND end1 > start2
			and r.reservation_time < slot_times.slot_end::time
			and (r.reservation_time + (r.duration_minutes || ' minutes')::interval) > p_time
	),
	blocked_tables as (
		select
			b.floorplan_table_id,
			b.blocked_at + make_interval(mins => 30 + 30 * ft.capacity) as block_ends_at
		from table_block b
		join floorplan_table ft on b.floorplan_table_id = ft.id
		cross join slot_times
		-- Block overlaps with slot if: block_start < slot_end AND block_end > slot_start
		where b.blocked_at < slot_times.slot_end
			and b.blocked_at + make_interval(mins => 30 + 30 * ft.capacity) > slot_times.slot_start
	)
	select coalesce(jsonb_agg(jsonb_build_object(
		'id', ft.id,
		'floorplanId', ft.floorplan_id,
		'name', ft.name,
		'capacity', ft.capacity,
		'xPct', ft.x_pct,
		'yPct', ft.y_pct,
		'isAvailable', bt.floorplan_table_id is null and cr.floorplan_table_id is null,
		'isBlocked', bt.floorplan_table_id is not null,
		'blockEndsAt', bt.block_ends_at,
		'hasConflict', cr.floorplan_table_id is not null
	) order by ft.floorplan_id, ft.name), '[]')
	from floorplan_table ft
	left join blocked_tables bt on ft.id = bt.floorplan_table_id
	left join conflicting_reservations cr on ft.id = cr.floorplan_table_id;
$$ language sql;

comment on function get_tables_for_slot(date, time, int, int) is 'HTTP GET
Get all tables with availability flags for booking UI';

-- Tests
begin;

do $$
declare
	v_result jsonb;
	v_table jsonb;
	fp1_id int;
	fp2_id int;
	t1_id int;
	t2_id int;
	t3_id int;
	res_id int;
begin
	truncate floorplan restart identity cascade;

	-- Setup: create 2 floorplans with tables
	insert into floorplan (name, image_path, image_width, image_height, sort_order)
	values ('Main Floor', '/main.png', 800, 600, 0)
	returning id into fp1_id;

	insert into floorplan (name, image_path, image_width, image_height, sort_order)
	values ('Patio', '/patio.png', 600, 400, 1)
	returning id into fp2_id;

	insert into floorplan_table (floorplan_id, name, capacity, x_pct, y_pct)
	values (fp1_id, '1', 4, 0.25, 0.5)
	returning id into t1_id;

	insert into floorplan_table (floorplan_id, name, capacity, x_pct, y_pct)
	values (fp1_id, '2', 2, 0.75, 0.5)
	returning id into t2_id;

	insert into floorplan_table (floorplan_id, name, capacity, x_pct, y_pct)
	values (fp2_id, 'P1', 6, 0.5, 0.5)
	returning id into t3_id;

	-- get_table_status_for_date returns all tables with no reservations
	v_result := get_table_status_for_date('2026-01-20');
	assert jsonb_array_length(v_result) = 3, 'should have 3 tables';

	-- Find table 1 in result
	select elem into v_table from jsonb_array_elements(v_result) elem where (elem->>'id')::int = t1_id;
	assert (v_table->>'isBlocked')::boolean = false, 'should not be blocked';
	assert jsonb_array_length(v_table->'reservations') = 0, 'should have no reservations';

	-- Add a reservation using junction table
	insert into reservation (guest_name, party_size, reservation_date, reservation_time, duration_minutes, status)
	values ('John', 2, '2026-01-20', '18:00', 90, 'confirmed')
	returning id into res_id;

	insert into reservation_table (reservation_id, floorplan_table_id)
	values (res_id, t1_id);

	-- get_table_status_for_date shows reservation
	v_result := get_table_status_for_date('2026-01-20');
	select elem into v_table from jsonb_array_elements(v_result) elem where (elem->>'id')::int = t1_id;
	assert jsonb_array_length(v_table->'reservations') = 1, 'table 1 should have 1 reservation';
	assert v_table->'reservations'->0->>'guestName' = 'John', 'guest name should match';

	-- Block table 2 at 17:00 (capacity 2 = 90 min block, ends at 18:30)
	insert into table_block (floorplan_table_id, blocked_at, notes)
	values (t2_id, '2026-01-20 17:00'::timestamptz, 'Walk-in');

	v_result := get_table_status_for_date('2026-01-20');
	select elem into v_table from jsonb_array_elements(v_result) elem where (elem->>'id')::int = t2_id;
	assert (v_table->>'isBlocked')::boolean = true, 'table 2 should be blocked on 2026-01-20';

	-- check_table_availability: 18:00 slot should exclude table 1 (occupied) and table 2 (blocked until 18:30)
	v_result := check_table_availability('2026-01-20', '18:00', 90, 2);
	assert jsonb_array_length(v_result) = 1, 'only P1 should be available at 18:00';
	assert v_result->0->>'name' = 'P1', 'available table should be P1';

	-- check_table_availability: 19:00 slot (after block expires at 18:30) should include table 2
	v_result := check_table_availability('2026-01-20', '19:00', 90, 2);
	assert jsonb_array_length(v_result) = 2, 'table 2 and P1 should be available at 19:00 (block expired)';

	-- check_table_availability: 20:00 slot (after table 1's reservation) should include table 1
	v_result := check_table_availability('2026-01-20', '20:00', 90, 2);
	assert jsonb_array_length(v_result) = 3, 'all 3 tables should be available at 20:00';

	-- check_table_availability: party of 5 excludes small tables
	v_result := check_table_availability('2026-01-20', '20:00', 90, 5);
	assert jsonb_array_length(v_result) = 1, 'only P1 (capacity 6) should fit party of 5';

	-- Test get_tables_for_slot: returns all tables with availability flags
	v_result := get_tables_for_slot('2026-01-20', '18:00', 90);
	assert jsonb_array_length(v_result) = 3, 'should return all 3 tables';

	-- Table 1 should be unavailable (has conflict)
	select elem into v_table from jsonb_array_elements(v_result) elem where (elem->>'id')::int = t1_id;
	assert (v_table->>'isAvailable')::boolean = false, 't1 should be unavailable';
	assert (v_table->>'hasConflict')::boolean = true, 't1 should have conflict';

	-- Table 2 should be unavailable (blocked)
	select elem into v_table from jsonb_array_elements(v_result) elem where (elem->>'id')::int = t2_id;
	assert (v_table->>'isAvailable')::boolean = false, 't2 should be unavailable';
	assert (v_table->>'isBlocked')::boolean = true, 't2 should be blocked';

	-- Test multi-table reservation: assign same reservation to t3
	insert into reservation_table (reservation_id, floorplan_table_id)
	values (res_id, t3_id);

	-- P1 should now be unavailable too
	v_result := get_tables_for_slot('2026-01-20', '18:00', 90);
	select elem into v_table from jsonb_array_elements(v_result) elem where (elem->>'id')::int = t3_id;
	assert (v_table->>'isAvailable')::boolean = false, 'P1 should be unavailable due to shared reservation';

	-- get_tables_for_slot with exclude_reservation_id should exclude that reservation's conflict
	v_result := get_tables_for_slot('2026-01-20', '18:00', 90, res_id);
	select elem into v_table from jsonb_array_elements(v_result) elem where (elem->>'id')::int = t1_id;
	assert (v_table->>'isAvailable')::boolean = true, 't1 should be available when excluding its reservation';

	raise notice 'All table_availability tests passed!';
end;
$$;

rollback;
