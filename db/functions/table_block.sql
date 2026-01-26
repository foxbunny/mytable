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
create function get_blocked_tables() returns jsonb as $$
	select coalesce(jsonb_agg(jsonb_build_object(
		'id', b.id,
		'tableId', b.floorplan_table_id,
		'tableName', t.name,
		'floorplanId', t.floorplan_id,
		'capacity', t.capacity,
		'blockedAt', b.blocked_at,
		'blockEndsAt', b.blocked_at + make_interval(mins => 30 + 30 * t.capacity),
		'notes', b.notes
	) order by b.blocked_at desc), '[]')
	from table_block b
	join floorplan_table t on b.floorplan_table_id = t.id;
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
	v_block jsonb;
	fp_id int;
	table1_id int;
	table2_id int;
	block_id int;
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

	-- get_blocked_tables returns empty array initially
	v_result := get_blocked_tables();
	assert jsonb_array_length(v_result) = 0, 'should return empty array';

	-- block_table blocks a table and returns id
	v_result := block_table(table1_id, 'Walk-in');
	block_id := (v_result->>'id')::int;
	assert block_id is not null, 'block should return id';

	-- get_blocked_tables returns the blocked table with end time
	v_result := get_blocked_tables();
	v_block := v_result->0;
	assert (v_block->>'tableId')::int = table1_id, 'tableId should match';
	assert v_block->>'notes' = 'Walk-in', 'notes should match';
	assert (v_block->>'capacity')::int = 4, 'capacity should be included';
	assert v_block->>'blockEndsAt' is not null, 'blockEndsAt should be present';

	-- block_table with same table updates the block
	v_result := block_table(table1_id, 'Maintenance');
	block_id := (v_result->>'id')::int;
	v_result := get_blocked_tables();
	assert jsonb_array_length(v_result) = 1, 'should still have 1 blocked table';
	assert v_result->0->>'notes' = 'Maintenance', 'notes should be updated';

	-- block second table (capacity 2 = 90 min block)
	perform block_table(table2_id);
	v_result := get_blocked_tables();
	assert jsonb_array_length(v_result) = 2, 'should have 2 blocked tables';

	-- unblock_table removes block
	perform unblock_table(table1_id);
	v_result := get_blocked_tables();
	assert jsonb_array_length(v_result) = 1, 'should have 1 blocked table after unblock';
	assert (v_result->0->>'tableId')::int = table2_id, 'remaining block should be table2';

	raise notice 'All table_block tests passed!';
end;
$$;

rollback;
