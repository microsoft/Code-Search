/**
This script cleans up all the tables/entries which has the state of indexing of the Wiki indexing units of the Collection. 
**/
DELETE FROM [Search].[tbl_ResourceLockTable]
WHERE LeaseId in
(SELECT Distinct(LeaseId) from [Search].[tbl_IndexingUnitChangeEvent]
	WHERE IndexingUnitId in 
	(
		SELECT IndexingUnitId FROM [Search].[tbl_IndexingUnit] WHERE EntityType = 'Wiki' AND PartitionId > 0
	) AND  PartitionId > 0
) AND PartitionId > 0

DELETE FROM [Search].[tbl_IndexingUnitChangeEvent]
	WHERE IndexingUnitId in 
	(
		SELECT IndexingUnitId FROM [Search].[tbl_IndexingUnit] WHERE EntityType = 'Wiki' AND PartitionId > 0
	) AND PartitionId > 0

DELETE FROM [Search].[tbl_IndexingUnitWikis]
	WHERE IndexingUnitId in 
	(
		SELECT IndexingUnitId FROM [Search].[tbl_IndexingUnit] WHERE EntityType = 'Wiki' AND PartitionId > 0
	) AND PartitionId > 0

DELETE FROM [Search].[tbl_IndexingUnit] WHERE EntityType = 'Wiki' AND PartitionId > 0
