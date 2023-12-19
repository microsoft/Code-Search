/*
This script gets the Search related registry settings from Collection DB.
*/

SELECT ParentPath, ChildItem, RegValue
FROM tbl_RegistryItems
where PartitionId > 0 and 
ParentPath like '%Search%'
