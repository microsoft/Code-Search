--**UPDATE** Please enter the Collection id and Days
/*
This script gets the number of repositories for which the Fresh Indexing(new repository) has already completed in the give date range.
*/
Declare @CollectionId uniqueidentifier = $(CollectionID);
Declare @Days int = $(DaysAgo);

select Count(DISTINCT(TfsEntityId)) as IndexingCompletedCount from Search.tbl_IndexingUnit as IU join
	Search.tbl_IndexingUnitChangeEvent  as IUCE ON IU.IndexingUnitId = IUCE.IndexingUnitId and IU.PartitionId = IUCE.PartitionId
    where IU.EntityType = 'Wiki'
        and IU.IndexingUnitType = 'Git_Repository'
        and IUCE.CreatedTimeUTC > DATEADD(DAY, -@Days, GETUTCDATE())
        and IUCE.State = 'Succeeded'
        and IU.PartitionId = (Select PartitionId from dbo.tbl_DatabasePartitionMap where ServiceHostId = @CollectionId)