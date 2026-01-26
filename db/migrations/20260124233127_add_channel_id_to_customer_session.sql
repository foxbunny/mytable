-- migrate:up
alter table customer_session add column channel_id text;

-- migrate:down
alter table customer_session drop column channel_id;
