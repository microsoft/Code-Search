/**
This script cleans up all the tables/entries which has the state of indexing of the Wiki indexing units of the Collection. 
**/
Declare @CollectionId uniqueidentifier = $(CollectionID);

DECLARE @partitionID varchar(50)
Select @partitionID = PartitionID from [dbo].[tbl_DatabasePartitionMap] where ServiceHostId = @CollectionId

DELETE FROM [Search].[tbl_ResourceLockTable]
WHERE LeaseId in
(SELECT Distinct(LeaseId) from [Search].[tbl_IndexingUnitChangeEvent]
	WHERE IndexingUnitId in 
	(
		SELECT IndexingUnitId FROM [Search].[tbl_IndexingUnit] WHERE EntityType = 'Wiki' AND PartitionId = @partitionID
	) AND  PartitionId = @partitionID
) AND PartitionId = @partitionID

DELETE FROM [Search].[tbl_IndexingUnitChangeEvent]
	WHERE IndexingUnitId in 
	(
		SELECT IndexingUnitId FROM [Search].[tbl_IndexingUnit] WHERE EntityType = 'Wiki' AND PartitionId = (Select PartitionId from dbo.tbl_DatabasePartitionMap where ServiceHostId = @CollectionId)
	) AND PartitionId = @partitionID

DELETE FROM [Search].[tbl_JobYield] WHERE EntityType = 'Wiki' AND PartitionId = @partitionID

DELETE FROM [Search].[tbl_TreeStore] WHERE EntityType = 'Wiki' AND PartitionId = @partitionID
