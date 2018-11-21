/**
This script cleans up all the tables/entries which has the state of indexing of the Code indexing units of the Collection. 
**/
DELETE FROM [Search].[tbl_ResourceLockTable]
WHERE LeaseId in
(SELECT Distinct(LeaseId) from [Search].[tbl_IndexingUnitChangeEvent]
	WHERE IndexingUnitId in 
	(
		SELECT IndexingUnitId FROM [Search].[tbl_IndexingUnit] WHERE EntityType = 'Code' and PartitionId > 0
	)
	AND PartitionId > 0
)
AND PartitionId > 0

DELETE FROM [Search].[tbl_IndexingUnitChangeEvent]
	WHERE IndexingUnitId in 
	(
		SELECT IndexingUnitId FROM [Search].[tbl_IndexingUnit] WHERE EntityType = 'Code' and PartitionId > 0
	)
	AND PartitionId > 0

DELETE FROM [Search].[tbl_ItemLevelFailures]
	WHERE IndexingUnitId in 
	(
		SELECT IndexingUnitId FROM [Search].[tbl_IndexingUnit] WHERE EntityType = 'Code' and PartitionId > 0
	)
	AND PartitionId > 0

TRUNCATE TABLE [Search].[tbl_DisabledFiles]
TRUNCATE TABLE [Search].[tbl_JobYield]
DELETE FROM [Search].[tbl_IndexingUnit] WHERE EntityType = 'Code' AND PartitionId > 0
