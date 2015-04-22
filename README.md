# Partitioning `query_log` table
SQL functions and instructions on how to construct and update a partitioned table setup for logging queries made to the VertNet data portal.

Author: [Javier Otegui](mailto:javier.otegui@gmail.com) for the [VertNet Project](https://www.vertnet.org)

[toc]

## Rationale and execution

`query_log` is the table that stores a regitry of the query and download events of the [VertNet portal](http://portal.vertnet.org). Due to its nature, this table grows very fast and as of March 31st 2015, it surpassed the maximum size for optimal retrieval of information, meaning regular calls (especially `INSERT` calls) to this table are likely to fail.

A re-thinking of the structure of this table is needed. A good solution is to implement a system of partitioned tables instead of a single table, splitting initially by year. If there are performance issues, the partition criteria can be changed and the full system can be easily rebuilt.

This repository contains the sql files that have been executed on the database via the CartoDB API. In order to reproduce these queries, an API call must have this structure:

	https://[domain].cartodb.com/api/v2/sql?api_key=[api-key]&q=[sql-file-content]

## Setup the partition tables structure

Building the partitioned table system involves XX steps:

##### Create the master table

Executing the **`create_master_table.sql`**, a new table is created called `query_log_master`, with the same structure as the `query_log` table. If there was any previous version of this table, it will be deleted and all functions and triggers associated will also be erased.

##### Cartodbfy the master table

Tables created via the SQL API cannot be seen from the main CartoDB UI, and several triggers and indexes are not created. The guys at CartoDB have developed a function called `CDB_CartodbfyTable` that creates a series of fields, indexes and functions on the specified table. This is achieved by executing the sql in the **`cartodbfy_master_table.sql`** file.

##### Create the partitions

The master table itself will always be empty. Records will be stored in one or more partitions. As an initial criterion for partitioning, I have decided to use year, so that all queries and downloads from the portal in a given year will be stored in a separate table. A table for each year has to be built, and thi is achieved executing the **`create_partition_tables.sql`** sql.

##### Create the indexes in the partitions

To improve performance, one index on each partition should -- at least-- be created: an index on the partitioning criterion. In this case, I have created an index on the `created_at` field for each partition. This sql is stored in the **`create_partition_tables_index.sql`** file.

##### Create the insert redirection function and trigger

Right now, if we send an `INSERT` query to `query_log_table`, the record will be kept in this table. We don't want that. We want the database to redirect the record to the proper table based on the content of the `created_at` field. The sql in the **`create_insert_function.sql`** file generates a function that checks the value of `created_at` and finds the appropriate table to send the record to.

Still, this alone won't work. This will send a new record to the correct table, but the function needs to be expicitly called. The system needs a trigger that fires the previous function up when a new `INSERT` query comes to `query_log_master`. The code for creating this trigger is in the **`create_insert_trigger.sql`** file.

And now, we have the partition tables ready

## Initial load of existing records from `query_log`

Loading the existing records into `query_log_master` is a single step process that is executed when calling the sql in the **`insert_existing_records.sql`** file. This will `select` all records in `query_log` table and send them to `query_log_master`. For each record, the trigger will execute the `query_log_insert_function` function and the record will be redirected to the proper table based on the value of the `created_at` field.

The content of the tables can be checked by counting the records in the master table and each partition

```sql
-- check records in master table
select count(*) from query_log_master -- all records
-- check records in each partition
select count(*) from query_log_2013 -- only records from 2013
select count(*) from query_log_2014 -- only records from 2014
select count(*) from query_log_2015 -- only records from 2015
```

## Loading and querying records

The tables are set, pieces should start moving. To load new records, simply execute an `INSERT` statement on `query_log_master` table. The trigger will run the `query_log_insert_function` function and the record will be redirected to the proper table based on the value of the `created_at` field.

All queries should be directed to `query_log_master` table, and records will be retrieved from the appropriate partition. When executing time-based queries (like "give me all records for year X"), indexing will reduce the amount of tables to scan, meaning a better performance of the query.

## IMPORTANT - Update of filters: adding new years

In order for this setup to work, filters and partitions should undergo certain routine upkeep. Specifically, and since records are stored in a table based on the year they have been created, new partitions should be added and the redirecting function should be updated before the new year starts.

The system, as it is at the moment of creation, is **ready to log queries up to the end of 2016**. Before 2016 ends, the system should be updated to allow logging queries made in 2017.

Here is an example that shows the necessary steps to prepare the system for logging queries made in 2017:

##### Create a new partition

Execute the following sql statement via the CartoDB SQL API (as explained in the RATIONALE AND EXECUTION section):

```sql
create table query_log_2017 (check (created_at >= DATE '2017-01-01' and created_at < DATE '2018-01-01')) inherits (query_log_master);
```

This creates a new table, called `query_log_2017`, adds a `constraint` that will only allow the table to be populated with records whose `created_at` value falls between 2017-01-01 and 2017-12-31, and links the table to `query_log_master` via table inheritance, indicating this is a partition of the master table.

##### Create an index on `created_at` for the new partition

Execute the following sql statement via the CartoDB API:

```sql
create index query_log_2017_created_at on query_log_2017 (created_at);
```

This creates an index on the `created_at` field of the new partition table. Create any other indexes as necessary.

##### Update the redirectioning filter

Open the `create_insert_function.sql` file and modify it as follows:

* In line 5 (which should start with `if (new.created_at...`), change the `if` for `elsif`, so that the new line is `elsif (new.created_at...`.
* Above this line, add the following statement (it should become the content of line 5, before all the lines starting with `elsif`):

```sql
if (new.created_at >= DATE '2017-01-01' and new.created_at < DATE '2018-01-01') then insert into query_log_2017 values (new.*);
```

and then execute the whole content of the file via the CartoDB API. This will update the function by adding a new condition: if the created_at value of the new record falls between 2017-01-01 and 2017-12-31, move it to table `query_log_2017`.

The order of the filters is relevant, for query optimization. When receiving an `INSERT` query, the database will execute this function. It will go through the list of conditions until one is met. If new filters (filters for new years) are put at the top of the list of conditions, the condition will be met sooner, and this will avoid checking the rest of the conditions, thus optimizing the selection of the table.