-- migrate:up

create table reservation (
	id serial primary key,
	guest_name text not null,
	guest_phone text,
	guest_email text,
	party_size int not null check (party_size >= 1),
	reservation_date date not null,
	reservation_time time not null,
	duration_minutes int not null default 90,
	floorplan_table_id int references floorplan_table(id) on delete set null,
	status text not null default 'pending'
		check (status in ('pending', 'confirmed', 'declined', 'completed', 'no_show', 'cancelled')),
	source text not null default 'online'
		check (source in ('online', 'phone', 'walk_in')),
	notes text,
	created_at timestamptz not null default now(),
	updated_at timestamptz not null default now()
);

create index reservation_date_idx on reservation(reservation_date);
create index reservation_status_idx on reservation(status);
create index reservation_date_status_idx on reservation(reservation_date, status);

create table table_block (
	id serial primary key,
	floorplan_table_id int not null references floorplan_table(id) on delete cascade,
	blocked_at timestamptz not null default now(),
	notes text,
	constraint one_active_block_per_table unique (floorplan_table_id)
);

create trigger reservation_updated_at
	before update on reservation
	for each row execute function update_restaurant_timestamp();

-- migrate:down
drop trigger if exists reservation_updated_at on reservation;
drop table if exists table_block;
drop table if exists reservation;
