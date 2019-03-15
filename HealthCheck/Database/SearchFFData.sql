/*
This script gets the Search FF states for indexing.
*/

SELECT ParentPath, ChildItem, RegValue
FROM tbl_RegistryItems
where PartitionId > 0 and 
(ParentPath like '%Search.Server.Code.Indexing%' or 
 ParentPath like '%Search.Server.Code.CrudOperations%' or 
 ParentPath like '%Search.Server.WorkItem.Indexing%' or 
 ParentPath like '%Search.Server.WorkItem.CrudOperations%' or 
 ParentPath like '%Search.Server.Wiki.Indexing%' or 
 ParentPath like '%Search.Server.Wiki.ContinuousIndexing%') and 
 ChildItem like '%AvailabilityState%'