/*
Gets the per repository status of indexing
*/
SELECT DISTINCT(TfsEntityId), substring(TfsEntityAttributes, CHARINDEX('<RepositoryName>', TFSEntityAttributes) + 16,
 (CHARINDEX('</RepositoryName>', TFSEntityAttributes) - (CHARINDEX('<RepositoryName>', TFSEntityAttributes) + 16)))  as RepositoryIndexingInProgress
		FROM Search.tbl_IndexingUnit as IU join
		Search.tbl_IndexingUnitChangeEvent  as IUCE on IU.IndexingUnitId = IUCE.IndexingUnitId
		where IUCE.ChangeType = 'BeginBulkIndex' and IUCE.ChangeData Like '%<Trigger>AccountFaultIn</Trigger>%' and IUCE.State in ('InProgress', 'Pending', 'Queued')
		and IU.IndexingUnitType in ('Tfvc_Repository', 'Git_Repository')
		and IU.EntityType = 'Code'
