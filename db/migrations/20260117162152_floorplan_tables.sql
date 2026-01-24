-- migrate:up
create table floorplan_table (
	id serial primary key,
	floorplan_id int not null references floorplan(id) on delete cascade,
	name text not null,
	capacity int not null default 2,
	notes text,
	x_pct numeric(5,4) not null check (x_pct >= 0 and x_pct <= 1),
	y_pct numeric(5,4) not null check (y_pct >= 0 and y_pct <= 1),
	created_at timestamptz not null default now()
);

create index floorplan_table_floorplan_id_idx on floorplan_table(floorplan_id);

-- migrate:down
drop table if exists floorplan_table;
