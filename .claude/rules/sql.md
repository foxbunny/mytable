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
create function foo(p_bar text) returns jsonb as $$
	select jsonb_build_object('bar', p_bar);
$$ language sql;
```

When changing a function's signature, drop all old signatures first:

```sql
-- Old signature
drop function if exists create_thing(text, int);
-- New signature
drop function if exists create_thing(text, int, boolean);
create function create_thing(p_name text, p_size int, p_active boolean default true) returns jsonb as $$
	...
$$ language sql;
```

## Return types

**All functions return `jsonb`.** No custom types, no scalar returns.

- **Single objects**: Use `jsonb_build_object()`
- **Lists**: Use `jsonb_agg()` with `coalesce(..., '[]'::jsonb)` for empty arrays
- **Nested structures**: Build with `jsonb_build_object()` containing `jsonb_agg()` subqueries

**Exception:** Functions with the `@login` directive must use `returns table(...)` because NpgsqlRest requires named columns for session handling.

```sql
-- Single object (mutation, status check, lookup)
create function get_restaurant() returns jsonb as $$
	select jsonb_build_object(
		'name', name,
		'address', address,
		'phone', phone
	)
	from restaurant
	where id = 1;
$$ language sql;

-- List
create function get_floorplans() returns jsonb as $$
	select coalesce(jsonb_agg(jsonb_build_object(
		'id', id,
		'name', name,
		'imagePath', image_path
	) order by sort_order, id), '[]')
	from floorplan;
$$ language sql;

-- Nested structure
create function get_table_status_for_date(p_date date) returns jsonb as $$
	with table_reservations as (
		select floorplan_table_id, jsonb_agg(jsonb_build_object(
			'id', r.id,
			'guestName', r.guest_name
		)) as reservations
		from reservation r
		join reservation_table rt on r.id = rt.reservation_id
		where r.reservation_date = p_date
		group by floorplan_table_id
	)
	select coalesce(jsonb_agg(jsonb_build_object(
		'id', ft.id,
		'name', ft.name,
		'reservations', coalesce(tr.reservations, '[]')
	)), '[]')
	from floorplan_table ft
	left join table_reservations tr on ft.id = tr.floorplan_table_id;
$$ language sql;

-- Empty result (mutation confirmation)
create function delete_thing(p_id int) returns jsonb as $$
	delete from thing where id = p_id
	returning '{}'::jsonb;
$$ language sql;

-- Login function (exception: must use returns table for @login)
create function admin_login(p_username text, p_password text)
returns table(user_id int, user_name text) as $$
	select id, username
	from admin_users
	where username = p_username
		and password_hash = crypt(p_password, password_hash);
$$ language sql;
-- Returns empty result set if credentials don't match
```

## JSON key naming

Use camelCase for JSON keys to match JavaScript conventions:

```sql
jsonb_build_object(
	'id', id,
	'guestName', guest_name,      -- not 'guest_name'
	'reservationDate', reservation_date
)
```

## SQL vs PL/PgSQL

Prefer SQL and CTEs over PL/PgSQL.
