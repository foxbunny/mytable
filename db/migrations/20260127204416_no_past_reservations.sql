-- migrate:up
create function check_reservation_not_in_past() returns trigger as $$
begin
	if new.reservation_date + new.reservation_time < now() then
		raise exception 'PAST_RESERVATION: Cannot create or update reservation in the past';
	end if;
	return new;
end;
$$ language plpgsql;

create trigger reservation_not_in_past
	before insert or update of reservation_date, reservation_time on reservation
	for each row
	execute function check_reservation_not_in_past();

-- migrate:down
drop trigger if exists reservation_not_in_past on reservation;
drop function if exists check_reservation_not_in_past();
