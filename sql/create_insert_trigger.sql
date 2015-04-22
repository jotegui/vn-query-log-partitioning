create trigger query_log_insert_trigger
    before insert on query_log_master
        for each row execute procedure query_log_insert_function();
