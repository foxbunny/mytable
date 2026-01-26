# SQL rules

This document outlines rules about SQL.

## Indentation

**ALWAYS use tabs for indentation. Never use spaces.**

## Formatting

Use lower-case keywords for everything. Use snake_case for names.

## Naming conventions

- **Parameters**: Use `p_` prefix (e.g., `p_name`, `p_user_id`)
- **Local variables**: Use `v_` prefix (e.g., `v_result`, `v_count`)

This avoids ambiguity between parameters, local variables, and column names.

## Function creation

Always use `drop function if exists` followed by `create function`. Never use `create or replace function` — it cannot change function signatures and leads to ghost overloads.

```sql
drop function if exists foo(text);
create function foo(p_bar text) returns my_result as $$
	select row(p_bar)::my_result;
$$ language sql;
```

When changing a function's signature, drop all old signatures first:

```sql
-- Old signature
drop function if exists create_thing(text, int);
-- New signature
drop function if exists create_thing(text, int, boolean);
create function create_thing(p_name text, p_size int, p_active boolean default true) returns thing_result as $$
	...
$$ language sql;
```

## Return types

**All functions return custom composite types.** Define types in migrations, then use them in functions.

- **Single objects**: Return a composite type directly
- **Lists**: Use `setof type` to return a set of rows
- **Mutations with no data**: Return `void`
- **Errors**: Use `raise exception` for error conditions

**Exceptions:**
- `@login` functions must use `returns table(...)` for NpgsqlRest session handling
- `@logout` functions return `text` for NpgsqlRest cookie handling
- File upload handlers return `json` for NpgsqlRest file metadata
- **Simple boolean returns**: Use `returns table(column boolean)` instead of a composite type (see below)

```sql
-- Type definitions (in migrations)
create type restaurant_info as (
	name text,
	address text,
	phone text,
	working_hours jsonb
);

create type floorplan_info as (
	id int,
	name text,
	image_path text,
	image_width int,
	image_height int,
	sort_order int
);

-- Single object
create function get_restaurant() returns restaurant_info as $$
	select row(name, address, phone, working_hours)::restaurant_info
	from restaurant
	where id = 1;
$$ language sql;

-- List (setof)
create function get_floorplans() returns setof floorplan_info as $$
	select id, name, image_path, image_width, image_height, sort_order
	from floorplan
	order by sort_order, id;
$$ language sql;

-- Mutation returning void
create function save_restaurant(p_name text, p_address text) returns void as $$
	insert into restaurant (id, name, address)
	values (1, p_name, p_address)
	on conflict (id) do update set
		name = excluded.name,
		address = excluded.address;
$$ language sql;

-- Error handling with exceptions
create function setup_admin(p_username text, p_password text) returns void as $$
begin
	if exists(select 1 from admin_users) then
		raise exception 'ALREADY_SETUP: System is already set up';
	end if;
	insert into admin_users (username, password_hash)
	values (p_username, crypt(p_password, gen_salt('bf')));
end;
$$ language plpgsql;

-- Login function (exception: must use returns table for @login)
create function admin_login(p_username text, p_password text)
returns table(user_id int, user_name text) as $$
	select id, username
	from admin_users
	where username = p_username
		and password_hash = crypt(p_password, password_hash);
$$ language sql;
```

## Boolean fields in composite types

**NpgsqlRest does not correctly serialize boolean values when using `row()` constructor with composite types.** It returns `(t)` or `(f)` instead of `true` or `false`.

This fails:
```sql
create type check_result as (ok boolean);

create function is_ready() returns check_result as $$
	select row(true)::check_result;  -- Returns {"ok":"(t)"} - WRONG
$$ language sql;
```

**Workaround:** For functions returning a single boolean (or simple boolean checks), use `returns table()` instead:

```sql
create function is_ready() returns table(ok boolean) as $$
	select true;  -- Returns {"ok":true} - CORRECT
$$ language sql;

create function is_setup() returns table(setup boolean) as $$
	select exists(select 1 from admin_users);
$$ language sql;
```

**Note:** Boolean fields work correctly in composite types when returned via `setof` from a multi-column SELECT:

```sql
create type table_info as (id int, name text, is_blocked boolean);

create function get_tables() returns setof table_info as $$
	select id, name, blocked  -- booleans serialize correctly here
	from tables;
$$ language sql;
```

## Nested data with jsonb

When a composite type needs to contain nested arrays or complex structures (like a list of reservations per table), use `jsonb` for that field:

```sql
create type table_status_info as (
	id int,
	name text,
	reservations jsonb  -- nested array of reservation objects
);

create function get_table_status() returns setof table_status_info as $$
	with table_reservations as (
		select floorplan_table_id, jsonb_agg(jsonb_build_object(
			'id', r.id,
			'guestName', r.guest_name
		)) as reservations
		from reservation r
		group by floorplan_table_id
	)
	select
		ft.id,
		ft.name,
		coalesce(tr.reservations, '[]')
	from floorplan_table ft
	left join table_reservations tr on ft.id = tr.floorplan_table_id;
$$ language sql;
```

## SQL vs PL/PgSQL

Prefer SQL and CTEs over PL/PgSQL.
