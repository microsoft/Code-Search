--**UPDATE** Please enter the Collection id and Days
/*
This script gets the number of Indexing operations failed in the given date range.
*/
Declare @CollectionId uniqueidentifier = $(CollectionID);
Declare @Days int = $(DaysAgo);

SELECT Count(Id) AS FailedIndexingCount
		FROM Search.tbl_IndexingUnitChangeEvent AS IUCE join
		Search.tbl_IndexingUnit as IU ON IU.IndexingUnitId = IUCE.IndexingUnitId and IU.PartitionId = IUCE.PartitionId
		where IUCE.ChangeType = 'BeginBulkIndex' AND IUCE.State = 'Failed'
		AND IU.IndexingUnitType = 'Git_Repository'
		AND IU.EntityType = 'Wiki'
		AND IU.PartitionId = (Select PartitionId from dbo.tbl_DatabasePartitionMap where ServiceHostId = @CollectionId)
        AND IUCE.CreatedTimeUTC > DATEADD(DAY, -@Days, GETUTCDATE())