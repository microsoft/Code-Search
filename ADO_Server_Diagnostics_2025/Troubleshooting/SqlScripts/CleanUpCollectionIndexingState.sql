-- This script cleans up all the tables/entries which has the indexing state of given entity type and given collection in collection database.

Declare @CollectionId UNIQUEIDENTIFIER = $(CollectionID);
Declare @EntityTypeString VARCHAR(32) = $(EntityTypeString);
Declare @EntityTypeInt TINYINT = $(EntityTypeInt);

IF (OBJECT_ID(N'Search.tbl_ResourceLockTable') IS NOT NULL)
BEGIN
    DELETE FROM Search.tbl_ResourceLockTable
        WHERE LeaseId IN (
            SELECT DISTINCT(IUCE.LeaseId) FROM Search.tbl_IndexingUnitChangeEvent IUCE INNER JOIN Search.tbl_IndexingUnit IU
                ON IUCE.IndexingUnitId = IU.IndexingUnitId AND IU.EntityType = @EntityTypeString AND IUCE.PartitionId = 1)
            AND PartitionId = 1
END

-- Delete indexing unit change events corresponding to indexing units of the given entity type
DELETE IUCE FROM Search.tbl_IndexingUnitChangeEvent IUCE INNER JOIN Search.tbl_IndexingUnit IU ON IUCE.IndexingUnitId = IU.IndexingUnitId AND IU.EntityType = @EntityTypeString AND IUCE.PartitionId = 1

-- Delete orphan indexing unit change events
DELETE IUCE FROM Search.tbl_IndexingUnitChangeEvent IUCE LEFT JOIN Search.tbl_IndexingUnit IU ON IUCE.IndexingUnitId = IU.IndexingUnitId WHERE IU.IndexingUnitId IS NULL AND IUCE.PartitionId = 1

IF (OBJECT_ID(N'Search.tbl_ItemLevelFailures') IS NOT NULL)
BEGIN
    DELETE ILF FROM Search.tbl_ItemLevelFailures ILF INNER JOIN Search.tbl_IndexingUnit IU ON ILF.IndexingUnitId = IU.IndexingUnitId AND IU.EntityType = @EntityTypeString AND ILF.PartitionId = 1
END

IF (OBJECT_ID(N'Search.tbl_IndexingUnitIndexingInformation') IS NOT NULL)
BEGIN
    DELETE FROM Search.tbl_IndexingUnitIndexingInformation WHERE EntityType = @EntityTypeInt AND PartitionId = 1
END

IF (OBJECT_ID(N'Search.tbl_JobYield') IS NOT NULL)
BEGIN
    DELETE FROM Search.tbl_JobYield WHERE EntityType = @EntityTypeString AND PartitionId = 1
END

IF (OBJECT_ID(N'Search.tbl_TreeStore') IS NOT NULL)
BEGIN
    DELETE FROM Search.tbl_TreeStore WHERE EntityType = @EntityTypeString AND PartitionId = 1
END

IF (@EntityTypeString = 'Code')
BEGIN
    IF (OBJECT_ID(N'Search.tbl_CustomRepositoryInfo') IS NOT NULL)
    BEGIN
        DELETE FROM Search.tbl_CustomRepositoryInfo WHERE PartitionId = 1
    END
    
    IF (OBJECT_ID(N'Search.tbl_DisabledFiles') IS NOT NULL)
    BEGIN
        DELETE FROM Search.tbl_DisabledFiles WHERE PartitionId = 1
    END
    
    IF (OBJECT_ID(N'Search.tbl_FileMetadataStore') IS NOT NULL)
    BEGIN
        DELETE FROM Search.tbl_FileMetadataStore WHERE PartitionId = 1
    END
    
    IF (OBJECT_ID(N'Search.tbl_TempFileMetadataStore') IS NOT NULL)
    BEGIN
        DELETE FROM Search.tbl_TempFileMetadataStore WHERE PartitionId = 1
    END
END

IF (@EntityTypeString = 'Wiki')
BEGIN
    IF (OBJECT_ID(N'Search.tbl_IndexingUnitWikis') IS NOT NULL)
    BEGIN
        DELETE FROM Search.tbl_IndexingUnitWikis WHERE PartitionId = 1
    END
END

IF (@EntityTypeString = 'WorkItem')
BEGIN
    IF (OBJECT_ID(N'Search.tbl_ClassificationNode') IS NOT NULL)
    BEGIN
        DELETE FROM Search.tbl_ClassificationNode WHERE PartitionId = 1
    END
END

DELETE FROM Search.tbl_IndexingUnit WHERE EntityType = @EntityTypeString AND PartitionId = 1