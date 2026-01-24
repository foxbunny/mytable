-- migrate:up
create table restaurant (
	id int primary key default 1 check (id = 1),
	name text not null,
	address text,
	phone text,
	working_hours jsonb not null default '{}',
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now()
);

create table floorplan (
	id serial primary key,
	name text not null,
	image_path text not null,
	image_width int not null,
	image_height int not null,
	sort_order int not null default 0,
	created_at timestamptz not null default now()
);

create or replace function update_restaurant_timestamp()
returns trigger as $$
begin
	new.updated_at = now();
	return new;
end;
$$ language plpgsql;

create trigger restaurant_updated_at
	before update on restaurant
	for each row
	execute function update_restaurant_timestamp();

-- migrate:down
drop table if exists floorplan;
drop trigger if exists restaurant_updated_at on restaurant;
drop function if exists update_restaurant_timestamp();
drop table if exists restaurant;
