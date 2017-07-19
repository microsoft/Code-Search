/*
Gets the per repository status of indexing
*/

SELECT  TS.TFSEntityId, (Count(*)*500) as MaxFilesPending
	 FROM Search.tbl_TreeStore as TS join
	(SELECT DISTINCT(TfsEntityId) as RepositoryIndexingInProgress
		FROM Search.tbl_IndexingUnit as IU join
		Search.tbl_IndexingUnitChangeEvent  as IUCE on IU.IndexingUnitId = IUCE.IndexingUnitId
		where IUCE.ChangeType = 'DataCrawl' and IUCE.ChangeData Like '%<Trigger>AccountFaultIn</Trigger>%' and IUCE.State in ('InProgress', 'Pending', 'Queued')) as IndexingInProgressRepositories
	on TS.TFSEntityId = IndexingInProgressRepositories.RepositoryIndexingInProgress
	group by TS.TFSEntityId
