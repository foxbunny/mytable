-- Check if restaurant is configured
drop function if exists is_restaurant_configured();
create function is_restaurant_configured() returns restaurant_configured_result as $$
	select exists(select 1 from restaurant where id = 1);
$$ language sql;

comment on function is_restaurant_configured() is 'HTTP GET
Check if restaurant settings have been configured';

-- Get restaurant info
drop function if exists get_restaurant();
create function get_restaurant() returns restaurant_info as $$
	select row(name, address, phone, working_hours)::restaurant_info
	from restaurant
	where id = 1;
$$ language sql;

comment on function get_restaurant() is 'HTTP GET
Get restaurant settings';

-- Save restaurant (upsert)
drop function if exists save_restaurant(text, text, text, jsonb);
create function save_restaurant(
	p_name text,
	p_address text default null,
	p_phone text default null,
	p_working_hours jsonb default '{}'
) returns void as $$
begin
	-- Validate that at least one table exists across all floorplans
	if not exists(select 1 from floorplan_table) then
		raise exception 'NO_TABLES: Please add at least one table to a floor plan before completing setup';
	end if;

	insert into restaurant (id, name, address, phone, working_hours)
	values (1, p_name, p_address, p_phone, p_working_hours)
	on conflict (id) do update set
		name = excluded.name,
		address = excluded.address,
		phone = excluded.phone,
		working_hours = excluded.working_hours;
end;
$$ language plpgsql;

comment on function save_restaurant(text, text, text, jsonb) is 'HTTP POST
@authorize
Save restaurant settings';

-- Tests (wrapped in transaction, always rolled back)
begin;

do $$
declare
	v_configured boolean;
	v_info restaurant_info;
	v_floorplan_id int;
begin
	truncate restaurant cascade;
	truncate floorplan cascade;

	-- is_restaurant_configured returns false when no restaurant
	select configured into v_configured from is_restaurant_configured();
	assert v_configured = false, 'configured should be false when no restaurant exists';

	-- get_restaurant returns null when no restaurant
	v_info := get_restaurant();
	assert v_info is null, 'get_restaurant should return null when no restaurant exists';

	-- save_restaurant fails without tables
	begin
		perform save_restaurant('Test Restaurant', '123 Main St', '555-1234', '{}');
		raise exception 'save_restaurant should have failed without tables';
	exception when others then
		assert sqlerrm like 'NO_TABLES:%', 'should raise NO_TABLES error';
	end;

	-- Create a floorplan and table for subsequent tests
	insert into floorplan (name, image_path, image_width, image_height)
	values ('Main Floor', '/uploads/floor.png', 800, 600)
	returning id into v_floorplan_id;

	insert into floorplan_table (floorplan_id, name, capacity, x_pct, y_pct)
	values (v_floorplan_id, '1', 4, 0.5, 0.5);

	-- save_restaurant creates restaurant when tables exist
	perform save_restaurant('Test Restaurant', '123 Main St', '555-1234', '{"monday": {"open": "09:00", "close": "17:00"}}');
	select configured into v_configured from is_restaurant_configured();
	assert v_configured = true, 'configured should be true after save';

	-- get_restaurant returns saved data
	v_info := get_restaurant();
	assert v_info.name = 'Test Restaurant', 'name should match';
	assert v_info.address = '123 Main St', 'address should match';
	assert v_info.phone = '555-1234', 'phone should match';
	assert v_info.working_hours->'monday'->>'open' = '09:00', 'working hours should match';

	-- save_restaurant updates existing restaurant
	perform save_restaurant('Updated Restaurant', '456 Oak Ave', '555-5678', '{}');
	assert (select count(*) from restaurant) = 1, 'should still have only 1 restaurant';
	v_info := get_restaurant();
	assert v_info.name = 'Updated Restaurant', 'name should be updated';
	assert v_info.address = '456 Oak Ave', 'address should be updated';

	raise notice 'All restaurant tests passed!';
end;
$$;

rollback;
