--**UPDATE** Please enter the Collection id and Days
/*
This script gets the number of repositories for which the Fresh Indexing(new repository) is in Progress.
*/
SELECT Count(TfsEntityId) as BulkIndexingInProgressCount
		FROM Search.tbl_IndexingUnit as IU join 
		Search.tbl_IndexingUnitChangeEvent  as IUCE on IU.IndexingUnitId = IUCE.IndexingUnitId
		where IUCE.ChangeData like '%WorkItemBulkIndexEventData%' and IUCE.State in ('InProgress', 'Pending', 'Queued')
		and IU.IndexingUnitType in ('Project')
		and IU.EntityType = 'WorkItem'


