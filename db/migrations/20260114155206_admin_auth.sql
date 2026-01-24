-- migrate:up
create extension if not exists pgcrypto;

create table admin_users (
    id serial primary key,
    username text not null unique,
    password_hash text not null,
    created_at timestamptz not null default now()
);

-- migrate:down
drop table if exists admin_users;
