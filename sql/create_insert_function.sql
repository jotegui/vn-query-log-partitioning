create or replace function query_log_insert_function()
returns trigger as $$
begin
    -- add new conditions for new years here
    if (new.created_at >= DATE '2016-01-01' and new.created_at < DATE '2017-01-01')
        then insert into query_log_2016 values (new.*);
    elsif (new.created_at >= DATE '2015-01-01' and new.created_at < DATE '2016-01-01')
        then insert into query_log_2015 values (new.*);
    elsif (new.created_at >= DATE '2014-01-01' and new.created_at < DATE '2015-01-01')
        then insert into query_log_2014 values (new.*);
    elsif (new.created_at >= DATE '2013-01-01' and new.created_at < DATE '2014-01-01')
        then insert into query_log_2013 values (new.*);
    
    else
        raise exception 'Creation date out of range. Please fix the query_log_insert_function by adding a new "elsif ... then ..." statement'; 

    end if;
    return null;
end;
$$
language plpgsql;
