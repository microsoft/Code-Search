DECLARE @IndexName VARCHAR(500) = $(IndexName);

SELECT TFSEntityId, EntityType, IndexingUnitType, IndexingUnitId, ParentUnitId
FROM Search.tbl_IndexingUnit
WHERE Properties LIKE '%' + @IndexName + '%'
