-- migrate:up

-- Echo
create type echo_result as (
	message text
);

-- Restaurant
create type restaurant_configured_result as (
	configured boolean
);

create type restaurant_info as (
	name text,
	address text,
	phone text,
	working_hours jsonb
);

-- Floorplan
create type floorplan_info as (
	id int,
	name text,
	image_path text,
	image_width int,
	image_height int,
	sort_order int
);

create type floorplan_save_result as (
	id int
);

create type floorplan_upload_result as (
	path text
);

-- Floorplan table
create type floorplan_table_info as (
	id int,
	floorplan_id int,
	name text,
	capacity int,
	notes text,
	x_pct numeric,
	y_pct numeric
);

create type floorplan_table_result as (
	id int,
	name text,
	capacity int,
	notes text,
	x_pct numeric,
	y_pct numeric
);

create type floorplan_table_delete_result as (
	id int
);

-- Reservation (list item with table info)
create type reservation_info as (
	id int,
	guest_name text,
	guest_phone text,
	guest_email text,
	party_size int,
	reservation_date date,
	reservation_time time,
	duration_minutes int,
	table_ids jsonb,
	table_names jsonb,
	status text,
	source text,
	notes text,
	created_at timestamptz
);

-- Pending reservation (queue item)
create type pending_reservation_info as (
	id int,
	guest_name text,
	guest_phone text,
	guest_email text,
	party_size int,
	reservation_date date,
	reservation_time time,
	duration_minutes int,
	table_ids jsonb,
	table_names jsonb,
	notes text,
	created_at timestamptz
);

create type pending_count_result as (
	count int
);

create type reservation_create_result as (
	id int,
	status text
);

create type reservation_update_result as (
	id int,
	status text
);

create type reservation_id_result as (
	id int
);

-- Table block
create type table_block_info as (
	id int,
	table_id int,
	table_name text,
	floorplan_id int,
	capacity int,
	blocked_at timestamptz,
	block_ends_at timestamptz,
	notes text
);

create type table_block_result as (
	id int
);

-- Table status (for date view, includes reservations)
create type table_reservation_info as (
	id int,
	guest_name text,
	party_size int,
	reservation_time time,
	duration_minutes int,
	status text
);

create type table_status_info as (
	id int,
	floorplan_id int,
	name text,
	capacity int,
	x_pct numeric,
	y_pct numeric,
	is_blocked boolean,
	block_notes text,
	block_ends_at timestamptz,
	reservations jsonb
);

-- Table availability (available tables for slot)
create type table_availability_info as (
	id int,
	floorplan_id int,
	floorplan_name text,
	name text,
	capacity int
);

-- Table slot (all tables with availability flags)
create type table_slot_info as (
	id int,
	floorplan_id int,
	name text,
	capacity int,
	x_pct numeric,
	y_pct numeric,
	is_available boolean,
	is_blocked boolean,
	block_ends_at timestamptz,
	has_conflict boolean
);

-- Customer reservation
create type customer_reservation_result as (
	reservation_id int,
	session_token text
);

create type customer_notification_result as (
	code text,
	admin_message text,
	reservation_status text,
	reservation_date date,
	reservation_time time,
	party_size int,
	guest_name text
);

-- New pending (for admin polling)
create type new_pending_info as (
	id int,
	guest_name text,
	party_size int,
	reservation_date date,
	reservation_time time,
	created_at timestamptz
);

-- Admin
create type setup_result as (
	setup boolean
);

create type auth_result as (
	authenticated boolean
);

-- migrate:down

drop type if exists auth_result;
drop type if exists setup_result;
drop type if exists new_pending_info;
drop type if exists customer_notification_result;
drop type if exists customer_reservation_result;
drop type if exists table_slot_info;
drop type if exists table_availability_info;
drop type if exists table_status_info;
drop type if exists table_reservation_info;
drop type if exists table_block_result;
drop type if exists table_block_info;
drop type if exists reservation_id_result;
drop type if exists reservation_update_result;
drop type if exists reservation_create_result;
drop type if exists pending_count_result;
drop type if exists pending_reservation_info;
drop type if exists reservation_info;
drop type if exists floorplan_table_delete_result;
drop type if exists floorplan_table_result;
drop type if exists floorplan_table_info;
drop type if exists floorplan_upload_result;
drop type if exists floorplan_save_result;
drop type if exists floorplan_info;
drop type if exists restaurant_info;
drop type if exists restaurant_configured_result;
drop type if exists echo_result;
