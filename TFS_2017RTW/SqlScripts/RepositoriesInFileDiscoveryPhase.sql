/*
Gets the count of repositories still in File Discovery phase
*/


SELECT  TS.TFSEntityId, (Count(*)*500) as MaxFilesDiscovered
	 FROM Search.tbl_TreeStore as TS join
	(SELECT Distinct(TfsEntityId) as RepositoryInFileDiscoveryPhase
		FROM Search.tbl_IndexingUnit as IU join
		Search.tbl_IndexingUnitChangeEvent  as IUCE
		on IU.IndexingUnitId = IUCE.IndexingUnitId
		WHERE IUCE.ChangeType = 'BulkTreeCrawl' and IUCE.State in ('InProgress', 'Pending', 'Queued')) as RepositoriesInFileDiscoveryPhase
		on TS.TFSEntityId = RepositoriesInFileDiscoveryPhase.RepositoryInFileDiscoveryPhase
		group by TS.TFSEntityId
