/**
This script cleans up all the tables which has the state of indexing for all the indexing units of the Collection.
**/
DELETE FROM [Search].[tbl_IndexingUnit]
DELETE FROM [Search].[tbl_IndexingUnitChangeEvent]
DELETE FROM [Search].[tbl_JobYield]
DELETE FROM [Search].[tbl_TreeStore]
DELETE FROM [Search].[tbl_ResourceLockTable]
