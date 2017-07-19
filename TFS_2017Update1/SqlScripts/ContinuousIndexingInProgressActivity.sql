--**UPDATE** Please enter the Collection id and Days
/*
This script gets the number of Continuous Indexing jobs completed in the given date range.
*/

SELECT Count(TfsEntityId) as ContinuousIndexingInProgressCount
		FROM Search.tbl_IndexingUnit as IU join
		Search.tbl_IndexingUnitChangeEvent  as IUCE on IU.IndexingUnitId = IUCE.IndexingUnitId
		where IUCE.ChangeType = 'UpdateIndex' and IUCE.State in ('InProgress', 'Pending', 'Queued')
		and IU.IndexingUnitType in ('TFVC_Repository', 'GIT_Repository')
