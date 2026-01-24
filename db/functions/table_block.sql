-- Block a table (for walk-ins or maintenance)
drop function if exists block_table(int, text);
create function block_table(p_table_id int, p_notes text default null) returns jsonb as $$
	insert into table_block (floorplan_table_id, notes)
	values (p_table_id, p_notes)
	on conflict (floorplan_table_id) do update
		set blocked_at = now(), notes = excluded.notes
	returning jsonb_build_object('id', id);
$$ language sql;

comment on function block_table(int, text) is 'HTTP POST
@authorize
Block a table for walk-ins or maintenance';

-- Unblock a table
drop function if exists unblock_table(int);
create function unblock_table(p_table_id int) returns jsonb as $$
	delete from table_block
	where floorplan_table_id = p_table_id
	returning '{}'::jsonb;
$$ language sql;

comment on function unblock_table(int) is 'HTTP POST
@authorize
Remove block from a table';

-- Get all currently blocked tables
-- Block duration: 30 min base + 30 min per seat
drop function if exists get_blocked_tables();
create function get_blocked_tables()
returns table(
	id int,
	table_id int,
	table_name text,
	floorplan_id int,
	capacity int,
	blocked_at timestamptz,
	block_ends_at timestamptz,
	notes text
) as $$
	select
		b.id,
		b.floorplan_table_id as table_id,
		t.name as table_name,
		t.floorplan_id,
		t.capacity,
		b.blocked_at,
		b.blocked_at + make_interval(mins => 30 + 30 * t.capacity) as block_ends_at,
		b.notes
	from table_block b
	join floorplan_table t on b.floorplan_table_id = t.id
	order by b.blocked_at desc;
$$ language sql;

comment on function get_blocked_tables() is 'HTTP GET
Get all currently blocked tables with their expiry times';

-- Clean up expired blocks
drop function if exists cleanup_expired_blocks();
create function cleanup_expired_blocks() returns jsonb as $$
	with deleted as (
		delete from table_block b
		using floorplan_table t
		where b.floorplan_table_id = t.id
			and b.blocked_at + make_interval(mins => 30 + 30 * t.capacity) < now()
		returning b.id
	)
	select jsonb_build_object('count', count(*)::int) from deleted;
$$ language sql;

comment on function cleanup_expired_blocks() is 'HTTP POST
@authorize
Remove expired table blocks';

-- Tests
begin;

do $$
declare
	v_result jsonb;
	result record;
	fp_id int;
	table1_id int;
	table2_id int;
	block_id int;
	block_end timestamptz;
	cnt int;
begin
	truncate floorplan restart identity cascade;

	-- Setup: create floorplan and tables
	insert into floorplan (name, image_path, image_width, image_height)
	values ('Test Floor', '/test.png', 800, 600)
	returning id into fp_id;

	-- Table 1: capacity 4 -> block duration = 30 + 30*4 = 150 min
	insert into floorplan_table (floorplan_id, name, capacity, x_pct, y_pct)
	values (fp_id, '1', 4, 0.25, 0.5)
	returning id into table1_id;

	-- Table 2: capacity 2 -> block duration = 30 + 30*2 = 90 min
	insert into floorplan_table (floorplan_id, name, capacity, x_pct, y_pct)
	values (fp_id, '2', 2, 0.75, 0.5)
	returning id into table2_id;

	-- get_blocked_tables returns empty initially
	assert not exists(select 1 from get_blocked_tables()), 'should return no rows';

	-- block_table blocks a table and returns id
	v_result := block_table(table1_id, 'Walk-in');
	block_id := (v_result->>'id')::int;
	assert block_id is not null, 'block should return id';

	-- get_blocked_tables returns the blocked table with end time
	select * into result from get_blocked_tables();
	assert result.table_id = table1_id, 'tableId should match';
	assert result.notes = 'Walk-in', 'notes should match';
	assert result.capacity = 4, 'capacity should be included';
	assert result.block_ends_at is not null, 'blockEndsAt should be present';

	-- Verify block duration: capacity 4 = 150 min block
	block_end := result.block_ends_at;
	assert block_end - result.blocked_at = interval '150 minutes',
		'block duration for capacity 4 should be 150 min';

	-- block_table with same table updates the block
	v_result := block_table(table1_id, 'Maintenance');
	block_id := (v_result->>'id')::int;
	select count(*) into cnt from get_blocked_tables();
	assert cnt = 1, 'should still have 1 blocked table';
	select * into result from get_blocked_tables();
	assert result.notes = 'Maintenance', 'notes should be updated';

	-- block second table (capacity 2 = 90 min block)
	perform block_table(table2_id);
	select count(*) into cnt from get_blocked_tables();
	assert cnt = 2, 'should have 2 blocked tables';

	-- Verify block duration for table 2: capacity 2 = 90 min block
	select * into result from get_blocked_tables() where table_id = table2_id;
	assert result.block_ends_at - result.blocked_at = interval '90 minutes',
		'block duration for capacity 2 should be 90 min';

	-- unblock_table removes block
	perform unblock_table(table1_id);
	select count(*) into cnt from get_blocked_tables();
	assert cnt = 1, 'should have 1 blocked table after unblock';
	select * into result from get_blocked_tables();
	assert result.table_id = table2_id, 'remaining block should be table2';

	raise notice 'All table_block tests passed!';
end;
$$;

rollback;
