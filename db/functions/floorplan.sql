-- List all floorplans
drop function if exists get_floorplans();
create function get_floorplans()
returns table(id int, name text, image_path text, image_width int, image_height int, sort_order int) as $$
	select id, name, image_path, image_width, image_height, sort_order
	from floorplan
	order by sort_order, id;
$$ language sql;

comment on function get_floorplans() is 'HTTP GET
Get all floorplans';

-- Upload floorplan image (NpgsqlRest file system handler)
drop function if exists upload_floorplan_image(json);
create function upload_floorplan_image(_meta json default null) returns json as $$
begin
	return json_build_object(
		'path', '/' || substr(_meta->0->>'filePath', 8)
	);
end;
$$ language plpgsql;

comment on function upload_floorplan_image(json) is 'HTTP POST
@authorize
@upload for file_system
Upload floorplan image file';

-- Save floorplan (after upload + dimension detection)
drop function if exists save_floorplan(text, text, int, int, int);
create function save_floorplan(
	p_name text,
	p_image_path text,
	p_image_width int,
	p_image_height int,
	p_sort_order int default 0
) returns jsonb as $$
	insert into floorplan (name, image_path, image_width, image_height, sort_order)
	values (p_name, p_image_path, p_image_width, p_image_height, p_sort_order)
	returning jsonb_build_object('id', id);
$$ language sql;

comment on function save_floorplan(text, text, int, int, int) is 'HTTP POST
@authorize
Save a new floorplan';

-- Update floorplan
drop function if exists update_floorplan(int, text, int);
create function update_floorplan(
	p_id int,
	p_name text,
	p_sort_order int default null
) returns jsonb as $$
	update floorplan
	set name = p_name,
		sort_order = coalesce(p_sort_order, sort_order)
	where id = p_id
	returning jsonb_build_object('id', id);
$$ language sql;

comment on function update_floorplan(int, text, int) is 'HTTP POST
@authorize
Update floorplan name or sort order';

-- Delete floorplan
drop function if exists delete_floorplan(int);
create function delete_floorplan(p_id int) returns jsonb as $$
	delete from floorplan where id = p_id
	returning jsonb_build_object('id', id);
$$ language sql;

comment on function delete_floorplan(int) is 'HTTP POST
@authorize
Delete a floorplan';

-- Tests (wrapped in transaction, always rolled back)
begin;

do $$
declare
	v_result jsonb;
	fp_id int;
	result record;
	cnt int;
begin
	truncate floorplan restart identity cascade;

	-- get_floorplans returns empty when no floorplans
	assert not exists(select 1 from get_floorplans()), 'get_floorplans should return no rows';

	-- save_floorplan creates floorplan and returns id
	v_result := save_floorplan('Main Floor', '/uploads/main.png', 800, 600, 0);
	fp_id := (v_result->>'id')::int;
	assert fp_id = 1, 'id should be 1';

	-- get_floorplans returns created floorplan
	select * into result from get_floorplans();
	assert result.name = 'Main Floor', 'name should match';
	assert result.image_path = '/uploads/main.png', 'image_path should match';
	assert result.image_width = 800, 'image_width should match';
	assert result.image_height = 600, 'image_height should match';

	-- save_floorplan respects sort_order
	perform save_floorplan('Patio', '/uploads/patio.png', 400, 300, 1);
	perform save_floorplan('Rooftop', '/uploads/rooftop.png', 600, 400, 2);
	select count(*) into cnt from get_floorplans();
	assert cnt = 3, 'should have 3 floorplans';

	-- Check ordering
	select name into result from get_floorplans() limit 1;
	assert result.name = 'Main Floor', 'first should be Main Floor';

	-- update_floorplan updates name
	perform update_floorplan(fp_id, 'Ground Floor', null);
	select name into result from get_floorplans() where id = fp_id;
	assert result.name = 'Ground Floor', 'name should be updated';

	-- delete_floorplan removes floorplan
	perform delete_floorplan(fp_id);
	select count(*) into cnt from get_floorplans();
	assert cnt = 2, 'should have 2 floorplans after delete';

	raise notice 'All floorplan tests passed!';
end;
$$;

rollback;
