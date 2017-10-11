/*
Gets the per repository status of indexing
*/
SELECT DISTINCT(TfsEntityId), substring(TfsEntityAttributes, CHARINDEX('<ProjectName>', TFSEntityAttributes) + 16,
 (CHARINDEX('</ProjectName>', TFSEntityAttributes) - (CHARINDEX('<ProjectName>', TFSEntityAttributes) + 16)))  as ProjectWorkItemIndexingInProgress
		FROM Search.tbl_IndexingUnit as IU join
		Search.tbl_IndexingUnitChangeEvent  as IUCE on IU.IndexingUnitId = IUCE.IndexingUnitId
		where IUCE.ChangeType = 'BeginBulkIndex' and IUCE.ChangeData Like '%<Trigger>AccountFaultIn</Trigger>%' and IUCE.State in ('InProgress', 'Pending', 'Queued')
		and IU.IndexingUnitType = 'Project'
		and IU.EntityType = 'WorkItem'
