-- Customer creates a reservation (public endpoint, no auth)
drop function if exists customer_create_reservation(text, int, date, time, text, text, text);
create function customer_create_reservation(
	p_guest_name text,
	p_party_size int,
	p_reservation_date date,
	p_reservation_time time,
	p_guest_phone text default null,
	p_guest_email text default null,
	p_notes text default null
) returns table(reservation_id int, session_token text) as $$
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
	insert into customer_session (reservation_id)
	values (v_reservation_id)
	returning token into v_token;

	-- Notify admin via LISTEN/NOTIFY
	perform pg_notify('admin_notifications', jsonb_build_object(
		'code', 'new_pending',
		'reservationId', v_reservation_id,
		'guestName', p_guest_name,
		'partySize', p_party_size,
		'reservationDate', p_reservation_date,
		'reservationTime', p_reservation_time
	)::text);

	return query select v_reservation_id, v_token;
end;
$$ language plpgsql;

comment on function customer_create_reservation(text, int, date, time, text, text, text) is 'HTTP POST
Create a new reservation from customer portal';

-- Get customer notification status (polling fallback)
drop function if exists get_customer_notification(text);
create function get_customer_notification(p_token text)
returns table(
	code text,
	admin_message text,
	reservation_status text,
	reservation_date date,
	reservation_time time,
	party_size int,
	guest_name text
) as $$
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
		return;
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
		return query select
			v_notification.code,
			v_notification.admin_message,
			v_reservation.status,
			v_reservation.reservation_date,
			v_reservation.reservation_time,
			v_reservation.party_size,
			v_reservation.guest_name;
	else
		-- Return current status without notification code
		return query select
			null::text,
			null::text,
			v_reservation.status,
			v_reservation.reservation_date,
			v_reservation.reservation_time,
			v_reservation.party_size,
			v_reservation.guest_name;
	end if;
end;
$$ language plpgsql;

comment on function get_customer_notification(text) is 'HTTP GET
Get notification status for customer reservation';

-- Mark notification as delivered
drop function if exists mark_notification_delivered(text);
create function mark_notification_delivered(p_token text) returns jsonb as $$
declare
	v_session record;
begin
	-- Get session
	select cs.* into v_session
	from customer_session cs
	where cs.token = p_token and cs.expires_at > now();

	if v_session is null then
		return jsonb_build_object('error', 'INVALID_SESSION: Invalid or expired session');
	end if;

	-- Mark notifications as delivered
	update reservation_notification
	set delivered = true
	where reservation_id = v_session.reservation_id
		and not delivered;

	return '{}'::jsonb;
end;
$$ language plpgsql;

comment on function mark_notification_delivered(text) is 'HTTP POST
Mark customer notification as delivered';

-- Confirm reservation with notification
drop function if exists confirm_reservation(int, text, int[]);
create function confirm_reservation(
	p_id int,
	p_admin_message text default null,
	p_table_ids int[] default null
) returns jsonb as $$
declare
	v_token text;
begin
	-- Update reservation status
	update reservation
	set status = 'confirmed'
	where id = p_id;

	-- Assign tables if provided
	if p_table_ids is not null and array_length(p_table_ids, 1) > 0 then
		delete from reservation_table where reservation_id = p_id;
		insert into reservation_table (reservation_id, floorplan_table_id)
		select p_id, unnest(p_table_ids);
	end if;

	-- Create notification record
	insert into reservation_notification (reservation_id, code, admin_message)
	values (p_id, 'reservation_confirmed', p_admin_message);

	-- Get customer session token for this reservation
	select token into v_token
	from customer_session
	where reservation_id = p_id and expires_at > now()
	limit 1;

	-- Notify customer via their channel
	if v_token is not null then
		perform pg_notify('customer_' || v_token, jsonb_build_object(
			'code', 'reservation_confirmed',
			'adminMessage', p_admin_message
		)::text);
	end if;

	return '{}'::jsonb;
end;
$$ language plpgsql;

comment on function confirm_reservation(int, text, int[]) is 'HTTP POST
@authorize
Confirm a reservation and notify customer';

-- Decline reservation with notification
drop function if exists decline_reservation(int, text);
create function decline_reservation(
	p_id int,
	p_admin_message text default null
) returns jsonb as $$
declare
	v_token text;
begin
	-- Update reservation status
	update reservation
	set status = 'declined'
	where id = p_id;

	-- Create notification record
	insert into reservation_notification (reservation_id, code, admin_message)
	values (p_id, 'reservation_declined', p_admin_message);

	-- Get customer session token for this reservation
	select token into v_token
	from customer_session
	where reservation_id = p_id and expires_at > now()
	limit 1;

	-- Notify customer via their channel
	if v_token is not null then
		perform pg_notify('customer_' || v_token, jsonb_build_object(
			'code', 'reservation_declined',
			'adminMessage', p_admin_message
		)::text);
	end if;

	return '{}'::jsonb;
end;
$$ language plpgsql;

comment on function decline_reservation(int, text) is 'HTTP POST
@authorize
Decline a reservation and notify customer';

-- Get new pending reservations since a given timestamp (for admin polling)
drop function if exists get_new_pending_reservations(timestamptz);
create function get_new_pending_reservations(p_since timestamptz default null)
returns table(
	id int,
	guest_name text,
	party_size int,
	reservation_date date,
	reservation_time time,
	created_at timestamptz
) as $$
begin
	return query
	select r.id, r.guest_name, r.party_size, r.reservation_date, r.reservation_time, r.created_at
	from reservation r
	where r.status = 'pending'
		and r.source = 'online'
		and (p_since is null or r.created_at > p_since)
	order by r.created_at desc;
end;
$$ language plpgsql;

comment on function get_new_pending_reservations(timestamptz) is 'HTTP GET
@authorize
Get pending online reservations, optionally since a given timestamp';
