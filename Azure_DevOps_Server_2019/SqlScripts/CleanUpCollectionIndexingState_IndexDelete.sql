/**
This script cleans up all the tables which has the state of indexing for all the indexing units of the Collection. 
**/
TRUNCATE TABLE [Search].[tbl_ClassificationNode]
TRUNCATE TABLE [Search].[tbl_DisabledFiles]
TRUNCATE TABLE [Search].[tbl_IndexingUnit]
TRUNCATE TABLE [Search].[tbl_IndexingUnitIndexingInformation]
TRUNCATE TABLE [Search].[tbl_IndexingUnitChangeEvent]
TRUNCATE TABLE [Search].[tbl_IndexingUnitWikis]
TRUNCATE TABLE [Search].[tbl_ItemLevelFailures]
TRUNCATE TABLE [Search].[tbl_JobYield]
TRUNCATE TABLE [Search].[tbl_ResourceLockTable]
