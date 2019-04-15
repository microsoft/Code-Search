-- This script fetches the indexing pipeline as well as query pipeline index names and routing values of all indexing units of a collection of a given entity type

DECLARE @EntityType VARCHAR(32) = $(EntityType)

SELECT 
    EntityType, 
    IndexingUnitType, 
    TfsEntityId,
    CAST(CAST(Properties AS xml).query('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
    declare namespace NS1="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common";
    /NS:IndexingProperties/NS:IndexIndices/NS1:IndexInfo/NS1:IndexName/text()') AS nvarchar(MAX)) AS IndexingIndexName,
    CAST(CAST(Properties AS xml).query('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
    declare namespace NS1="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common";
    /NS:IndexingProperties/NS:IndexIndices/NS1:IndexInfo/NS1:Routing/text()') AS nvarchar(MAX)) AS IndexingIndexRouting,
    CAST(CAST(Properties AS xml).query('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
    declare namespace NS1="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common";
    /NS:IndexingProperties/NS:QueryIndices/NS1:IndexInfo/NS1:IndexName/text()') AS nvarchar(MAX)) AS QueryIndexName,
    CAST(CAST(Properties AS xml).query('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
    declare namespace NS1="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common";
    /NS:IndexingProperties/NS:QueryIndices/NS1:IndexInfo/NS1:Routing/text()') AS nvarchar(MAX)) AS QueryIndexRouting
FROM Search.tbl_IndexingUnit
WHERE PartitionId = 1 AND EntityType = @EntityType AND AssociatedJobId IS NOT NULL