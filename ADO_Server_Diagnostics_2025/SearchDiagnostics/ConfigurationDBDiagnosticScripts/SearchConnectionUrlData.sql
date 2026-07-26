/*
This script gets the configured Search (Elasticsearch) connection URL string.
*/

SELECT ParentPath, ChildItem, RegValue
FROM tbl_RegistryItems
where PartitionId > 0 and 
ChildItem like '%SearchPlatformConnectionString%'