--**UPDATE** Please enter the Collection id
/*
This script gets the number of repositories for which the indexing of a wiki git repository is in Progress.
*/
Declare @CollectionId uniqueidentifier = $(CollectionID);

SELECT Count(DISTINCT(TfsEntityId)) AS IndexingInProgressCount
		FROM Search.tbl_IndexingUnit AS IU join 
		Search.tbl_IndexingUnitChangeEvent  as IUCE ON IU.IndexingUnitId = IUCE.IndexingUnitId and IU.PartitionId = IUCE.PartitionId
		where IUCE.ChangeType = 'BeginBulkIndex' AND IUCE.State in ('InProgress', 'Pending', 'Queued', 'FailedAndRetry')
		AND IU.IndexingUnitType = 'Git_Repository'
		AND IU.EntityType = 'Wiki'
		AND IU.PartitionId = (Select PartitionId from dbo.tbl_DatabasePartitionMap where ServiceHostId = @CollectionId)