--**UPDATE** Please enter the Collection id and Days
/*
This script gets the number of Continuous Indexing jobs in progress.
*/

SELECT Count(TfsEntityId) as ContinuousIndexingInProgressCount
		FROM Search.tbl_IndexingUnit as IU join 
		Search.tbl_IndexingUnitChangeEvent  as IUCE on IU.IndexingUnitId = IUCE.IndexingUnitId and IU.PartitionId = IUCE.PartitionId
		where (( IU.IndexingUnitType = 'Git_Repository' and IUCE.ChangeType = 'BeginBulkIndex' and IUCE.ChangeData like '%<Trigger>PushEventNotification</Trigger>%')
				or
			   ( IU.IndexingUnitType = 'TFVC_Repository' and IUCE.ChangeType = 'UpdateIndex'))
		and IUCE.State in ('InProgress', 'Pending', 'Queued', 'FailedAndRetry')
		and IU.EntityType = 'Code'
