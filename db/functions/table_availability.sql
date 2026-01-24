-- Composite type for reservation summary in table status
drop type if exists reservation_summary cascade;
create type reservation_summary as (
	id int,
	guest_name text,
	party_size int,
	reservation_time time,
	duration_minutes int,
	status text
);

-- Get table status for a specific date (includes reservations and block status)
-- Block duration: 30 min base + 30 min per seat
drop function if exists get_table_status_for_date(date);
create function get_table_status_for_date(p_date date)
returns table(
	id int,
	floorplan_id int,
	name text,
	capacity int,
	x_pct numeric,
	y_pct numeric,
	is_blocked boolean,
	block_notes text,
	block_ends_at timestamptz,
	reservations reservation_summary[]
) as $$
	with table_reservations as (
		select
			rt.floorplan_table_id,
			array_agg(
				row(r.id, r.guest_name, r.party_size, r.reservation_time, r.duration_minutes, r.status)::reservation_summary
				order by r.reservation_time
			) as reservations
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
	select
		ft.id,
		ft.floorplan_id,
		ft.name,
		ft.capacity,
		ft.x_pct,
		ft.y_pct,
		ab.id is not null as is_blocked,
		ab.notes as block_notes,
		ab.block_ends_at,
		coalesce(tr.reservations, '{}') as reservations
	from floorplan_table ft
	left join active_blocks ab on ft.id = ab.floorplan_table_id
	left join table_reservations tr on ft.id = tr.floorplan_table_id
	order by ft.floorplan_id, ft.name;
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
) returns table(
	id int,
	floorplan_id int,
	floorplan_name text,
	name text,
	capacity int
) as $$
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
	select
		ft.id,
		ft.floorplan_id,
		f.name as floorplan_name,
		ft.name,
		ft.capacity
	from floorplan_table ft
	join floorplan f on ft.floorplan_id = f.id
	where ft.capacity >= p_party_size
		and ft.id not in (select floorplan_table_id from blocked_tables)
		and ft.id not in (select floorplan_table_id from conflicting_reservations)
	order by f.sort_order, f.id, ft.name;
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
) returns table(
	id int,
	floorplan_id int,
	name text,
	capacity int,
	x_pct numeric,
	y_pct numeric,
	is_available boolean,
	is_blocked boolean,
	block_ends_at timestamptz,
	has_conflict boolean
) as $$
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
	select
		ft.id,
		ft.floorplan_id,
		ft.name,
		ft.capacity,
		ft.x_pct,
		ft.y_pct,
		bt.floorplan_table_id is null and cr.floorplan_table_id is null as is_available,
		bt.floorplan_table_id is not null as is_blocked,
		bt.block_ends_at,
		cr.floorplan_table_id is not null as has_conflict
	from floorplan_table ft
	left join blocked_tables bt on ft.id = bt.floorplan_table_id
	left join conflicting_reservations cr on ft.id = cr.floorplan_table_id
	order by ft.floorplan_id, ft.name;
$$ language sql;

comment on function get_tables_for_slot(date, time, int, int) is 'HTTP GET
Get all tables with availability flags for booking UI';

-- Tests
begin;

do $$
declare
	result record;
	fp1_id int;
	fp2_id int;
	t1_id int;
	t2_id int;
	t3_id int;
	res_id int;
	cnt int;
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
	select count(*) into cnt from get_table_status_for_date('2026-01-20');
	assert cnt = 3, 'should have 3 tables';

	select * into result from get_table_status_for_date('2026-01-20') where id = t1_id;
	assert result.is_blocked = false, 'should not be blocked';
	assert array_length(result.reservations, 1) is null, 'should have no reservations';

	-- Add a reservation using junction table
	insert into reservation (guest_name, party_size, reservation_date, reservation_time, duration_minutes, status)
	values ('John', 2, '2026-01-20', '18:00', 90, 'confirmed')
	returning id into res_id;

	insert into reservation_table (reservation_id, floorplan_table_id)
	values (res_id, t1_id);

	-- get_table_status_for_date shows reservation
	select * into result from get_table_status_for_date('2026-01-20') where id = t1_id;
	assert array_length(result.reservations, 1) = 1, 'table 1 should have 1 reservation';
	assert (result.reservations[1]).guest_name = 'John', 'guest name should match';

	-- Block table 2 at 17:00 (capacity 2 = 90 min block, ends at 18:30)
	insert into table_block (floorplan_table_id, blocked_at, notes)
	values (t2_id, '2026-01-20 17:00'::timestamptz, 'Walk-in');

	select * into result from get_table_status_for_date('2026-01-20') where id = t2_id;
	assert result.is_blocked = true, 'table 2 should be blocked on 2026-01-20';

	-- check_table_availability: 18:00 slot should exclude table 1 (occupied) and table 2 (blocked until 18:30)
	select count(*) into cnt from check_table_availability('2026-01-20', '18:00', 90, 2);
	assert cnt = 1, 'only P1 should be available at 18:00';
	select * into result from check_table_availability('2026-01-20', '18:00', 90, 2);
	assert result.name = 'P1', 'available table should be P1';

	-- check_table_availability: 19:00 slot (after block expires at 18:30) should include table 2
	select count(*) into cnt from check_table_availability('2026-01-20', '19:00', 90, 2);
	assert cnt = 2, 'table 2 and P1 should be available at 19:00 (block expired)';

	-- check_table_availability: 20:00 slot (after table 1's reservation) should include table 1
	select count(*) into cnt from check_table_availability('2026-01-20', '20:00', 90, 2);
	assert cnt = 3, 'all 3 tables should be available at 20:00';

	-- check_table_availability: party of 5 excludes small tables
	select count(*) into cnt from check_table_availability('2026-01-20', '20:00', 90, 5);
	assert cnt = 1, 'only P1 (capacity 6) should fit party of 5';

	-- Test get_tables_for_slot: returns all tables with availability flags
	select count(*) into cnt from get_tables_for_slot('2026-01-20', '18:00', 90);
	assert cnt = 3, 'should return all 3 tables';

	-- Table 1 should be unavailable (has conflict)
	select * into result from get_tables_for_slot('2026-01-20', '18:00', 90) where id = t1_id;
	assert result.is_available = false, 't1 should be unavailable';
	assert result.has_conflict = true, 't1 should have conflict';

	-- Table 2 should be unavailable (blocked)
	select * into result from get_tables_for_slot('2026-01-20', '18:00', 90) where id = t2_id;
	assert result.is_available = false, 't2 should be unavailable';
	assert result.is_blocked = true, 't2 should be blocked';

	-- Test multi-table reservation: assign same reservation to t3
	insert into reservation_table (reservation_id, floorplan_table_id)
	values (res_id, t3_id);

	-- P1 should now be unavailable too
	select * into result from get_tables_for_slot('2026-01-20', '18:00', 90) where id = t3_id;
	assert result.is_available = false, 'P1 should be unavailable due to shared reservation';

	-- get_tables_for_slot with exclude_reservation_id should exclude that reservation's conflict
	select * into result from get_tables_for_slot('2026-01-20', '18:00', 90, res_id) where id = t1_id;
	assert result.is_available = true, 't1 should be available when excluding its reservation';

	raise notice 'All table_availability tests passed!';
end;
$$;

rollback;
