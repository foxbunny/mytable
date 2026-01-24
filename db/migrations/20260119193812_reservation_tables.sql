-- migrate:up

create table reservation_table (
	reservation_id int not null references reservation(id) on delete cascade,
	floorplan_table_id int not null references floorplan_table(id) on delete cascade,
	primary key (reservation_id, floorplan_table_id)
);

create index reservation_table_table_idx on reservation_table(floorplan_table_id);

-- Migrate existing data
insert into reservation_table (reservation_id, floorplan_table_id)
select id, floorplan_table_id from reservation where floorplan_table_id is not null;

-- Drop old column
alter table reservation drop column floorplan_table_id;

-- migrate:down

alter table reservation add column floorplan_table_id int references floorplan_table(id) on delete set null;

-- Migrate data back (takes first table if multiple)
update reservation r
set floorplan_table_id = (
	select floorplan_table_id from reservation_table rt
	where rt.reservation_id = r.id
	limit 1
);

drop table reservation_table;
