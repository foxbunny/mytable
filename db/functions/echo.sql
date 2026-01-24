drop function if exists echo(text);
create function echo(p_message text) returns jsonb as $$
select jsonb_build_object('message', p_message);
$$ language sql;

comment on function echo(text) is 'HTTP
Echoes the input message back';
