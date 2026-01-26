-- List all floorplans
drop function if exists get_floorplans();
create function get_floorplans() returns jsonb as $$
	select coalesce(jsonb_agg(jsonb_build_object(
		'id', id,
		'name', name,
		'imagePath', image_path,
		'imageWidth', image_width,
		'imageHeight', image_height,
		'sortOrder', sort_order
	) order by sort_order, id), '[]')
	from floorplan;
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
begin
	truncate floorplan restart identity cascade;

	-- get_floorplans returns empty array when no floorplans
	v_result := get_floorplans();
	assert jsonb_array_length(v_result) = 0, 'get_floorplans should return empty array';

	-- save_floorplan creates floorplan and returns id
	v_result := save_floorplan('Main Floor', '/uploads/main.png', 800, 600, 0);
	fp_id := (v_result->>'id')::int;
	assert fp_id = 1, 'id should be 1';

	-- get_floorplans returns created floorplan
	v_result := get_floorplans();
	assert v_result->0->>'name' = 'Main Floor', 'name should match';
	assert v_result->0->>'imagePath' = '/uploads/main.png', 'imagePath should match';
	assert (v_result->0->>'imageWidth')::int = 800, 'imageWidth should match';
	assert (v_result->0->>'imageHeight')::int = 600, 'imageHeight should match';

	-- save_floorplan respects sort_order
	perform save_floorplan('Patio', '/uploads/patio.png', 400, 300, 1);
	perform save_floorplan('Rooftop', '/uploads/rooftop.png', 600, 400, 2);
	v_result := get_floorplans();
	assert jsonb_array_length(v_result) = 3, 'should have 3 floorplans';

	-- Check ordering
	assert v_result->0->>'name' = 'Main Floor', 'first should be Main Floor';

	-- update_floorplan updates name
	perform update_floorplan(fp_id, 'Ground Floor', null);
	v_result := get_floorplans();
	assert v_result->0->>'name' = 'Ground Floor', 'name should be updated';

	-- delete_floorplan removes floorplan
	perform delete_floorplan(fp_id);
	v_result := get_floorplans();
	assert jsonb_array_length(v_result) = 2, 'should have 2 floorplans after delete';

	raise notice 'All floorplan tests passed!';
end;
$$;

rollback;
