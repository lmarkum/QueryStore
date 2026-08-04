/*

Written by: Lee Markum

Date: September 2025

Purpose:
These queries retrieve Query Store query_id values, query_hash values, and
average performance metrics for queries executed during two different time
ranges. The results compare the average metric values from a baseline period
("before") with those from a comparison period ("after").

The goal is similar to the Query Store Tracked Queries report, but these
queries allow you to view the top N queries simultaneously and determine
whether each metric improved or regressed following a change.

The script selects the TOP (10) queries from the baseline period and compares
those same query_id values against the comparison period. This ensures that the
comparison is performed against the same set of queries rather than whatever
happened to be the top queries after the change. Some baseline query_id values
may not appear during the comparison period, which is why a LEFT JOIN is used.

This is particularly useful when establishing a performance baseline before a
SQL Server migration and comparing it with performance after the migration.
It can also be used to measure the impact of query tuning, index changes,
configuration changes, or other modifications.

The same approach can be applied to any performance metric stored in Query
Store, not just CPU usage.

Updated: August 3, 2026
- Added comparisons for additional Query Store performance metrics beyond CPU.
- Updated the comment block and removed the repeating variable DECLARE sections.

Requirement: Query Store must have been enabled and in ReadWrite mode during the time periods under consideration.

*/

--First CTE: Get top 10 CPU-intensive queries from before the migration

USE SomeDB;
GO

DECLARE @BeforeStart DATETIME = '2026-07-30';
DECLARE @BeforeEnd DATETIME = '2026-08-02';
DECLARE @AfterStart DATETIME = '2026-08-02';
DECLARE @AfterEnd DATETIME = '2026-08-04';
DECLARE @TopCount int = 10;

WITH BaselineTopQueries
AS (
	SELECT TOP(@TopCount) qsq.query_hash
		,qsq.query_id
		,LEFT(qsqt.query_sql_text, 500) AS query_sql_text
		,SUM(qsrs.avg_cpu_time) AS avg_cpu_time_baseline
		,SUM(qsrs.count_executions) AS ExecutionCount
	FROM sys.query_store_query qsq
	JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id
	JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id
	JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id = qsrsi.runtime_stats_interval_id
	JOIN sys.query_store_query_text qsqt ON qsq.query_text_id = qsqt.query_text_id
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
	SELECT qsq.query_hash
		,qsq.query_id
		,LEFT(qsqt.query_sql_text, 500) AS query_sql_text
		,SUM(qsrs.avg_cpu_time) AS avg_cpu_time_later
		,SUM(qsrs.count_executions) AS ExecutionCount
	FROM sys.query_store_query qsq
	JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id
	JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id
	JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id = qsrsi.runtime_stats_interval_id
	JOIN sys.query_store_query_text qsqt ON qsq.query_text_id = qsqt.query_text_id
	WHERE qsrsi.start_time >= @AfterStart
		AND qsrsi.end_time < @AfterEnd
		AND qsq.query_id IN (
			SELECT query_id
			FROM BaselineTopQueries
			)
	GROUP BY qsq.query_hash
		,qsq.query_id
		,qsqt.query_sql_text

	)
--Final output: Compare early vs. late CPU average usage
SELECT BTQ.query_hash
	,BTQ.query_id
	,BTQ.query_sql_text
    ,BTQ.ExecutionCount AS BaselineExecutioncount
    ,l.Executioncount AS LaterExecutionCount
	,BTQ.avg_cpu_time_baseline
	,l.avg_cpu_time_later
	,(ISNULL(l.avg_cpu_time_later, 0) - BTQ.avg_cpu_time_baseline) AS cpu_change
FROM BaselineTopQueries AS BTQ
LEFT JOIN LaterCpuStats l ON BTQ.query_id = l.query_id
ORDER BY BTQ.avg_cpu_time_baseline DESC;

/*********************************/
--First CTE: Get top 10 intensive queries by avg_logical_io_reads from before the migration
WITH BaselineTopQueries
AS (
	SELECT TOP(@TopCount) qsq.query_hash
		,qsq.query_id
		,LEFT(qsqt.query_sql_text, 500) AS query_sql_text
		,SUM(qsrs.avg_logical_io_reads) AS avg_logical_io_reads_baseline
		,SUM(qsrs.count_executions) AS ExecutionCount
	FROM sys.query_store_query qsq
	JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id
	JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id
	JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id = qsrsi.runtime_stats_interval_id
	JOIN sys.query_store_query_text qsqt ON qsq.query_text_id = qsqt.query_text_id
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
	SELECT qsq.query_hash
        ,qsq.query_id
		,LEFT(qsqt.query_sql_text, 500) AS query_sql_text
		,SUM(qsrs.avg_logical_io_reads) AS avg_logical_io_reads_later
		,SUM(qsrs.count_executions) AS ExecutionCount
	FROM sys.query_store_query qsq
	JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id
	JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id
	JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id = qsrsi.runtime_stats_interval_id
	JOIN sys.query_store_query_text qsqt ON qsq.query_text_id = qsqt.query_text_id
	WHERE qsrsi.start_time >= @AfterStart
		AND qsrsi.end_time < @AfterEnd
		AND qsq.query_id IN (
			SELECT query_id
			FROM BaselineTopQueries
			)
	GROUP BY qsq.query_hash
		,qsq.query_id
		,qsqt.query_sql_text
	)
--Final output: Compare early vs. late stats
SELECT BTQ.query_hash
	,BTQ.query_id
	,BTQ.query_sql_text
    ,BTQ.ExecutionCount AS BaselineExecutioncount
    ,l.Executioncount AS LaterExecutionCount
	,BTQ.avg_logical_io_reads_baseline
	,l.avg_logical_io_reads_later
	,(ISNULL(l.avg_logical_io_reads_later, 0) - BTQ.avg_logical_io_reads_baseline) AS avg_logical_io_reads_change
FROM BaselineTopQueries AS BTQ
LEFT JOIN LaterStats l ON BTQ.query_id = l.query_id
ORDER BY BTQ.avg_logical_io_reads_baseline DESC;

--First CTE: Get top 10 intensive queries by avg_logical_io_writes from before the migration
WITH BaselineTopQueries
AS (
	SELECT TOP(@TopCount) qsq.query_hash
		,qsq.query_id
		,LEFT(qsqt.query_sql_text, 500) AS query_sql_text
		,SUM(qsrs.avg_logical_io_writes) AS avg_logical_io_writes_baseline
		,SUM(qsrs.count_executions) AS ExecutionCount
	FROM sys.query_store_query qsq
	JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id
	JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id
	JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id = qsrsi.runtime_stats_interval_id
	JOIN sys.query_store_query_text qsqt ON qsq.query_text_id = qsqt.query_text_id
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
	SELECT qsq.query_hash
        ,qsq.query_id
		,LEFT(qsqt.query_sql_text, 500) AS query_sql_text
		,SUM(qsrs.avg_logical_io_writes) AS avg_logical_io_writes_later
		,SUM(qsrs.count_executions) AS ExecutionCount
	FROM sys.query_store_query qsq
	JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id
	JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id
	JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id = qsrsi.runtime_stats_interval_id
	JOIN sys.query_store_query_text qsqt ON qsq.query_text_id = qsqt.query_text_id
	WHERE qsrsi.start_time >= @AfterStart
		AND qsrsi.end_time < @AfterEnd
		AND qsq.query_id IN (
			SELECT query_id
			FROM BaselineTopQueries
			)
	GROUP BY qsq.query_hash
		,qsq.query_id
		,qsqt.query_sql_text
	)
--Final output: Compare early vs. late stats
SELECT BTQ.query_hash
	,BTQ.query_id
	,BTQ.query_sql_text
    ,BTQ.ExecutionCount AS BaselineExecutioncount
    ,l.Executioncount AS LaterExecutionCount
	,BTQ.avg_logical_io_writes_baseline
	,l.avg_logical_io_writes_later
	,(ISNULL(l.avg_logical_io_writes_later, 0) - BTQ.avg_logical_io_writes_baseline) AS avg_logical_io_writes_change
FROM BaselineTopQueries AS BTQ
LEFT JOIN LaterStats l ON BTQ.query_id = l.query_id
ORDER BY BTQ.avg_logical_io_writes_baseline DESC;

--First CTE: Get top 10 intensive queries by avg_query_max_used_memory from before the migration
WITH BaselineTopQueries
AS (
	SELECT TOP(@TopCount) qsq.query_hash
		,qsq.query_id
		,LEFT(qsqt.query_sql_text, 500) AS query_sql_text
		,SUM(qsrs.avg_query_max_used_memory) AS avg_query_max_used_memory_baseline
		,SUM(qsrs.count_executions) AS ExecutionCount
	FROM sys.query_store_query qsq
	JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id
	JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id
	JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id = qsrsi.runtime_stats_interval_id
	JOIN sys.query_store_query_text qsqt ON qsq.query_text_id = qsqt.query_text_id
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
	SELECT qsq.query_hash
        ,qsq.query_id
		,LEFT(qsqt.query_sql_text, 500) AS query_sql_text
		,SUM(qsrs.avg_query_max_used_memory) AS avg_query_max_used_memory_later
		,SUM(qsrs.count_executions) AS ExecutionCount
	FROM sys.query_store_query qsq
	JOIN sys.query_store_plan qspt ON qsq.query_id = qspt.query_id
	JOIN sys.query_store_runtime_stats qsrs ON qspt.plan_id = qsrs.plan_id
	JOIN sys.query_store_runtime_stats_interval qsrsi ON qsrs.runtime_stats_interval_id = qsrsi.runtime_stats_interval_id
	JOIN sys.query_store_query_text qsqt ON qsq.query_text_id = qsqt.query_text_id
	WHERE qsrsi.start_time >= @AfterStart
		AND qsrsi.end_time < @AfterEnd
		AND qsq.query_id IN (
			SELECT query_id
			FROM BaselineTopQueries
			)
	GROUP BY qsq.query_hash
		,qsq.query_id
		,qsqt.query_sql_text
	)
--Final output: Compare early vs. late stats
SELECT BTQ.query_hash
	,BTQ.query_id
	,BTQ.query_sql_text
    ,BTQ.ExecutionCount AS BaselineExecutioncount
    ,l.Executioncount AS LaterExecutionCount
	,BTQ.avg_query_max_used_memory_baseline
	,l.avg_query_max_used_memory_later
	,(ISNULL(l.avg_query_max_used_memory_later, 0) - BTQ.avg_query_max_used_memory_baseline) AS avg_query_max_used_memory_change
FROM BaselineTopQueries AS BTQ
LEFT JOIN LaterStats l ON BTQ.query_id = l.query_id
ORDER BY BTQ.avg_query_max_used_memory_baseline DESC;

 
