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

## Example function formatting:

```sql
create or replace function foo(p_bar text) returns jsonb as $$
select ....
$$ language sql;
```

```sql
create or replace function bar(p_id int) returns text as $$
declare
	v_name text;
begin
	select name into v_name from users where id = p_id;
	return v_name;
end;
$$ language plpgsql;
```

## Return types

Use `returns table(...)` for functions that return **multiple rows** or **zero-or-more rows** (i.e., read operations where the result is a list or may be empty):

```sql
-- Multiple rows: list of items
create or replace function get_floorplan_tables(p_floorplan_id int)
returns table(id int, name text, x_pct numeric, y_pct numeric) as $$ ...

-- Zero-or-one rows: lookup that may fail (e.g., invalid credentials)
create or replace function admin_login(p_name text, p_password text)
returns table(user_id int, user_name text) as $$ ...
```

Use `returns jsonb` for functions that return a **single object** — mutations, status checks, confirmations, and summary values:

```sql
-- Mutation returning confirmation
create or replace function save_restaurant(p_name text, ...) returns jsonb as $$
	... returning jsonb_build_object('id', id);

-- Status check
create or replace function is_setup() returns jsonb as $$
	select jsonb_build_object('setup', exists(...));

-- Delete confirmation
create or replace function delete_floorplan_table(p_id int) returns jsonb as $$
	delete from ... returning jsonb_build_object('id', id);
```

The distinction matters because NpgsqlRest serializes `table(...)` as a JSON array and `jsonb` as a plain object. JavaScript consumes them differently: arrays are iterated/mapped, objects are accessed directly.

## SQL vs PL/PgSQL

Prefer SQL and CTEs over PL/PgSQL.
