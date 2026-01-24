-- migrate:up
create table customer_session (
	id serial primary key,
	token text not null unique default gen_random_uuid()::text,
	reservation_id int references reservation(id) on delete cascade,
	created_at timestamptz not null default now(),
	expires_at timestamptz not null default now() + interval '24 hours'
);

create index customer_session_token_idx on customer_session(token);
create index customer_session_reservation_idx on customer_session(reservation_id);

create table reservation_notification (
	id serial primary key,
	reservation_id int not null references reservation(id) on delete cascade,
	code text not null,
	admin_message text,
	delivered boolean not null default false,
	created_at timestamptz not null default now()
);

create index reservation_notification_reservation_idx on reservation_notification(reservation_id);

-- migrate:down
drop table if exists reservation_notification;
drop table if exists customer_session;
