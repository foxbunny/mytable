-- Check if system is set up (has at least one admin)
drop function if exists is_setup();
create function is_setup() returns setup_result as $$
	select exists(select 1 from admin_users);
$$ language sql;

comment on function is_setup() is 'HTTP GET
Check if the system has been set up with an admin account';

-- Setup first admin account (only works when no admins exist)
drop function if exists setup_admin(text, text);
create function setup_admin(
	p_username text,
	p_password text
) returns void as $$
begin
	if exists(select 1 from admin_users) then
		raise exception 'ALREADY_SETUP: System is already set up';
	end if;

	insert into admin_users (username, password_hash)
	values (p_username, crypt(p_password, gen_salt('bf')));
end;
$$ language plpgsql;

comment on function setup_admin(text, text) is 'HTTP POST
Set up the initial admin account. Only works if no admin exists.';

-- Admin login (returns row on success, empty on failure)
-- NOTE: @login functions must use returns table() for NpgsqlRest session handling
drop function if exists admin_login(text, text);
create function admin_login(
	p_username text,
	p_password text
) returns table(user_id int, user_name text) as $$
	select a.id, a.username
	from admin_users a
	where a.username = p_username
		and a.password_hash = crypt(p_password, a.password_hash);
$$ language sql;

comment on function admin_login(text, text) is 'HTTP POST
@login
Authenticate admin user';

-- Check if current session is authenticated
drop function if exists is_authenticated();
create function is_authenticated() returns auth_result as $$
	select true;
$$ language sql;

comment on function is_authenticated() is 'HTTP GET
@authorize
Returns authenticated status if session is valid, 401 if not';

-- Admin logout
drop function if exists admin_logout();
create function admin_logout() returns text as $$
	select 'Cookies'::text;
$$ language sql;

comment on function admin_logout() is 'HTTP POST
@logout
@authorize
Sign out the current admin session';

-- Tests (wrapped in transaction, always rolled back)
begin;

do $$
declare
	v_setup boolean;
	v_auth boolean;
	v_login record;
begin
	truncate admin_users restart identity cascade;

	-- is_setup returns false when no admin
	select setup into v_setup from is_setup();
	assert v_setup = false, 'setup should be false when no admin exists';

	-- is_setup returns true when admin exists
	insert into admin_users (username, password_hash) values ('admin', 'hash');
	select setup into v_setup from is_setup();
	assert v_setup = true, 'setup should be true when admin exists';

	-- setup_admin creates first admin
	truncate admin_users restart identity cascade;
	perform setup_admin('testadmin', 'testpass');
	assert (select count(*) from admin_users) = 1, 'should have 1 admin';
	assert (select username from admin_users limit 1) = 'testadmin', 'username should match';
	assert (select password_hash from admin_users limit 1) like '$2a$%', 'password should be bcrypt hashed';

	-- setup_admin raises error when admin exists
	begin
		perform setup_admin('hacker', 'evil');
		assert false, 'should have raised exception';
	exception when others then
		assert sqlerrm like 'ALREADY_SETUP:%', 'should raise ALREADY_SETUP error';
	end;
	assert (select count(*) from admin_users) = 1, 'should still have only 1 admin';

	-- admin_login succeeds with correct credentials
	truncate admin_users restart identity cascade;
	perform setup_admin('admin', 'secret123');
	select * into v_login from admin_login('admin', 'secret123');
	assert v_login.user_id = 1, 'user_id should be 1';
	assert v_login.user_name = 'admin', 'user_name should match';

	-- admin_login returns no rows with wrong password
	assert not exists(select 1 from admin_login('admin', 'wrongpass')), 'should return no rows for wrong password';

	-- admin_login returns no rows with non-existent user
	assert not exists(select 1 from admin_login('nonexistent', 'anypass')), 'should return no rows for non-existent user';

	-- is_authenticated returns true
	select authenticated into v_auth from is_authenticated();
	assert v_auth = true, 'should return authenticated: true';

	raise notice 'All admin tests passed!';
end;
$$;

rollback;
