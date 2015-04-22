drop table if exists query_log_master;
create table query_log_master as select * from query_log where false;
