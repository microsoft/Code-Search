/**
This script cleans up all the tables/entries which has the state of indexing of the WorkItem indexing units of the Collection. 
**/
DELETE FROM [Search].[tbl_ResourceLockTable]
WHERE LeaseId in
(SELECT Distinct(LeaseId) from [Search].[tbl_IndexingUnitChangeEvent]
	WHERE IndexingUnitId in 
	(
		SELECT IndexingUnitId FROM [Search].[tbl_IndexingUnit] WHERE EntityType = 'WorkItem'
	)
)

DELETE FROM [Search].[tbl_IndexingUnitChangeEvent]
	WHERE IndexingUnitId in 
	(
		SELECT IndexingUnitId FROM [Search].[tbl_IndexingUnit] WHERE EntityType = 'WorkItem'
	)

DELETE FROM [Search].[tbl_JobYield]

DELETE FROM [Search].[tbl_TreeStore]

DELETE FROM [Search].[tbl_ResourceLockTable] 
