/*
This script gets the Search related registry settings.
*/

SELECT ParentPath, ChildItem, RegValue
FROM tbl_RegistryItems
where PartitionId > 0 and 
ParentPath like '%Search%'