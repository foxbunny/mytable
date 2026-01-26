-- Get all tables for a floorplan
drop function if exists get_floorplan_tables(int);
create function get_floorplan_tables(p_floorplan_id int) returns setof floorplan_table_info as $$
	select id, floorplan_id, name, capacity, notes, x_pct, y_pct
	from floorplan_table
	where floorplan_id = p_floorplan_id
	order by created_at, id;
$$ language sql;

comment on function get_floorplan_tables(int) is 'HTTP GET
Get all tables for a floorplan';

-- Save a new table (auto-generates name if null)
drop function if exists save_floorplan_table(int, numeric, numeric, text, int, text);
create function save_floorplan_table(
	p_floorplan_id int,
	p_x_pct numeric,
	p_y_pct numeric,
	p_name text default null,
	p_capacity int default 4,
	p_notes text default null
) returns floorplan_table_result as $$
declare
	v_name text;
	v_max_num int;
	v_id int;
begin
	if p_name is null then
		-- Find max numeric name in this floorplan and increment
		select max(ft.name::int)
		into v_max_num
		from floorplan_table ft
		where ft.floorplan_id = p_floorplan_id
			and ft.name ~ '^\d+$';

		v_name := (coalesce(v_max_num, 0) + 1)::text;
	else
		v_name := p_name;
	end if;

	insert into floorplan_table (floorplan_id, name, capacity, notes, x_pct, y_pct)
	values (p_floorplan_id, v_name, p_capacity, p_notes, p_x_pct, p_y_pct)
	returning id into v_id;

	return row(v_id, v_name, p_capacity, p_notes, p_x_pct, p_y_pct)::floorplan_table_result;
end;
$$ language plpgsql;

comment on function save_floorplan_table(int, numeric, numeric, text, int, text) is 'HTTP POST
@authorize
Save a new table to a floorplan';

-- Update an existing table
drop function if exists update_floorplan_table(int, text, int, text, numeric, numeric);
create function update_floorplan_table(
	p_id int,
	p_name text default null,
	p_capacity int default null,
	p_notes text default null,
	p_x_pct numeric default null,
	p_y_pct numeric default null
) returns floorplan_table_result as $$
	update floorplan_table
	set
		name = coalesce(p_name, floorplan_table.name),
		capacity = coalesce(p_capacity, floorplan_table.capacity),
		notes = coalesce(p_notes, floorplan_table.notes),
		x_pct = coalesce(p_x_pct, floorplan_table.x_pct),
		y_pct = coalesce(p_y_pct, floorplan_table.y_pct)
	where floorplan_table.id = p_id
	returning row(id, name, capacity, notes, x_pct, y_pct)::floorplan_table_result;
$$ language sql;

comment on function update_floorplan_table(int, text, int, text, numeric, numeric) is 'HTTP POST
@authorize
Update a floorplan table';

-- Delete a table
drop function if exists delete_floorplan_table(int);
create function delete_floorplan_table(p_id int) returns floorplan_table_delete_result as $$
	delete from floorplan_table where id = p_id
	returning row(id)::floorplan_table_delete_result;
$$ language sql;

comment on function delete_floorplan_table(int) is 'HTTP POST
@authorize
Delete a floorplan table';

-- Tests (wrapped in transaction, always rolled back)
begin;

do $$
declare
	v_result floorplan_table_result;
	v_delete_result floorplan_table_delete_result;
	v_info floorplan_table_info;
	v_list floorplan_table_info[];
	fp_id int;
	table_id int;
begin
	truncate floorplan restart identity cascade;

	-- Create a floorplan for testing
	insert into floorplan (name, image_path, image_width, image_height, sort_order)
	values ('Test Floor', '/test.png', 800, 600, 0)
	returning id into fp_id;

	-- get_floorplan_tables returns empty set when no tables
	select array_agg(t) into v_list from get_floorplan_tables(fp_id) t;
	assert v_list is null, 'get_floorplan_tables should return empty set';

	-- save_floorplan_table auto-generates name
	v_result := save_floorplan_table(fp_id, 0.25, 0.50);
	assert v_result.name = '1', 'first table should be named 1';
	table_id := v_result.id;

	-- second table should be named 2
	v_result := save_floorplan_table(fp_id, 0.50, 0.50);
	assert v_result.name = '2', 'second table should be named 2';

	-- custom name works
	v_result := save_floorplan_table(fp_id, 0.75, 0.50, 'VIP');
	assert v_result.name = 'VIP', 'custom name should be preserved';

	-- next auto-name continues from 2
	v_result := save_floorplan_table(fp_id, 0.25, 0.75);
	assert v_result.name = '3', 'should continue numbering from highest numeric';

	-- get_floorplan_tables returns all tables
	select array_agg(t) into v_list from get_floorplan_tables(fp_id) t;
	assert array_length(v_list, 1) = 4, 'should have 4 tables';

	-- update_floorplan_table updates fields
	v_result := update_floorplan_table(table_id, 'Table A', 4, 'Near window');
	assert v_result.name = 'Table A', 'name should be updated';
	assert v_result.capacity = 4, 'capacity should be updated';
	assert v_result.notes = 'Near window', 'notes should be updated';

	-- update_floorplan_table partial update (position only)
	v_result := update_floorplan_table(table_id, null, null, null, 0.30, 0.55);
	assert v_result.x_pct = 0.30, 'x should be updated';
	assert v_result.y_pct = 0.55, 'y should be updated';
	assert v_result.name = 'Table A', 'name should remain unchanged';

	-- delete_floorplan_table removes table
	v_delete_result := delete_floorplan_table(table_id);
	select array_agg(t) into v_list from get_floorplan_tables(fp_id) t;
	assert array_length(v_list, 1) = 3, 'should have 3 tables after delete';

	raise notice 'All floorplan_table tests passed!';
end;
$$;

rollback;
