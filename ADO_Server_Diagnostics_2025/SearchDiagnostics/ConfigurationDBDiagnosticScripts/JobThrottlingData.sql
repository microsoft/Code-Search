/*
This script gets the job throttling settings.
*/

SELECT ParentPath, ChildItem, RegValue
FROM tbl_RegistryItems
where PartitionId > 0 and 
(ChildItem = 'JobQueueControllerCpuHealthJobThrottleCount\' or ChildItem = 'JobQueueControllerCpuHealthThreshold\')