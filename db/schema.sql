\restrict dbmate

-- Dumped from database version 18.1 (Ubuntu 18.1-1.pgdg24.04+2)
-- Dumped by pg_dump version 18.1 (Ubuntu 18.1-1.pgdg24.04+2)

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: pgcrypto; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;


--
-- Name: EXTENSION pgcrypto; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pgcrypto IS 'cryptographic functions';


--
-- Name: auth_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.auth_result AS (
	authenticated boolean
);


--
-- Name: customer_notification_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.customer_notification_result AS (
	code text,
	admin_message text,
	reservation_status text,
	reservation_date date,
	reservation_time time without time zone,
	party_size integer,
	guest_name text
);


--
-- Name: customer_reservation_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.customer_reservation_result AS (
	reservation_id integer,
	session_token text
);


--
-- Name: echo_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.echo_result AS (
	message text
);


--
-- Name: floorplan_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.floorplan_info AS (
	id integer,
	name text,
	image_path text,
	image_width integer,
	image_height integer,
	sort_order integer
);


--
-- Name: floorplan_save_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.floorplan_save_result AS (
	id integer
);


--
-- Name: floorplan_table_delete_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.floorplan_table_delete_result AS (
	id integer
);


--
-- Name: floorplan_table_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.floorplan_table_info AS (
	id integer,
	floorplan_id integer,
	name text,
	capacity integer,
	notes text,
	x_pct numeric,
	y_pct numeric
);


--
-- Name: floorplan_table_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.floorplan_table_result AS (
	id integer,
	name text,
	capacity integer,
	notes text,
	x_pct numeric,
	y_pct numeric
);


--
-- Name: floorplan_upload_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.floorplan_upload_result AS (
	path text
);


--
-- Name: new_pending_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.new_pending_info AS (
	id integer,
	guest_name text,
	party_size integer,
	reservation_date date,
	reservation_time time without time zone,
	created_at timestamp with time zone
);


--
-- Name: pending_count_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pending_count_result AS (
	count integer
);


--
-- Name: pending_reservation_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.pending_reservation_info AS (
	id integer,
	guest_name text,
	guest_phone text,
	guest_email text,
	party_size integer,
	reservation_date date,
	reservation_time time without time zone,
	duration_minutes integer,
	table_ids jsonb,
	table_names jsonb,
	notes text,
	created_at timestamp with time zone
);


--
-- Name: reservation_create_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.reservation_create_result AS (
	id integer,
	status text
);


--
-- Name: reservation_id_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.reservation_id_result AS (
	id integer
);


--
-- Name: reservation_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.reservation_info AS (
	id integer,
	guest_name text,
	guest_phone text,
	guest_email text,
	party_size integer,
	reservation_date date,
	reservation_time time without time zone,
	duration_minutes integer,
	table_ids jsonb,
	table_names jsonb,
	status text,
	source text,
	notes text,
	created_at timestamp with time zone
);


--
-- Name: reservation_update_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.reservation_update_result AS (
	id integer,
	status text
);


--
-- Name: restaurant_configured_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.restaurant_configured_result AS (
	configured boolean
);


--
-- Name: restaurant_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.restaurant_info AS (
	name text,
	address text,
	phone text,
	working_hours jsonb
);


--
-- Name: setup_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.setup_result AS (
	setup boolean
);


--
-- Name: table_availability_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.table_availability_info AS (
	id integer,
	floorplan_id integer,
	floorplan_name text,
	name text,
	capacity integer
);


--
-- Name: table_block_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.table_block_info AS (
	id integer,
	table_id integer,
	table_name text,
	floorplan_id integer,
	capacity integer,
	blocked_at timestamp with time zone,
	block_ends_at timestamp with time zone,
	notes text
);


--
-- Name: table_block_result; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.table_block_result AS (
	id integer
);


--
-- Name: table_reservation_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.table_reservation_info AS (
	id integer,
	guest_name text,
	party_size integer,
	reservation_time time without time zone,
	duration_minutes integer,
	status text
);


--
-- Name: table_slot_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.table_slot_info AS (
	id integer,
	floorplan_id integer,
	name text,
	capacity integer,
	x_pct numeric,
	y_pct numeric,
	is_available boolean,
	is_blocked boolean,
	block_ends_at timestamp with time zone,
	has_conflict boolean
);


--
-- Name: table_status_info; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public.table_status_info AS (
	id integer,
	floorplan_id integer,
	name text,
	capacity integer,
	x_pct numeric,
	y_pct numeric,
	is_blocked boolean,
	block_notes text,
	block_ends_at timestamp with time zone,
	reservations jsonb
);


--
-- Name: admin_login(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_login(p_username text, p_password text) RETURNS TABLE(user_id integer, user_name text)
    LANGUAGE sql
    AS $$
	select a.id, a.username
	from admin_users a
	where a.username = p_username
		and a.password_hash = crypt(p_password, a.password_hash);
$$;


--
-- Name: FUNCTION admin_login(p_username text, p_password text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.admin_login(p_username text, p_password text) IS 'HTTP POST
@login
@rate_limiter_policy auth
Authenticate admin user';


--
-- Name: admin_logout(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.admin_logout() RETURNS text
    LANGUAGE sql
    AS $$
	select 'Cookies'::text;
$$;


--
-- Name: FUNCTION admin_logout(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.admin_logout() IS 'HTTP POST
@logout
@authorize
Sign out the current admin session';


--
-- Name: assign_reservation_tables(integer, integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.assign_reservation_tables(p_reservation_id integer, p_table_ids integer[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	-- Clear existing assignments
	delete from reservation_table where reservation_id = p_reservation_id;

	-- Add new assignments
	if p_table_ids is not null and array_length(p_table_ids, 1) > 0 then
		insert into reservation_table (reservation_id, floorplan_table_id)
		select p_reservation_id, unnest(p_table_ids);
	end if;
end;
$$;


--
-- Name: FUNCTION assign_reservation_tables(p_reservation_id integer, p_table_ids integer[]); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.assign_reservation_tables(p_reservation_id integer, p_table_ids integer[]) IS 'HTTP POST
@authorize
Assign tables to a reservation (replaces existing assignments)';


--
-- Name: block_table(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.block_table(p_table_id integer, p_notes text DEFAULT NULL::text) RETURNS public.table_block_result
    LANGUAGE sql
    AS $$
	insert into table_block (floorplan_table_id, notes)
	values (p_table_id, p_notes)
	on conflict (floorplan_table_id) do update
		set blocked_at = now(), notes = excluded.notes
	returning row(id)::table_block_result;
$$;


--
-- Name: FUNCTION block_table(p_table_id integer, p_notes text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.block_table(p_table_id integer, p_notes text) IS 'HTTP POST
@authorize
Block a table for walk-ins or maintenance';


--
-- Name: check_reservation_not_in_past(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_reservation_not_in_past() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	if new.reservation_date + new.reservation_time < now() then
		raise exception 'PAST_RESERVATION: Cannot create or update reservation in the past';
	end if;
	return new;
end;
$$;


--
-- Name: check_table_availability(date, time without time zone, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.check_table_availability(p_date date, p_time time without time zone, p_duration integer, p_party_size integer) RETURNS SETOF public.table_availability_info
    LANGUAGE sql
    AS $$
	with slot_times as (
		select
			(p_date + p_time)::timestamptz as slot_start,
			(p_date + p_time + (p_duration || ' minutes')::interval)::timestamptz as slot_end
	),
	conflicting_reservations as (
		select distinct rt.floorplan_table_id
		from reservation r
		join reservation_table rt on r.id = rt.reservation_id
		cross join slot_times
		where r.reservation_date = p_date
			and r.status in ('pending', 'confirmed')
			-- Overlap check: start1 < end2 AND end1 > start2
			and r.reservation_time < slot_times.slot_end::time
			and (r.reservation_time + (r.duration_minutes || ' minutes')::interval) > p_time
	),
	blocked_tables as (
		select b.floorplan_table_id
		from table_block b
		join floorplan_table ft on b.floorplan_table_id = ft.id
		cross join slot_times
		-- Block overlaps with slot if: block_start < slot_end AND block_end > slot_start
		where b.blocked_at < slot_times.slot_end
			and b.blocked_at + make_interval(mins => 30 + 30 * ft.capacity) > slot_times.slot_start
	)
	select
		ft.id,
		ft.floorplan_id,
		f.name,
		ft.name,
		ft.capacity
	from floorplan_table ft
	join floorplan f on ft.floorplan_id = f.id
	where ft.capacity >= p_party_size
		and ft.id not in (select floorplan_table_id from blocked_tables)
		and ft.id not in (select floorplan_table_id from conflicting_reservations)
	order by f.sort_order, f.id, ft.name;
$$;


--
-- Name: FUNCTION check_table_availability(p_date date, p_time time without time zone, p_duration integer, p_party_size integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.check_table_availability(p_date date, p_time time without time zone, p_duration integer, p_party_size integer) IS 'HTTP GET
Get available tables for a specific time slot and party size';


--
-- Name: cleanup_expired_blocks(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.cleanup_expired_blocks() RETURNS public.pending_count_result
    LANGUAGE sql
    AS $$
	with deleted as (
		delete from table_block b
		using floorplan_table t
		where b.floorplan_table_id = t.id
			and b.blocked_at + make_interval(mins => 30 + 30 * t.capacity) < now()
		returning b.id
	)
	select row(count(*)::int)::pending_count_result from deleted;
$$;


--
-- Name: FUNCTION cleanup_expired_blocks(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.cleanup_expired_blocks() IS 'HTTP POST
@authorize
Remove expired table blocks';


--
-- Name: create_reservation(text, integer, date, time without time zone, text, text, integer, integer[], text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.create_reservation(p_guest_name text, p_party_size integer, p_reservation_date date, p_reservation_time time without time zone, p_guest_phone text DEFAULT NULL::text, p_guest_email text DEFAULT NULL::text, p_duration_minutes integer DEFAULT 90, p_table_ids integer[] DEFAULT NULL::integer[], p_source text DEFAULT 'online'::text, p_notes text DEFAULT NULL::text) RETURNS public.reservation_create_result
    LANGUAGE plpgsql
    AS $$
declare
	v_status text;
	v_id int;
begin
	-- Phone and walk-in reservations are auto-confirmed
	v_status := case when p_source in ('phone', 'walk_in') then 'confirmed' else 'pending' end;

	insert into reservation (
		guest_name, guest_phone, guest_email, party_size,
		reservation_date, reservation_time, duration_minutes,
		source, status, notes
	)
	values (
		p_guest_name, p_guest_phone, p_guest_email, p_party_size,
		p_reservation_date, p_reservation_time, p_duration_minutes,
		p_source, v_status, p_notes
	)
	returning id into v_id;

	-- Assign tables if provided
	if p_table_ids is not null and array_length(p_table_ids, 1) > 0 then
		insert into reservation_table (reservation_id, floorplan_table_id)
		select v_id, unnest(p_table_ids);
	end if;

	return row(v_id, v_status)::reservation_create_result;
end;
$$;


--
-- Name: FUNCTION create_reservation(p_guest_name text, p_party_size integer, p_reservation_date date, p_reservation_time time without time zone, p_guest_phone text, p_guest_email text, p_duration_minutes integer, p_table_ids integer[], p_source text, p_notes text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.create_reservation(p_guest_name text, p_party_size integer, p_reservation_date date, p_reservation_time time without time zone, p_guest_phone text, p_guest_email text, p_duration_minutes integer, p_table_ids integer[], p_source text, p_notes text) IS 'HTTP POST
@authorize
Create a new reservation';


--
-- Name: customer_create_reservation(text, integer, date, time without time zone, text, text, text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.customer_create_reservation(p_guest_name text, p_party_size integer, p_reservation_date date, p_reservation_time time without time zone, p_guest_phone text DEFAULT NULL::text, p_guest_email text DEFAULT NULL::text, p_notes text DEFAULT NULL::text, p_channel_id text DEFAULT NULL::text) RETURNS public.customer_reservation_result
    LANGUAGE plpgsql
    AS $$
declare
	v_reservation_id int;
	v_token text;
begin
	-- Create reservation with pending status
	insert into reservation (
		guest_name, guest_phone, guest_email, party_size,
		reservation_date, reservation_time, duration_minutes,
		source, status, notes
	)
	values (
		p_guest_name, p_guest_phone, p_guest_email, p_party_size,
		p_reservation_date, p_reservation_time, 90,
		'online', 'pending', p_notes
	)
	returning id into v_reservation_id;

	-- Create customer session with token
	insert into customer_session (reservation_id, channel_id)
	values (v_reservation_id, p_channel_id)
	returning token into v_token;

	-- Broadcast to SSE clients
	raise info '%', jsonb_build_object(
		'code', 'new_pending',
		'reservationId', v_reservation_id,
		'guestName', p_guest_name,
		'partySize', p_party_size,
		'reservationDate', p_reservation_date,
		'reservationTime', p_reservation_time
	);

	return row(v_reservation_id, v_token)::customer_reservation_result;
end;
$$;


--
-- Name: FUNCTION customer_create_reservation(p_guest_name text, p_party_size integer, p_reservation_date date, p_reservation_time time without time zone, p_guest_phone text, p_guest_email text, p_notes text, p_channel_id text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.customer_create_reservation(p_guest_name text, p_party_size integer, p_reservation_date date, p_reservation_time time without time zone, p_guest_phone text, p_guest_email text, p_notes text, p_channel_id text) IS 'HTTP POST
@sse
Create a new reservation from customer portal';


--
-- Name: delete_floorplan(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_floorplan(p_id integer) RETURNS public.floorplan_save_result
    LANGUAGE sql
    AS $$
	delete from floorplan where id = p_id
	returning id;
$$;


--
-- Name: FUNCTION delete_floorplan(p_id integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.delete_floorplan(p_id integer) IS 'HTTP POST
@authorize
Delete a floorplan';


--
-- Name: delete_floorplan_table(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.delete_floorplan_table(p_id integer) RETURNS public.floorplan_table_delete_result
    LANGUAGE sql
    AS $$
	delete from floorplan_table where id = p_id
	returning id;
$$;


--
-- Name: FUNCTION delete_floorplan_table(p_id integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.delete_floorplan_table(p_id integer) IS 'HTTP POST
@authorize
Delete a floorplan table';


--
-- Name: echo(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.echo(p_message text) RETURNS public.echo_result
    LANGUAGE sql
    AS $$
select row(p_message)::echo_result;
$$;


--
-- Name: FUNCTION echo(p_message text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.echo(p_message text) IS 'HTTP
Echoes the input message back';


--
-- Name: get_blocked_tables(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_blocked_tables() RETURNS SETOF public.table_block_info
    LANGUAGE sql
    AS $$
	select
		b.id,
		b.floorplan_table_id,
		t.name,
		t.floorplan_id,
		t.capacity,
		b.blocked_at,
		b.blocked_at + make_interval(mins => 30 + 30 * t.capacity),
		b.notes
	from table_block b
	join floorplan_table t on b.floorplan_table_id = t.id
	order by b.blocked_at desc;
$$;


--
-- Name: FUNCTION get_blocked_tables(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_blocked_tables() IS 'HTTP GET
Get all currently blocked tables with their expiry times';


--
-- Name: get_customer_notification(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_customer_notification(p_token text) RETURNS public.customer_notification_result
    LANGUAGE plpgsql
    AS $$
declare
	v_session record;
	v_reservation record;
	v_notification record;
begin
	-- Get session
	select cs.* into v_session
	from customer_session cs
	where cs.token = p_token and cs.expires_at > now();

	if v_session is null then
		return null;
	end if;

	-- Get reservation details
	select r.* into v_reservation
	from reservation r
	where r.id = v_session.reservation_id;

	-- Check for undelivered notification
	select rn.* into v_notification
	from reservation_notification rn
	where rn.reservation_id = v_session.reservation_id
		and not rn.delivered
	order by rn.created_at desc
	limit 1;

	if v_notification is not null then
		return row(
			v_notification.code,
			v_notification.admin_message,
			v_reservation.status,
			v_reservation.reservation_date,
			v_reservation.reservation_time,
			v_reservation.party_size,
			v_reservation.guest_name
		)::customer_notification_result;
	else
		-- Return current status without notification code
		return row(
			null,
			null,
			v_reservation.status,
			v_reservation.reservation_date,
			v_reservation.reservation_time,
			v_reservation.party_size,
			v_reservation.guest_name
		)::customer_notification_result;
	end if;
end;
$$;


--
-- Name: FUNCTION get_customer_notification(p_token text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_customer_notification(p_token text) IS 'HTTP GET
Get notification status for customer reservation';


--
-- Name: get_floorplan_tables(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_floorplan_tables(p_floorplan_id integer) RETURNS SETOF public.floorplan_table_info
    LANGUAGE sql
    AS $$
	select id, floorplan_id, name, capacity, notes, x_pct, y_pct
	from floorplan_table
	where floorplan_id = p_floorplan_id
	order by created_at, id;
$$;


--
-- Name: FUNCTION get_floorplan_tables(p_floorplan_id integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_floorplan_tables(p_floorplan_id integer) IS 'HTTP GET
Get all tables for a floorplan';


--
-- Name: get_floorplans(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_floorplans() RETURNS SETOF public.floorplan_info
    LANGUAGE sql
    AS $$
	select id, name, image_path, image_width, image_height, sort_order
	from floorplan
	order by sort_order, id;
$$;


--
-- Name: FUNCTION get_floorplans(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_floorplans() IS 'HTTP GET
Get all floorplans';


--
-- Name: get_new_pending_reservations(timestamp with time zone); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_new_pending_reservations(p_since timestamp with time zone DEFAULT NULL::timestamp with time zone) RETURNS SETOF public.new_pending_info
    LANGUAGE sql
    AS $$
	select
		r.id,
		r.guest_name,
		r.party_size,
		r.reservation_date,
		r.reservation_time,
		r.created_at
	from reservation r
	where r.status = 'pending'
		and r.source = 'online'
		and (p_since is null or r.created_at > p_since)
	order by r.created_at desc;
$$;


--
-- Name: FUNCTION get_new_pending_reservations(p_since timestamp with time zone); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_new_pending_reservations(p_since timestamp with time zone) IS 'HTTP GET
@authorize
Get pending online reservations, optionally since a given timestamp';


--
-- Name: get_pending_count(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_pending_count() RETURNS public.pending_count_result
    LANGUAGE sql
    AS $$
	select row(count(*)::int)::pending_count_result
	from reservation
	where status = 'pending';
$$;


--
-- Name: FUNCTION get_pending_count(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_pending_count() IS 'HTTP GET
Get count of pending reservations';


--
-- Name: get_pending_dates(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_pending_dates() RETURNS SETOF date
    LANGUAGE sql
    AS $$
	select distinct r.reservation_date
	from reservation r
	where r.status = 'pending'
	order by r.reservation_date;
$$;


--
-- Name: FUNCTION get_pending_dates(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_pending_dates() IS 'HTTP GET
Get dates with pending reservations for calendar markers';


--
-- Name: get_pending_reservations(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_pending_reservations() RETURNS SETOF public.pending_reservation_info
    LANGUAGE sql
    AS $$
	with reservation_tables as (
		select
			rt.reservation_id,
			jsonb_agg(rt.floorplan_table_id order by rt.floorplan_table_id) as table_ids,
			jsonb_agg(t.name order by rt.floorplan_table_id) as table_names
		from reservation_table rt
		join floorplan_table t on rt.floorplan_table_id = t.id
		group by rt.reservation_id
	)
	select
		r.id,
		r.guest_name,
		r.guest_phone,
		r.guest_email,
		r.party_size,
		r.reservation_date,
		r.reservation_time,
		r.duration_minutes,
		coalesce(rt.table_ids, '[]'),
		coalesce(rt.table_names, '[]'),
		r.notes,
		r.created_at
	from reservation r
	left join reservation_tables rt on r.id = rt.reservation_id
	where r.status = 'pending'
	order by r.reservation_date, r.reservation_time, r.created_at;
$$;


--
-- Name: FUNCTION get_pending_reservations(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_pending_reservations() IS 'HTTP GET
Get all pending reservations for the queue';


--
-- Name: get_reservations_for_date(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_reservations_for_date(p_date date) RETURNS SETOF public.reservation_info
    LANGUAGE sql
    AS $$
	with reservation_tables as (
		select
			rt.reservation_id,
			jsonb_agg(rt.floorplan_table_id order by rt.floorplan_table_id) as table_ids,
			jsonb_agg(t.name order by rt.floorplan_table_id) as table_names
		from reservation_table rt
		join floorplan_table t on rt.floorplan_table_id = t.id
		group by rt.reservation_id
	)
	select
		r.id,
		r.guest_name,
		r.guest_phone,
		r.guest_email,
		r.party_size,
		r.reservation_date,
		r.reservation_time,
		r.duration_minutes,
		coalesce(rt.table_ids, '[]'),
		coalesce(rt.table_names, '[]'),
		r.status,
		r.source,
		r.notes,
		r.created_at
	from reservation r
	left join reservation_tables rt on r.id = rt.reservation_id
	where r.reservation_date = p_date
		and r.status not in ('completed', 'no_show', 'cancelled', 'declined')
	order by r.reservation_time, r.created_at;
$$;


--
-- Name: FUNCTION get_reservations_for_date(p_date date); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_reservations_for_date(p_date date) IS 'HTTP GET
Get all reservations for a specific date';


--
-- Name: get_restaurant(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_restaurant() RETURNS public.restaurant_info
    LANGUAGE sql
    AS $$
	select row(name, address, phone, working_hours)::restaurant_info
	from restaurant
	where id = 1;
$$;


--
-- Name: FUNCTION get_restaurant(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_restaurant() IS 'HTTP GET
Get restaurant settings';


--
-- Name: get_table_status_for_date(date); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_table_status_for_date(p_date date) RETURNS SETOF public.table_status_info
    LANGUAGE sql
    AS $$
	with table_reservations as (
		select
			rt.floorplan_table_id,
			jsonb_agg(jsonb_build_object(
				'id', r.id,
				'guestName', r.guest_name,
				'partySize', r.party_size,
				'reservationTime', r.reservation_time,
				'durationMinutes', r.duration_minutes,
				'status', r.status
			) order by r.reservation_time) as reservations
		from reservation r
		join reservation_table rt on r.id = rt.reservation_id
		where r.reservation_date = p_date
			and r.status in ('pending', 'confirmed')
		group by rt.floorplan_table_id
	),
	active_blocks as (
		select
			b.id,
			b.floorplan_table_id,
			b.blocked_at,
			b.notes,
			b.blocked_at + make_interval(mins => 30 + 30 * ft.capacity) as block_ends_at
		from table_block b
		join floorplan_table ft on b.floorplan_table_id = ft.id
		where b.blocked_at < (p_date + 1)::timestamptz
			and b.blocked_at + make_interval(mins => 30 + 30 * ft.capacity) > p_date::timestamptz
	)
	select
		ft.id,
		ft.floorplan_id,
		ft.name,
		ft.capacity,
		ft.x_pct,
		ft.y_pct,
		ab.id is not null,
		ab.notes,
		ab.block_ends_at,
		coalesce(tr.reservations, '[]')
	from floorplan_table ft
	left join active_blocks ab on ft.id = ab.floorplan_table_id
	left join table_reservations tr on ft.id = tr.floorplan_table_id
	order by ft.floorplan_id, ft.name;
$$;


--
-- Name: FUNCTION get_table_status_for_date(p_date date); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_table_status_for_date(p_date date) IS 'HTTP GET
Get all tables with their reservation and block status for a date';


--
-- Name: get_tables_for_slot(date, time without time zone, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.get_tables_for_slot(p_date date, p_time time without time zone, p_duration integer, p_exclude_reservation_id integer DEFAULT NULL::integer) RETURNS SETOF public.table_slot_info
    LANGUAGE sql
    AS $$
	with slot_times as (
		select
			(p_date + p_time)::timestamptz as slot_start,
			(p_date + p_time + (p_duration || ' minutes')::interval)::timestamptz as slot_end
	),
	conflicting_reservations as (
		select distinct rt.floorplan_table_id
		from reservation r
		join reservation_table rt on r.id = rt.reservation_id
		cross join slot_times
		where r.reservation_date = p_date
			and r.status in ('pending', 'confirmed')
			and r.id is distinct from p_exclude_reservation_id
			-- Overlap check: start1 < end2 AND end1 > start2
			and r.reservation_time < slot_times.slot_end::time
			and (r.reservation_time + (r.duration_minutes || ' minutes')::interval) > p_time
	),
	blocked_tables as (
		select
			b.floorplan_table_id,
			b.blocked_at + make_interval(mins => 30 + 30 * ft.capacity) as block_ends_at
		from table_block b
		join floorplan_table ft on b.floorplan_table_id = ft.id
		cross join slot_times
		-- Block overlaps with slot if: block_start < slot_end AND block_end > slot_start
		where b.blocked_at < slot_times.slot_end
			and b.blocked_at + make_interval(mins => 30 + 30 * ft.capacity) > slot_times.slot_start
	)
	select
		ft.id,
		ft.floorplan_id,
		ft.name,
		ft.capacity,
		ft.x_pct,
		ft.y_pct,
		bt.floorplan_table_id is null and cr.floorplan_table_id is null,
		bt.floorplan_table_id is not null,
		bt.block_ends_at,
		cr.floorplan_table_id is not null
	from floorplan_table ft
	left join blocked_tables bt on ft.id = bt.floorplan_table_id
	left join conflicting_reservations cr on ft.id = cr.floorplan_table_id
	order by ft.floorplan_id, ft.name;
$$;


--
-- Name: FUNCTION get_tables_for_slot(p_date date, p_time time without time zone, p_duration integer, p_exclude_reservation_id integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.get_tables_for_slot(p_date date, p_time time without time zone, p_duration integer, p_exclude_reservation_id integer) IS 'HTTP GET
Get all tables with availability flags for booking UI';


--
-- Name: is_authenticated(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_authenticated() RETURNS public.auth_result
    LANGUAGE sql
    AS $$
	select true;
$$;


--
-- Name: FUNCTION is_authenticated(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_authenticated() IS 'HTTP GET
@authorize
Returns authenticated status if session is valid, 401 if not';


--
-- Name: is_restaurant_configured(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_restaurant_configured() RETURNS public.restaurant_configured_result
    LANGUAGE sql
    AS $$
	select exists(select 1 from restaurant where id = 1);
$$;


--
-- Name: FUNCTION is_restaurant_configured(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_restaurant_configured() IS 'HTTP GET
Check if restaurant settings have been configured';


--
-- Name: is_setup(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.is_setup() RETURNS public.setup_result
    LANGUAGE sql
    AS $$
	select exists(select 1 from admin_users);
$$;


--
-- Name: FUNCTION is_setup(); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.is_setup() IS 'HTTP GET
Check if the system has been set up with an admin account';


--
-- Name: mark_notification_delivered(text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.mark_notification_delivered(p_token text) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
	v_session record;
begin
	-- Get session
	select cs.* into v_session
	from customer_session cs
	where cs.token = p_token and cs.expires_at > now();

	if v_session is null then
		raise exception 'INVALID_SESSION: Invalid or expired session';
	end if;

	-- Mark notifications as delivered
	update reservation_notification
	set delivered = true
	where reservation_id = v_session.reservation_id
		and not delivered;
end;
$$;


--
-- Name: FUNCTION mark_notification_delivered(p_token text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.mark_notification_delivered(p_token text) IS 'HTTP POST
Mark customer notification as delivered';


--
-- Name: resolve_reservation(integer, text, text, integer[]); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.resolve_reservation(p_id integer, p_status text, p_admin_message text DEFAULT NULL::text, p_table_ids integer[] DEFAULT NULL::integer[]) RETURNS void
    LANGUAGE plpgsql
    AS $$
declare
	v_token text;
	v_code text;
begin
	v_code := 'reservation_' || p_status;

	-- Update reservation status
	update reservation
	set status = p_status
	where id = p_id;

	-- Assign tables if provided
	if p_table_ids is not null and array_length(p_table_ids, 1) > 0 then
		delete from reservation_table where reservation_id = p_id;
		insert into reservation_table (reservation_id, floorplan_table_id)
		select p_id, unnest(p_table_ids);
	end if;

	-- Create notification record
	insert into reservation_notification (reservation_id, code, admin_message)
	values (p_id, v_code, p_admin_message);

	-- Broadcast to SSE clients
	select channel_id into v_token
	from customer_session
	where reservation_id = p_id and expires_at > now()
		and channel_id is not null
	limit 1;

	if v_token is not null then
		raise info '%', jsonb_build_object(
			'code', v_code,
			'channelId', v_token,
			'adminMessage', p_admin_message
		);
	end if;
end;
$$;


--
-- Name: FUNCTION resolve_reservation(p_id integer, p_status text, p_admin_message text, p_table_ids integer[]); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.resolve_reservation(p_id integer, p_status text, p_admin_message text, p_table_ids integer[]) IS 'HTTP POST
@authorize
@sse
Resolve a reservation (confirm or decline) and notify customer';


--
-- Name: save_floorplan(text, text, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_floorplan(p_name text, p_image_path text, p_image_width integer, p_image_height integer, p_sort_order integer DEFAULT 0) RETURNS public.floorplan_save_result
    LANGUAGE sql
    AS $$
	insert into floorplan (name, image_path, image_width, image_height, sort_order)
	values (p_name, p_image_path, p_image_width, p_image_height, p_sort_order)
	returning id;
$$;


--
-- Name: FUNCTION save_floorplan(p_name text, p_image_path text, p_image_width integer, p_image_height integer, p_sort_order integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.save_floorplan(p_name text, p_image_path text, p_image_width integer, p_image_height integer, p_sort_order integer) IS 'HTTP POST
@authorize
Save a new floorplan';


--
-- Name: save_floorplan_table(integer, numeric, numeric, text, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_floorplan_table(p_floorplan_id integer, p_x_pct numeric, p_y_pct numeric, p_name text DEFAULT NULL::text, p_capacity integer DEFAULT 4, p_notes text DEFAULT NULL::text) RETURNS public.floorplan_table_result
    LANGUAGE plpgsql
    AS $_$
declare
	v_name text;
	v_max_num int;
	v_id int;
begin
	if p_name is null then
		-- Find max numeric name in this floorplan and increment
		select max(ft.name::int)
		into v_max_num
		from floorplan_table ft
		where ft.floorplan_id = p_floorplan_id
			and ft.name ~ '^\d+$';

		v_name := (coalesce(v_max_num, 0) + 1)::text;
	else
		v_name := p_name;
	end if;

	insert into floorplan_table (floorplan_id, name, capacity, notes, x_pct, y_pct)
	values (p_floorplan_id, v_name, p_capacity, p_notes, p_x_pct, p_y_pct)
	returning id into v_id;

	return row(v_id, v_name, p_capacity, p_notes, p_x_pct, p_y_pct)::floorplan_table_result;
end;
$_$;


--
-- Name: FUNCTION save_floorplan_table(p_floorplan_id integer, p_x_pct numeric, p_y_pct numeric, p_name text, p_capacity integer, p_notes text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.save_floorplan_table(p_floorplan_id integer, p_x_pct numeric, p_y_pct numeric, p_name text, p_capacity integer, p_notes text) IS 'HTTP POST
@authorize
Save a new table to a floorplan';


--
-- Name: save_restaurant(text, text, text, jsonb); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.save_restaurant(p_name text, p_address text DEFAULT NULL::text, p_phone text DEFAULT NULL::text, p_working_hours jsonb DEFAULT '{}'::jsonb) RETURNS void
    LANGUAGE sql
    AS $$
	insert into restaurant (id, name, address, phone, working_hours)
	values (1, p_name, p_address, p_phone, p_working_hours)
	on conflict (id) do update set
		name = excluded.name,
		address = excluded.address,
		phone = excluded.phone,
		working_hours = excluded.working_hours;
$$;


--
-- Name: FUNCTION save_restaurant(p_name text, p_address text, p_phone text, p_working_hours jsonb); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.save_restaurant(p_name text, p_address text, p_phone text, p_working_hours jsonb) IS 'HTTP POST
@authorize
Save restaurant settings';


--
-- Name: setup_admin(text, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.setup_admin(p_username text, p_password text) RETURNS void
    LANGUAGE plpgsql
    AS $$
begin
	if exists(select 1 from admin_users) then
		raise exception 'ALREADY_SETUP: System is already set up';
	end if;

	insert into admin_users (username, password_hash)
	values (p_username, crypt(p_password, gen_salt('bf')));
end;
$$;


--
-- Name: FUNCTION setup_admin(p_username text, p_password text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.setup_admin(p_username text, p_password text) IS 'HTTP POST
@rate_limiter_policy auth
Set up the initial admin account. Only works if no admin exists.';


--
-- Name: unblock_table(integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.unblock_table(p_table_id integer) RETURNS void
    LANGUAGE sql
    AS $$
	delete from table_block
	where floorplan_table_id = p_table_id;
$$;


--
-- Name: FUNCTION unblock_table(p_table_id integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.unblock_table(p_table_id integer) IS 'HTTP POST
@authorize
Remove block from a table';


--
-- Name: update_floorplan(integer, text, integer); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_floorplan(p_id integer, p_name text, p_sort_order integer DEFAULT NULL::integer) RETURNS public.floorplan_save_result
    LANGUAGE sql
    AS $$
	update floorplan
	set name = p_name,
		sort_order = coalesce(p_sort_order, sort_order)
	where id = p_id
	returning id;
$$;


--
-- Name: FUNCTION update_floorplan(p_id integer, p_name text, p_sort_order integer); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.update_floorplan(p_id integer, p_name text, p_sort_order integer) IS 'HTTP POST
@authorize
Update floorplan name or sort order';


--
-- Name: update_floorplan_table(integer, text, integer, text, numeric, numeric); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_floorplan_table(p_id integer, p_name text DEFAULT NULL::text, p_capacity integer DEFAULT NULL::integer, p_notes text DEFAULT NULL::text, p_x_pct numeric DEFAULT NULL::numeric, p_y_pct numeric DEFAULT NULL::numeric) RETURNS public.floorplan_table_result
    LANGUAGE sql
    AS $$
	update floorplan_table
	set
		name = coalesce(p_name, floorplan_table.name),
		capacity = coalesce(p_capacity, floorplan_table.capacity),
		notes = coalesce(p_notes, floorplan_table.notes),
		x_pct = coalesce(p_x_pct, floorplan_table.x_pct),
		y_pct = coalesce(p_y_pct, floorplan_table.y_pct)
	where floorplan_table.id = p_id
	returning row(id, name, capacity, notes, x_pct, y_pct)::floorplan_table_result;
$$;


--
-- Name: FUNCTION update_floorplan_table(p_id integer, p_name text, p_capacity integer, p_notes text, p_x_pct numeric, p_y_pct numeric); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.update_floorplan_table(p_id integer, p_name text, p_capacity integer, p_notes text, p_x_pct numeric, p_y_pct numeric) IS 'HTTP POST
@authorize
Update a floorplan table';


--
-- Name: update_reservation(integer, text, text, text, integer, date, time without time zone, integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_reservation(p_id integer, p_guest_name text DEFAULT NULL::text, p_guest_phone text DEFAULT NULL::text, p_guest_email text DEFAULT NULL::text, p_party_size integer DEFAULT NULL::integer, p_reservation_date date DEFAULT NULL::date, p_reservation_time time without time zone DEFAULT NULL::time without time zone, p_duration_minutes integer DEFAULT NULL::integer, p_notes text DEFAULT NULL::text) RETURNS public.reservation_id_result
    LANGUAGE sql
    AS $$
	update reservation
	set
		guest_name = coalesce(p_guest_name, guest_name),
		guest_phone = coalesce(p_guest_phone, guest_phone),
		guest_email = coalesce(p_guest_email, guest_email),
		party_size = coalesce(p_party_size, party_size),
		reservation_date = coalesce(p_reservation_date, reservation_date),
		reservation_time = coalesce(p_reservation_time, reservation_time),
		duration_minutes = coalesce(p_duration_minutes, duration_minutes),
		notes = coalesce(p_notes, notes)
	where id = p_id
	returning row(id)::reservation_id_result;
$$;


--
-- Name: FUNCTION update_reservation(p_id integer, p_guest_name text, p_guest_phone text, p_guest_email text, p_party_size integer, p_reservation_date date, p_reservation_time time without time zone, p_duration_minutes integer, p_notes text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.update_reservation(p_id integer, p_guest_name text, p_guest_phone text, p_guest_email text, p_party_size integer, p_reservation_date date, p_reservation_time time without time zone, p_duration_minutes integer, p_notes text) IS 'HTTP POST
@authorize
Update reservation details';


--
-- Name: update_reservation_status(integer, text); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_reservation_status(p_id integer, p_status text) RETURNS public.reservation_update_result
    LANGUAGE sql
    AS $$
	update reservation
	set status = p_status
	where id = p_id
	returning row(id, status)::reservation_update_result;
$$;


--
-- Name: FUNCTION update_reservation_status(p_id integer, p_status text); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.update_reservation_status(p_id integer, p_status text) IS 'HTTP POST
@authorize
Update reservation status (confirm, decline, complete, etc.)';


--
-- Name: update_restaurant_timestamp(); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.update_restaurant_timestamp() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	new.updated_at = now();
	return new;
end;
$$;


--
-- Name: upload_floorplan_image(json); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.upload_floorplan_image(_meta json DEFAULT NULL::json) RETURNS json
    LANGUAGE plpgsql
    AS $$
begin
	return json_build_object(
		'path', '/' || substr(_meta->0->>'filePath', 8)
	);
end;
$$;


--
-- Name: FUNCTION upload_floorplan_image(_meta json); Type: COMMENT; Schema: public; Owner: -
--

COMMENT ON FUNCTION public.upload_floorplan_image(_meta json) IS 'HTTP POST
@authorize
@upload for file_system
Upload floorplan image file';


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: admin_users; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.admin_users (
    id integer NOT NULL,
    username text NOT NULL,
    password_hash text NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: admin_users_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.admin_users_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: admin_users_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.admin_users_id_seq OWNED BY public.admin_users.id;


--
-- Name: customer_session; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.customer_session (
    id integer NOT NULL,
    token text DEFAULT (gen_random_uuid())::text NOT NULL,
    reservation_id integer,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    expires_at timestamp with time zone DEFAULT (now() + '24:00:00'::interval) NOT NULL,
    channel_id text
);


--
-- Name: customer_session_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.customer_session_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: customer_session_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.customer_session_id_seq OWNED BY public.customer_session.id;


--
-- Name: floorplan; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.floorplan (
    id integer NOT NULL,
    name text NOT NULL,
    image_path text NOT NULL,
    image_width integer NOT NULL,
    image_height integer NOT NULL,
    sort_order integer DEFAULT 0 NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: floorplan_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.floorplan_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: floorplan_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.floorplan_id_seq OWNED BY public.floorplan.id;


--
-- Name: floorplan_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.floorplan_table (
    id integer NOT NULL,
    floorplan_id integer NOT NULL,
    name text NOT NULL,
    capacity integer DEFAULT 2 NOT NULL,
    notes text,
    x_pct numeric(5,4) NOT NULL,
    y_pct numeric(5,4) NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT floorplan_table_x_pct_check CHECK (((x_pct >= (0)::numeric) AND (x_pct <= (1)::numeric))),
    CONSTRAINT floorplan_table_y_pct_check CHECK (((y_pct >= (0)::numeric) AND (y_pct <= (1)::numeric)))
);


--
-- Name: floorplan_table_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.floorplan_table_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: floorplan_table_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.floorplan_table_id_seq OWNED BY public.floorplan_table.id;


--
-- Name: reservation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservation (
    id integer NOT NULL,
    guest_name text NOT NULL,
    guest_phone text,
    guest_email text,
    party_size integer NOT NULL,
    reservation_date date NOT NULL,
    reservation_time time without time zone NOT NULL,
    duration_minutes integer DEFAULT 90 NOT NULL,
    status text DEFAULT 'pending'::text NOT NULL,
    source text DEFAULT 'online'::text NOT NULL,
    notes text,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT reservation_party_size_check CHECK ((party_size >= 1)),
    CONSTRAINT reservation_source_check CHECK ((source = ANY (ARRAY['online'::text, 'phone'::text, 'walk_in'::text]))),
    CONSTRAINT reservation_status_check CHECK ((status = ANY (ARRAY['pending'::text, 'confirmed'::text, 'declined'::text, 'completed'::text, 'no_show'::text, 'cancelled'::text])))
);


--
-- Name: reservation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reservation_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reservation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reservation_id_seq OWNED BY public.reservation.id;


--
-- Name: reservation_notification; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservation_notification (
    id integer NOT NULL,
    reservation_id integer NOT NULL,
    code text NOT NULL,
    admin_message text,
    delivered boolean DEFAULT false NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: reservation_notification_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.reservation_notification_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: reservation_notification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.reservation_notification_id_seq OWNED BY public.reservation_notification.id;


--
-- Name: reservation_table; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.reservation_table (
    reservation_id integer NOT NULL,
    floorplan_table_id integer NOT NULL
);


--
-- Name: restaurant; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.restaurant (
    id integer DEFAULT 1 NOT NULL,
    name text NOT NULL,
    address text,
    phone text,
    working_hours jsonb DEFAULT '{}'::jsonb NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT restaurant_id_check CHECK ((id = 1))
);


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version character varying NOT NULL
);


--
-- Name: table_block; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.table_block (
    id integer NOT NULL,
    floorplan_table_id integer NOT NULL,
    blocked_at timestamp with time zone DEFAULT now() NOT NULL,
    notes text
);


--
-- Name: table_block_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.table_block_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: table_block_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.table_block_id_seq OWNED BY public.table_block.id;


--
-- Name: admin_users id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users ALTER COLUMN id SET DEFAULT nextval('public.admin_users_id_seq'::regclass);


--
-- Name: customer_session id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_session ALTER COLUMN id SET DEFAULT nextval('public.customer_session_id_seq'::regclass);


--
-- Name: floorplan id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.floorplan ALTER COLUMN id SET DEFAULT nextval('public.floorplan_id_seq'::regclass);


--
-- Name: floorplan_table id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.floorplan_table ALTER COLUMN id SET DEFAULT nextval('public.floorplan_table_id_seq'::regclass);


--
-- Name: reservation id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation ALTER COLUMN id SET DEFAULT nextval('public.reservation_id_seq'::regclass);


--
-- Name: reservation_notification id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_notification ALTER COLUMN id SET DEFAULT nextval('public.reservation_notification_id_seq'::regclass);


--
-- Name: table_block id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_block ALTER COLUMN id SET DEFAULT nextval('public.table_block_id_seq'::regclass);


--
-- Name: admin_users admin_users_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_pkey PRIMARY KEY (id);


--
-- Name: admin_users admin_users_username_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.admin_users
    ADD CONSTRAINT admin_users_username_key UNIQUE (username);


--
-- Name: customer_session customer_session_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_session
    ADD CONSTRAINT customer_session_pkey PRIMARY KEY (id);


--
-- Name: customer_session customer_session_token_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_session
    ADD CONSTRAINT customer_session_token_key UNIQUE (token);


--
-- Name: floorplan floorplan_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.floorplan
    ADD CONSTRAINT floorplan_pkey PRIMARY KEY (id);


--
-- Name: floorplan_table floorplan_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.floorplan_table
    ADD CONSTRAINT floorplan_table_pkey PRIMARY KEY (id);


--
-- Name: table_block one_active_block_per_table; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_block
    ADD CONSTRAINT one_active_block_per_table UNIQUE (floorplan_table_id);


--
-- Name: reservation_notification reservation_notification_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_notification
    ADD CONSTRAINT reservation_notification_pkey PRIMARY KEY (id);


--
-- Name: reservation reservation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation
    ADD CONSTRAINT reservation_pkey PRIMARY KEY (id);


--
-- Name: reservation_table reservation_table_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_table
    ADD CONSTRAINT reservation_table_pkey PRIMARY KEY (reservation_id, floorplan_table_id);


--
-- Name: restaurant restaurant_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.restaurant
    ADD CONSTRAINT restaurant_pkey PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: table_block table_block_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_block
    ADD CONSTRAINT table_block_pkey PRIMARY KEY (id);


--
-- Name: customer_session_reservation_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX customer_session_reservation_idx ON public.customer_session USING btree (reservation_id);


--
-- Name: customer_session_token_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX customer_session_token_idx ON public.customer_session USING btree (token);


--
-- Name: floorplan_table_floorplan_id_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX floorplan_table_floorplan_id_idx ON public.floorplan_table USING btree (floorplan_id);


--
-- Name: reservation_date_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservation_date_idx ON public.reservation USING btree (reservation_date);


--
-- Name: reservation_date_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservation_date_status_idx ON public.reservation USING btree (reservation_date, status);


--
-- Name: reservation_notification_reservation_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservation_notification_reservation_idx ON public.reservation_notification USING btree (reservation_id);


--
-- Name: reservation_status_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservation_status_idx ON public.reservation USING btree (status);


--
-- Name: reservation_table_table_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX reservation_table_table_idx ON public.reservation_table USING btree (floorplan_table_id);


--
-- Name: reservation reservation_not_in_past; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER reservation_not_in_past BEFORE INSERT OR UPDATE OF reservation_date, reservation_time ON public.reservation FOR EACH ROW EXECUTE FUNCTION public.check_reservation_not_in_past();


--
-- Name: reservation reservation_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER reservation_updated_at BEFORE UPDATE ON public.reservation FOR EACH ROW EXECUTE FUNCTION public.update_restaurant_timestamp();


--
-- Name: restaurant restaurant_updated_at; Type: TRIGGER; Schema: public; Owner: -
--

CREATE TRIGGER restaurant_updated_at BEFORE UPDATE ON public.restaurant FOR EACH ROW EXECUTE FUNCTION public.update_restaurant_timestamp();


--
-- Name: customer_session customer_session_reservation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.customer_session
    ADD CONSTRAINT customer_session_reservation_id_fkey FOREIGN KEY (reservation_id) REFERENCES public.reservation(id) ON DELETE CASCADE;


--
-- Name: floorplan_table floorplan_table_floorplan_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.floorplan_table
    ADD CONSTRAINT floorplan_table_floorplan_id_fkey FOREIGN KEY (floorplan_id) REFERENCES public.floorplan(id) ON DELETE CASCADE;


--
-- Name: reservation_notification reservation_notification_reservation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_notification
    ADD CONSTRAINT reservation_notification_reservation_id_fkey FOREIGN KEY (reservation_id) REFERENCES public.reservation(id) ON DELETE CASCADE;


--
-- Name: reservation_table reservation_table_floorplan_table_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_table
    ADD CONSTRAINT reservation_table_floorplan_table_id_fkey FOREIGN KEY (floorplan_table_id) REFERENCES public.floorplan_table(id) ON DELETE CASCADE;


--
-- Name: reservation_table reservation_table_reservation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.reservation_table
    ADD CONSTRAINT reservation_table_reservation_id_fkey FOREIGN KEY (reservation_id) REFERENCES public.reservation(id) ON DELETE CASCADE;


--
-- Name: table_block table_block_floorplan_table_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.table_block
    ADD CONSTRAINT table_block_floorplan_table_id_fkey FOREIGN KEY (floorplan_table_id) REFERENCES public.floorplan_table(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict dbmate


--
-- Dbmate schema migrations
--

INSERT INTO public.schema_migrations (version) VALUES
    ('20260114155206'),
    ('20260116133141'),
    ('20260117162152'),
    ('20260118123020'),
    ('20260119193812'),
    ('20260122100000'),
    ('20260124233127'),
    ('20260126073500'),
    ('20260127204416');
