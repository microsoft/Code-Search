--**UPDATE** Please enter the Collection id and Days
/*
This script gets the number of repositories for which the bulk indexing of a git/tfvc repository is in Progress.
*/
SELECT Count(TfsEntityId) AS BulkIndexingInProgressCount
		FROM Search.tbl_IndexingUnit AS IU join 
		Search.tbl_IndexingUnitChangeEvent  as IUCE ON IU.IndexingUnitId = IUCE.IndexingUnitId and IU.PartitionId = IUCE.PartitionId
		where IUCE.ChangeType = 'BeginBulkIndex' AND IUCE.State in ('InProgress', 'Pending', 'Queued', 'FailedAndRetry')
		AND IU.IndexingUnitType IN ('TFVC_Repository', 'Git_Repository')
		AND IU.EntityType = 'Code'
	    AND ((IndexingUnitType = 'Git_Repository'
			AND CAST(Properties AS xml).exist('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
			declare namespace AS="http://schemas.microsoft.com/2003/10/Serialization/Arrays";
					  (/NS:IndexingProperties/NS:BranchIndexInfo/AS:KeyValueOfstringGitBranchIndexInfoRWfTSrgf/AS:Value/NS:LastIndexedCommitId[text() = "0000000000000000000000000000000000000000"])') = 1)
		   OR (IndexingUnitType = 'TFVC_Repository'
			   AND CAST(Properties AS xml).exist('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
			declare namespace AS="http://schemas.microsoft.com/2003/10/Serialization/Arrays";
					  (/NS:IndexingProperties/NS:LastIndexedChangeSetId[text() = "-1"])') = 1) )
