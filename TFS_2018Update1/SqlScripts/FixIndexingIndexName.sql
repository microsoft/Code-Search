/**
	This script fixes the index name in all repo indexing units (if the same is not available).
	Database: Partition database
	Parameter: Collection Id 
**/
DECLARE @CollectionId UNIQUEIDENTIFIER = $(CollectionId)

-- Get the partition Id associated with collection
DECLARE @PartitionId INT
SELECT @PartitionId = [PartitionId]
FROM [tbl_DatabasePartitionMap]
WHERE ServiceHostId = @CollectionId

-- Get the index name associated with collection
DECLARE @IndexingIndexName NVARCHAR(MAX)
SELECT @IndexingIndexName = CAST(
	props.query(
		'declare namespace NS1="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
		 declare namespace NS2="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common";
		/NS1:IndexingProperties/NS1:IndexIndices/NS2:IndexInfo/NS2:IndexName/text()') AS NVARCHAR(MAX)
	)
FROM 
    (
        SELECT CAST(Properties AS xml) AS props
        FROM Search.tbl_IndexingUnit
        WHERE IndexingUnitType = 'Collection' AND EntityType = 'Code'
		      AND PartitionId = @PartitionId
    ) a 

-- Update all repo indexing properties with index name retrieved from collection
DECLARE @IndexingIndexNameInfo NVARCHAR(MAX) = CONCAT('<a:IndexName>', @IndexingIndexName, '</a:IndexName>')
UPDATE Search.tbl_IndexingUnit
SET Properties = REPLACE(Properties, '<a:IndexName i:nil="true"/>', @IndexingIndexNameInfo)
WHERE (IndexingUnitType = 'Git_Repository' OR IndexingUnitType = 'TFVC_Repository')  AND EntityType = 'Code'
      AND PartitionId = @PartitionId