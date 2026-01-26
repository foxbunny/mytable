-- Customer creates a reservation (public endpoint, no auth)
drop function if exists customer_create_reservation(text, int, date, time, text, text, text);
drop function if exists customer_create_reservation(text, int, date, time, text, text, text, text);
create function customer_create_reservation(
	p_guest_name text,
	p_party_size int,
	p_reservation_date date,
	p_reservation_time time,
	p_guest_phone text default null,
	p_guest_email text default null,
	p_notes text default null,
	p_channel_id text default null
) returns jsonb as $$
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

	return jsonb_build_object('reservationId', v_reservation_id, 'sessionToken', v_token);
end;
$$ language plpgsql;

comment on function customer_create_reservation(text, int, date, time, text, text, text, text) is 'HTTP POST
@sse
Create a new reservation from customer portal';

-- Get customer notification status (polling fallback)
drop function if exists get_customer_notification(text);
create function get_customer_notification(p_token text) returns jsonb as $$
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
		return jsonb_build_object(
			'code', v_notification.code,
			'adminMessage', v_notification.admin_message,
			'reservationStatus', v_reservation.status,
			'reservationDate', v_reservation.reservation_date,
			'reservationTime', v_reservation.reservation_time,
			'partySize', v_reservation.party_size,
			'guestName', v_reservation.guest_name
		);
	else
		-- Return current status without notification code
		return jsonb_build_object(
			'code', null,
			'adminMessage', null,
			'reservationStatus', v_reservation.status,
			'reservationDate', v_reservation.reservation_date,
			'reservationTime', v_reservation.reservation_time,
			'partySize', v_reservation.party_size,
			'guestName', v_reservation.guest_name
		);
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

-- Resolve reservation (confirm or decline) with notification
drop function if exists confirm_reservation(int, text, int[]);
drop function if exists decline_reservation(int, text);
drop function if exists resolve_reservation(int, text, text, int[]);
create function resolve_reservation(
	p_id int,
	p_status text,
	p_admin_message text default null,
	p_table_ids int[] default null
) returns jsonb as $$
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

	return '{}'::jsonb;
end;
$$ language plpgsql;

comment on function resolve_reservation(int, text, text, int[]) is 'HTTP POST
@authorize
@sse
Resolve a reservation (confirm or decline) and notify customer';

-- Get new pending reservations since a given timestamp (for admin polling)
drop function if exists get_new_pending_reservations(timestamptz);
create function get_new_pending_reservations(p_since timestamptz default null) returns jsonb as $$
	select coalesce(jsonb_agg(jsonb_build_object(
		'id', r.id,
		'guestName', r.guest_name,
		'partySize', r.party_size,
		'reservationDate', r.reservation_date,
		'reservationTime', r.reservation_time,
		'createdAt', r.created_at
	) order by r.created_at desc), '[]')
	from reservation r
	where r.status = 'pending'
		and r.source = 'online'
		and (p_since is null or r.created_at > p_since);
$$ language sql;

comment on function get_new_pending_reservations(timestamptz) is 'HTTP GET
@authorize
Get pending online reservations, optionally since a given timestamp';
