/**
This script cleans up all the tables which has the state of indexing for all the indexing units of the Collection. 
**/
DELETE FROM [Search].[tbl_IndexingUnit] WHERE PartitionId > 0
DELETE FROM [Search].[tbl_IndexingUnitChangeEvent] WHERE PartitionId > 0
DELETE FROM [Search].[tbl_JobYield] WHERE PartitionId > 0
DELETE FROM [Search].[tbl_TreeStore] WHERE PartitionId > 0
DELETE FROM [Search].[tbl_ResourceLockTable] WHERE PartitionId > 0
