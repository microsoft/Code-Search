/*
This script gets the Search related registry settings from Collection DB.
*/

SELECT *
FROM tbl_RegistryItems
where PartitionId > 0 and 
ParentPath like '%Search%'
