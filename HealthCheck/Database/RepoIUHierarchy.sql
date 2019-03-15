/*
This script validates the IU hierarchy for the repository
*/
DECLARE @RepoName NVARCHAR(MAX) = $(RepoName)

SELECT TOP(1) 
       IUREPO.TFSEntityId
      ,IUREPO.IndexingUnitId AS REPO_IUID
      ,IUREPO.TFSEntityAttributes
      ,IUREPO.Properties
      ,IUREPO.AssociatedJobId
	  ,IUPROJ.IndexingUnitId AS PROJ_IUID
      ,IUPROJ.TFSEntityId AS PROJ_ID
	  ,IUCOL.IndexingUnitId AS COL_IUID
      ,IUCOL.TFSEntityId AS COL_ID
  FROM Search.tbl_IndexingUnit IUREPO
  JOIN Search.tbl_IndexingUnit IUPROJ
  ON IUREPO.PartitionId = IUPROJ.PartitionId
  and IUREPO.EntityType = 'Code'
  and IUREPO.IndexingUnitType = 'Git_Repository'
  and
	CAST(IUREPO.TFSEntityAttributes as xml).value('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
                  (/NS:TFSEntityAttributes/NS:RepositoryName/text())[1]', 'NVARCHAR(MAX)') = @RepoName
  and IUREPO.ParentUnitId = IUPROJ.IndexingUnitId
  and IUPROJ.EntityType = 'Code'
  JOIN Search.tbl_IndexingUnit IUCOL
  ON IUPROJ.PartitionId = IUCOL.PartitionId
  and IUPROJ.ParentUnitId = IUCOL.IndexingUnitId
  and IUCOL.EntityType = 'Code'

 