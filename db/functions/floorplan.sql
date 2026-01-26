-- List all floorplans
drop function if exists get_floorplans();
create function get_floorplans() returns setof floorplan_info as $$
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
) returns floorplan_save_result as $$
	insert into floorplan (name, image_path, image_width, image_height, sort_order)
	values (p_name, p_image_path, p_image_width, p_image_height, p_sort_order)
	returning row(id)::floorplan_save_result;
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
) returns floorplan_save_result as $$
	update floorplan
	set name = p_name,
		sort_order = coalesce(p_sort_order, sort_order)
	where id = p_id
	returning row(id)::floorplan_save_result;
$$ language sql;

comment on function update_floorplan(int, text, int) is 'HTTP POST
@authorize
Update floorplan name or sort order';

-- Delete floorplan
drop function if exists delete_floorplan(int);
create function delete_floorplan(p_id int) returns floorplan_save_result as $$
	delete from floorplan where id = p_id
	returning row(id)::floorplan_save_result;
$$ language sql;

comment on function delete_floorplan(int) is 'HTTP POST
@authorize
Delete a floorplan';

-- Tests (wrapped in transaction, always rolled back)
begin;

do $$
declare
	v_result floorplan_save_result;
	v_info floorplan_info;
	v_list floorplan_info[];
	fp_id int;
begin
	truncate floorplan restart identity cascade;

	-- get_floorplans returns empty set when no floorplans
	select array_agg(f) into v_list from get_floorplans() f;
	assert v_list is null, 'get_floorplans should return empty set';

	-- save_floorplan creates floorplan and returns id
	v_result := save_floorplan('Main Floor', '/uploads/main.png', 800, 600, 0);
	fp_id := v_result.id;
	assert fp_id = 1, 'id should be 1';

	-- get_floorplans returns created floorplan
	select * into v_info from get_floorplans() limit 1;
	assert v_info.name = 'Main Floor', 'name should match';
	assert v_info.image_path = '/uploads/main.png', 'image_path should match';
	assert v_info.image_width = 800, 'image_width should match';
	assert v_info.image_height = 600, 'image_height should match';

	-- save_floorplan respects sort_order
	perform save_floorplan('Patio', '/uploads/patio.png', 400, 300, 1);
	perform save_floorplan('Rooftop', '/uploads/rooftop.png', 600, 400, 2);
	select array_agg(f) into v_list from get_floorplans() f;
	assert array_length(v_list, 1) = 3, 'should have 3 floorplans';

	-- Check ordering
	assert v_list[1].name = 'Main Floor', 'first should be Main Floor';

	-- update_floorplan updates name
	perform update_floorplan(fp_id, 'Ground Floor', null);
	select * into v_info from get_floorplans() where id = fp_id;
	assert v_info.name = 'Ground Floor', 'name should be updated';

	-- delete_floorplan removes floorplan
	perform delete_floorplan(fp_id);
	select array_agg(f) into v_list from get_floorplans() f;
	assert array_length(v_list, 1) = 2, 'should have 2 floorplans after delete';

	raise notice 'All floorplan tests passed!';
end;
$$;

rollback;
