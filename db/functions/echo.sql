drop function if exists echo(text);
create function echo(p_message text) returns echo_result as $$
select row(p_message)::echo_result;
$$ language sql;

comment on function echo(text) is 'HTTP
Echoes the input message back';
