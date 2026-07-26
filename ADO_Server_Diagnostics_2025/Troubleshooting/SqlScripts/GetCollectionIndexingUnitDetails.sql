-- This script fetches some information from collection indexing unit for the given entity type

DECLARE @EntityType VARCHAR(32) = $(EntityType)

SELECT 
    TfsEntityId,
    CAST(CAST(Properties AS xml).query('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
    declare namespace NS1="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common";
    /NS:IndexingProperties/NS:IndexIndices/NS1:IndexInfo/NS1:IndexName/text()') AS nvarchar(MAX)) AS IndexingIndexName,
    CAST(CAST(Properties AS xml).query('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
    /NS:IndexingProperties/NS:IndexContractType/text()') AS nvarchar(MAX)) AS IndexContractType,
    CAST(CAST(Properties AS xml).query('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
    declare namespace NS1="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common";
    /NS:IndexingProperties/NS:IndexIndices/NS1:IndexInfo/NS1:Routing/text()') AS nvarchar(MAX)) AS IndexingIndexRouting,
    CAST(CAST(Properties AS xml).query('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
    declare namespace NS1="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common";
    /NS:IndexingProperties/NS:QueryIndices/NS1:IndexInfo/NS1:IndexName/text()') AS nvarchar(MAX)) AS QueryIndexName,
    CAST(CAST(Properties AS xml).query('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
    /NS:IndexingProperties/NS:QueryContractType/text()') AS nvarchar(MAX)) AS QueryContractType,
    CAST(CAST(Properties AS xml).query('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
    declare namespace NS1="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common";
    /NS:IndexingProperties/NS:QueryIndices/NS1:IndexInfo/NS1:Routing/text()') AS nvarchar(MAX)) AS QueryIndexRouting
FROM Search.tbl_IndexingUnit
WHERE EntityType = @EntityType AND IndexingUnitType = 'Collection' AND IsDeleted = 0 AND PartitionId = 1