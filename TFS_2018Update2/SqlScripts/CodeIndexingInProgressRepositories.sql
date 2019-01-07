/*
This script gets the number of repositories for which the bulk indexing of a git/tfvc repository is in progress.
*/

select cast(cast(RepoAttributes as xml).query(
'declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
declare namespace AS="http://schemas.microsoft.com/2003/10/Serialization/Arrays";
(/NS:TFSEntityAttributes/NS:RepositoryName/text())'
) as nvarchar(max)) as RepositoryName, cast(cast(ProjectAttributes as xml).query(
'declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
declare namespace AS="http://schemas.microsoft.com/2003/10/Serialization/Arrays";
(/NS:TFSEntityAttributes/NS:ProjectName/text())'
) as nvarchar(max)) as ProjectName
from (
select A.TFSEntityAttributes as ProjectAttributes, B.RepoAttributes from
search.tbl_IndexingUnit A
join 
(
select TFSEntityAttributes as RepoAttributes, ParentUnitId, PartitionId
		FROM Search.tbl_IndexingUnit
		where IndexingUnitType IN ('TFVC_Repository', 'Git_Repository')
		AND EntityType = 'Code'
	    AND ((IndexingUnitType = 'Git_Repository'
			AND CAST(Properties AS xml).exist('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
			declare namespace AS="http://schemas.microsoft.com/2003/10/Serialization/Arrays";
					  (/NS:IndexingProperties/NS:BranchIndexInfo/AS:KeyValueOfstringGitBranchIndexInfoRWfTSrgf/AS:Value/NS:LastIndexedCommitId[text() = "0000000000000000000000000000000000000000"])') = 1)
		   OR (IndexingUnitType = 'TFVC_Repository'
			   AND CAST(Properties AS xml).exist('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
			declare namespace AS="http://schemas.microsoft.com/2003/10/Serialization/Arrays";
					  (/NS:IndexingProperties/NS:LastIndexedChangeSetId[text() = "-1"])') = 1) )) B
on A.PartitionId = B.PartitionId
and A.IndexingUnitId = B.ParentUnitId
) C