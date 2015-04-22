create table query_log_2013
    (check (created_at >= DATE '2013-01-01' and created_at < DATE '2014-01-01'))
    inherits (query_log_master);
create table query_log_2014
    (check (created_at >= DATE '2014-01-01' and created_at < DATE '2015-01-01'))
    inherits (query_log_master);
create table query_log_2015
    (check (created_at >= DATE '2015-01-01' and created_at < DATE '2016-01-01'))
    inherits (query_log_master);
create table query_log_2016
    (check (created_at >= DATE '2016-01-01' and created_at < DATE '2017-01-01'))
    inherits (query_log_master);
