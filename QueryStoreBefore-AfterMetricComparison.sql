/*

Written by: Lee Markum

Date: September 2025

Purpose:These queries retrieve the queryIDs, query hash and various average performance metrics for those queries in a given time range and compares the AVG metric from before and after. I choose to retreive the TOP 10 from the before and compare them to the same
queryID values after so the query would be comparing the performance of the same queries. Some queryID values from the "before"
snapshot may not appear in the "after" snapshot and that is the reason for the LEFT JOIN

 

This is useful for capturing performance prior to a SQL Server migration and then after for the same set of queries.

This could also be useful for a before/after comparison after any change to a query.

 

This sort of query could be done with other query perofrmance metrics stored in Query Store.

 

*/

 

--First CTE: Get top 10 CPU-intensive queries from before the migration

 

USE SomeDB;

GO

 

DECLARE @BeforeStart datetime = '2026-07-30';

DECLARE @BeforeEnd   datetime = '2026-08-01 23:59:59';

 

DECLARE @AfterStart  datetime = '2026-08-02';

DECLARE @AfterEnd    datetime = '2026-08-04';

 

WITH FilteredTop10

AS (

                SELECT TOP 10 qsq.query_hash,qsq.query_id, qsqt.query_sql_text

                                ,SUM(qsrs.avg_cpu_time) AS avg_cpu_time_early

                FROM sys.query_store_query qsq

                JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id

                JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id

                JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id =

                qsrsi.runtime_stats_interval_id

JOIN sys.query_store_query_text qsqt

    ON qsq.query_text_id = qsqt.query_text_id

                WHERE qsrsi.start_time >= @BeforeStart

                                AND qsrsi.end_time < @BeforeEnd

                GROUP BY qsq.query_hash

                                ,qsq.query_id

                                ,qsqt.query_sql_text

                ORDER BY SUM(qsrs.avg_cpu_time) DESC

                )

 

--Pass into the below the queryIDs from before the migration to retreive the metrics for those queries for after the migration.

,LaterCpuStats

AS (

                SELECT qsq.query_id,qsqt.query_sql_text,AVG(qsrs.avg_cpu_time) AS avg_cpu_time_late

                FROM sys.query_store_query qsq

                JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id

                JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id

                JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id =

                qsrsi.runtime_stats_interval_id

JOIN sys.query_store_query_text qsqt

    ON qsq.query_text_id = qsqt.query_text_id

                WHERE qsrsi.start_time >= @AfterStart

                                AND qsrsi.end_time < @AfterEnd

                                AND qsq.query_id IN

                                (

                                               

                                                SELECT query_id

                                                FROM FilteredTop10

 

                                )

                GROUP BY qsq.query_hash

                                ,qsq.query_id

                                ,qsqt.query_sql_text

                )

 

 

                --Final output: Compare early vs. late CPU average usage

SELECT f.query_hash

                ,f.query_id

, f.query_sql_text

                ,f.avg_cpu_time_early

                ,l.avg_cpu_time_late

                ,(ISNULL(l.avg_cpu_time_late, 0) - f.avg_cpu_time_early) AS cpu_change

FROM FilteredTop10 f

LEFT JOIN LaterCpuStats l ON f.query_id = l.query_id

ORDER BY f.avg_cpu_time_early DESC;

 

 

 

 

/*********************************/

 

 

--First CTE: Get top 10 intensive queries by avg_logical_io_reads from before the migration

 

 

DECLARE @BeforeStart datetime = '2026-07-30';

DECLARE @BeforeEnd   datetime = '2026-08-01 23:59:59';

 

DECLARE @AfterStart  datetime = '2026-08-02';

DECLARE @AfterEnd    datetime = '2026-08-04';

 

WITH FilteredTop10

AS (

                SELECT TOP 10 qsq.query_hash,qsq.query_id, qsqt.query_sql_text

                                ,SUM(qsrs.avg_logical_io_reads) AS avg_logical_io_reads_early

                FROM sys.query_store_query qsq

                JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id

                JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id

                JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id =

                qsrsi.runtime_stats_interval_id

JOIN sys.query_store_query_text qsqt

    ON qsq.query_text_id = qsqt.query_text_id

                WHERE qsrsi.start_time >= @BeforeStart

                                AND qsrsi.end_time < @BeforeEnd

                GROUP BY qsq.query_hash

                                ,qsq.query_id

                                ,qsqt.query_sql_text

                ORDER BY SUM(qsrs.avg_logical_io_reads) DESC

                )

 

--Pass into the below the queryIDs from before the migration to retreive the metrics for those queries for after the migration.

,LaterStats

AS (

                SELECT qsq.query_id,qsqt.query_sql_text,AVG(qsrs.avg_logical_io_reads) AS avg_logical_io_reads_late

                FROM sys.query_store_query qsq

                JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id

                JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id

                JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id =

                qsrsi.runtime_stats_interval_id

JOIN sys.query_store_query_text qsqt

    ON qsq.query_text_id = qsqt.query_text_id

                WHERE qsrsi.start_time >= @AfterStart

                                AND qsrsi.end_time < @AfterEnd

                                AND qsq.query_id IN

                                (

                                               

                                                SELECT query_id

                                                FROM FilteredTop10

 

                                )

                GROUP BY qsq.query_hash

                                ,qsq.query_id

                                ,qsqt.query_sql_text

                )

 

 

                --Final output: Compare early vs. late stats

SELECT f.query_hash

                ,f.query_id

, f.query_sql_text

                ,f.avg_logical_io_reads_early

                ,l.avg_logical_io_reads_late

                ,(ISNULL(l.avg_logical_io_reads_late, 0) - f.avg_logical_io_reads_early) AS avg_logical_io_reads_change

FROM FilteredTop10 f

LEFT JOIN LaterStats l ON f.query_id = l.query_id

ORDER BY f.avg_logical_io_reads_early DESC;

 

 

 

--First CTE: Get top 10 intensive queries by avg_logical_io_writes from before the migration

 

 

DECLARE @BeforeStart datetime = '2026-07-30';

DECLARE @BeforeEnd   datetime = '2026-08-01 23:59:59';

 

DECLARE @AfterStart  datetime = '2026-08-02';

DECLARE @AfterEnd    datetime = '2026-08-04';

 

WITH FilteredTop10

AS (

                SELECT TOP 10 qsq.query_hash,qsq.query_id, qsqt.query_sql_text

                                ,SUM(qsrs.avg_logical_io_writes) AS avg_logical_io_writes_early

                FROM sys.query_store_query qsq

                JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id

                JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id

                JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id =

                qsrsi.runtime_stats_interval_id

JOIN sys.query_store_query_text qsqt

    ON qsq.query_text_id = qsqt.query_text_id

                WHERE qsrsi.start_time >= @BeforeStart

                                AND qsrsi.end_time < @BeforeEnd

                GROUP BY qsq.query_hash

                                ,qsq.query_id

                                ,qsqt.query_sql_text

                ORDER BY SUM(qsrs.avg_logical_io_writes) DESC

                )

 

--Pass into the below the queryIDs from before the migration to retreive the metrics for those queries for after the migration.

,LaterStats

AS (

                SELECT qsq.query_id,qsqt.query_sql_text,AVG(qsrs.avg_logical_io_writes) AS avg_logical_io_writes_late

                FROM sys.query_store_query qsq

                JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id

                JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id

                JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id =

                qsrsi.runtime_stats_interval_id

JOIN sys.query_store_query_text qsqt

    ON qsq.query_text_id = qsqt.query_text_id

                WHERE qsrsi.start_time >= @AfterStart

                                AND qsrsi.end_time < @AfterEnd

                                AND qsq.query_id IN

                                (

                                               

                                                SELECT query_id

                                                FROM FilteredTop10

 

                                )

                GROUP BY qsq.query_hash

                                ,qsq.query_id

                                ,qsqt.query_sql_text

                )

 

 

                --Final output: Compare early vs. late stats

SELECT f.query_hash

                ,f.query_id

, f.query_sql_text

                ,f.avg_logical_io_writes_early

                ,l.avg_logical_io_writes_late

                ,(ISNULL(l.avg_logical_io_writes_late, 0) - f.avg_logical_io_writes_early) AS avg_logical_io_writes_change

FROM FilteredTop10 f

LEFT JOIN LaterStats l ON f.query_id = l.query_id

ORDER BY f.avg_logical_io_writes_early DESC;

 

 

 

 

--First CTE: Get top 10 intensive queries by avg_query_max_used_memory from before the migration

 

DECLARE @BeforeStart datetime = '2026-07-30';

DECLARE @BeforeEnd   datetime = '2026-08-01 23:59:59';

 

DECLARE @AfterStart  datetime = '2026-08-02';

DECLARE @AfterEnd    datetime = '2026-08-04';

 

WITH FilteredTop10

AS (

                SELECT TOP 10 qsq.query_hash,qsq.query_id, qsqt.query_sql_text

                                ,SUM(qsrs.avg_query_max_used_memory) AS avg_query_max_used_memory_early

                FROM sys.query_store_query qsq

                JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id

                JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id

                JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id =

                qsrsi.runtime_stats_interval_id

JOIN sys.query_store_query_text qsqt

    ON qsq.query_text_id = qsqt.query_text_id

                WHERE qsrsi.start_time >= @BeforeStart

                                AND qsrsi.end_time < @BeforeEnd

                GROUP BY qsq.query_hash

                                ,qsq.query_id

                                ,qsqt.query_sql_text

                ORDER BY SUM(qsrs.avg_query_max_used_memory) DESC

                )

 

--Pass into the below the queryIDs from before the migration to retreive the metrics for those queries for after the migration.

,LaterStats

AS (

                SELECT qsq.query_id,qsqt.query_sql_text,AVG(qsrs.avg_query_max_used_memory) AS avg_query_max_used_memory_late

                FROM sys.query_store_query qsq

                JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id

                JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id

                JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id =

                qsrsi.runtime_stats_interval_id

JOIN sys.query_store_query_text qsqt

    ON qsq.query_text_id = qsqt.query_text_id

                WHERE qsrsi.start_time >= @AfterStart

                                AND qsrsi.end_time < @AfterEnd

                                AND qsq.query_id IN

                                (

                                               

                                                SELECT query_id

                                                FROM FilteredTop10

 

                                )

                GROUP BY qsq.query_hash

                                ,qsq.query_id

                                ,qsqt.query_sql_text

                )

 

 

                --Final output: Compare early vs. late stats

SELECT f.query_hash

                ,f.query_id

, f.query_sql_text

                ,f.avg_query_max_used_memory_early

                ,l.avg_query_max_used_memory_late

                ,(ISNULL(l.avg_query_max_used_memory_late, 0) - f.avg_query_max_used_memory_early) AS avg_query_max_used_memory_change

FROM FilteredTop10 f

LEFT JOIN LaterStats l ON f.query_id = l.query_id

ORDER BY f.avg_query_max_used_memory_early DESC;

 
