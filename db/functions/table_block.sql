-- Block a table (for walk-ins or maintenance)
drop function if exists block_table(int, text);
create function block_table(p_table_id int, p_notes text default null) returns table_block_result as $$
	insert into table_block (floorplan_table_id, notes)
	values (p_table_id, p_notes)
	on conflict (floorplan_table_id) do update
		set blocked_at = now(), notes = excluded.notes
	returning row(id)::table_block_result;
$$ language sql;

comment on function block_table(int, text) is 'HTTP POST
@authorize
Block a table for walk-ins or maintenance';

-- Unblock a table
drop function if exists unblock_table(int);
create function unblock_table(p_table_id int) returns void as $$
	delete from table_block
	where floorplan_table_id = p_table_id;
$$ language sql;

comment on function unblock_table(int) is 'HTTP POST
@authorize
Remove block from a table';

-- Get all currently blocked tables
-- Block duration: 30 min base + 30 min per seat
drop function if exists get_blocked_tables();
create function get_blocked_tables() returns setof table_block_info as $$
	select
		b.id,
		b.floorplan_table_id,
		t.name,
		t.floorplan_id,
		t.capacity,
		b.blocked_at,
		b.blocked_at + make_interval(mins => 30 + 30 * t.capacity),
		b.notes
	from table_block b
	join floorplan_table t on b.floorplan_table_id = t.id
	order by b.blocked_at desc;
$$ language sql;

comment on function get_blocked_tables() is 'HTTP GET
Get all currently blocked tables with their expiry times';

-- Clean up expired blocks
drop function if exists cleanup_expired_blocks();
create function cleanup_expired_blocks() returns pending_count_result as $$
	with deleted as (
		delete from table_block b
		using floorplan_table t
		where b.floorplan_table_id = t.id
			and b.blocked_at + make_interval(mins => 30 + 30 * t.capacity) < now()
		returning b.id
	)
	select row(count(*)::int)::pending_count_result from deleted;
$$ language sql;

comment on function cleanup_expired_blocks() is 'HTTP POST
@authorize
Remove expired table blocks';

-- Tests
begin;

do $$
declare
	v_result table_block_result;
	v_block table_block_info;
	v_list table_block_info[];
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

	-- get_blocked_tables returns empty set initially
	select array_agg(b) into v_list from get_blocked_tables() b;
	assert v_list is null, 'should return empty set';

	-- block_table blocks a table and returns id
	v_result := block_table(table1_id, 'Walk-in');
	block_id := v_result.id;
	assert block_id is not null, 'block should return id';

	-- get_blocked_tables returns the blocked table with end time
	select * into v_block from get_blocked_tables() limit 1;
	assert v_block.table_id = table1_id, 'table_id should match';
	assert v_block.notes = 'Walk-in', 'notes should match';
	assert v_block.capacity = 4, 'capacity should be included';
	assert v_block.block_ends_at is not null, 'block_ends_at should be present';

	-- block_table with same table updates the block
	v_result := block_table(table1_id, 'Maintenance');
	block_id := v_result.id;
	select array_agg(b) into v_list from get_blocked_tables() b;
	assert array_length(v_list, 1) = 1, 'should still have 1 blocked table';
	assert v_list[1].notes = 'Maintenance', 'notes should be updated';

	-- block second table (capacity 2 = 90 min block)
	perform block_table(table2_id);
	select array_agg(b) into v_list from get_blocked_tables() b;
	assert array_length(v_list, 1) = 2, 'should have 2 blocked tables';

	-- unblock_table removes block
	perform unblock_table(table1_id);
	select array_agg(b) into v_list from get_blocked_tables() b;
	assert array_length(v_list, 1) = 1, 'should have 1 blocked table after unblock';
	assert v_list[1].table_id = table2_id, 'remaining block should be table2';

	raise notice 'All table_block tests passed!';
end;
$$;

rollback;
