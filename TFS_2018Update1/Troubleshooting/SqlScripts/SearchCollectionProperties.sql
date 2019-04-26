/*
This script gets the Search URL from the Collection IU's  properties column for given entity
*/

DECLARE @CollectionId UNIQUEIDENTIFIER = $(CollectionId)
DECLARE @EntityType VARCHAR(32) = $(EntityType)

SELECT EntityType,
    CAST(
    props.query(
        'declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
        /NS:IndexingProperties/NS:IndexESConnectionString/text()') AS NVARCHAR(MAX)
    ) AS IndexESConnectionString,
    CAST(
    props.query(
        'declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
        /NS:IndexingProperties/NS:QueryESConnectionString/text()') AS NVARCHAR(MAX)
    ) AS QueryESConnectionString,
    CAST(
    props.query(
        'declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
        /NS:IndexingProperties/NS:IndexContractType/text()') AS NVARCHAR(MAX)
    ) AS IndexContractType,
    CAST(
    props.query(
        'declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
        /NS:IndexingProperties/NS:QueryContractType/text()') AS NVARCHAR(MAX)
    ) AS QueryContractType
FROM 
    (
        SELECT EntityType, CAST(Properties AS xml) AS props
        FROM Search.tbl_IndexingUnit
        WHERE PartitionId = 1 AND TFSEntityId = @CollectionId AND EntityType = @EntityType AND IsDeleted = 0
    ) a