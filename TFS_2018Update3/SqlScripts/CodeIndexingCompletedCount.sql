/*
This script gets the number of repositories for which the bulk indexing of a git/tfvc repository is completed.
*/
SELECT count(*) as BulkIndexingCompletedCount
		FROM Search.tbl_IndexingUnit
		where IndexingUnitType IN ('TFVC_Repository', 'Git_Repository')
		AND EntityType = 'Code'
	    AND ((IndexingUnitType = 'Git_Repository'
			AND CAST(Properties AS xml).exist('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
			declare namespace AS="http://schemas.microsoft.com/2003/10/Serialization/Arrays";
					  (/NS:IndexingProperties/NS:BranchIndexInfo/AS:KeyValueOfstringGitBranchIndexInfoRWfTSrgf/AS:Value/NS:LastIndexedCommitId[text() = "0000000000000000000000000000000000000000"])') <> 1)
		   OR (IndexingUnitType = 'TFVC_Repository'
			   AND CAST(Properties AS xml).exist('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
			declare namespace AS="http://schemas.microsoft.com/2003/10/Serialization/Arrays";
					  (/NS:IndexingProperties/NS:LastIndexedChangeSetId[text() = "-1"])') <> 1) )
