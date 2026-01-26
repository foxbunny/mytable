-- Check if restaurant is configured
drop function if exists is_restaurant_configured();
create function is_restaurant_configured() returns jsonb as $$
	select jsonb_build_object('configured', exists(select 1 from restaurant where id = 1));
$$ language sql;

comment on function is_restaurant_configured() is 'HTTP GET
Check if restaurant settings have been configured';

-- Get restaurant info
drop function if exists get_restaurant();
create function get_restaurant() returns jsonb as $$
	select jsonb_build_object(
		'name', name,
		'address', address,
		'phone', phone,
		'workingHours', working_hours
	)
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
) returns jsonb as $$
	insert into restaurant (id, name, address, phone, working_hours)
	values (1, p_name, p_address, p_phone, p_working_hours)
	on conflict (id) do update set
		name = excluded.name,
		address = excluded.address,
		phone = excluded.phone,
		working_hours = excluded.working_hours
	returning '{}'::jsonb;
$$ language sql;

comment on function save_restaurant(text, text, text, jsonb) is 'HTTP POST
@authorize
Save restaurant settings';

-- Tests (wrapped in transaction, always rolled back)
begin;

do $$
declare
	v_result jsonb;
begin
	truncate restaurant cascade;

	-- is_restaurant_configured returns {configured: false} when no restaurant
	v_result := is_restaurant_configured();
	assert (v_result->>'configured')::boolean = false, 'configured should be false when no restaurant exists';

	-- get_restaurant returns null when no restaurant
	v_result := get_restaurant();
	assert v_result is null, 'get_restaurant should return null when no restaurant exists';

	-- save_restaurant creates restaurant
	perform save_restaurant('Test Restaurant', '123 Main St', '555-1234', '{"monday": {"open": "09:00", "close": "17:00"}}');
	v_result := is_restaurant_configured();
	assert (v_result->>'configured')::boolean = true, 'configured should be true after save';

	-- get_restaurant returns saved data
	v_result := get_restaurant();
	assert v_result->>'name' = 'Test Restaurant', 'name should match';
	assert v_result->>'address' = '123 Main St', 'address should match';
	assert v_result->>'phone' = '555-1234', 'phone should match';
	assert v_result->'workingHours'->'monday'->>'open' = '09:00', 'working hours should match';

	-- save_restaurant updates existing restaurant
	perform save_restaurant('Updated Restaurant', '456 Oak Ave', '555-5678', '{}');
	assert (select count(*) from restaurant) = 1, 'should still have only 1 restaurant';
	v_result := get_restaurant();
	assert v_result->>'name' = 'Updated Restaurant', 'name should be updated';
	assert v_result->>'address' = '456 Oak Ave', 'address should be updated';

	raise notice 'All restaurant tests passed!';
end;
$$;

rollback;
