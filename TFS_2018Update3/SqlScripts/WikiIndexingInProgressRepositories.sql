--**UPDATE** Please enter the Collection id
/*
Gets the list of repositories for which indexing is in progress.
*/
Declare @CollectionId uniqueidentifier = $(CollectionID);

SELECT DISTINCT(TfsEntityId), substring(IU.TfsEntityAttributes, CHARINDEX('<RepositoryName>', TFSEntityAttributes) + 16,
 (CHARINDEX('</RepositoryName>', TFSEntityAttributes) - (CHARINDEX('<RepositoryName>', TFSEntityAttributes) + 16)))  as RepositoryIndexingInProgress
		FROM Search.tbl_IndexingUnit AS IU join 
		Search.tbl_IndexingUnitChangeEvent  as IUCE ON IU.IndexingUnitId = IUCE.IndexingUnitId and IU.PartitionId = IUCE.PartitionId
		where IUCE.ChangeType = 'BeginBulkIndex' AND IUCE.State in ('InProgress', 'Pending', 'Queued', 'FailedAndRetry')
		AND IU.IndexingUnitType = 'Git_Repository'
		AND IU.EntityType = 'Wiki'
		AND IU.PartitionId = (Select PartitionId from dbo.tbl_DatabasePartitionMap where ServiceHostId = @CollectionId)