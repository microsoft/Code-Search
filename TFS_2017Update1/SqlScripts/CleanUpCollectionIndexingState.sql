-- This script cleans up all the tables/entries which has the indexing state of given entity type and given collection in collection database.

Declare @CollectionId uniqueidentifier = $(CollectionID);
Declare @EntityTypeString VARCHAR(32) = $(EntityTypeString);
Declare @EntityTypeInt TINYINT = $(EntityTypeInt);

DECLARE @partitionID VARCHAR(50)
SELECT @partitionID = PartitionID FROM [dbo].[tbl_DatabasePartitionMap] WHERE ServiceHostId = @CollectionId

IF (OBJECT_ID(N'Search.tbl_ResourceLockTable') IS NOT NULL)
BEGIN
    DELETE FROM [Search].[tbl_ResourceLockTable]
        WHERE LeaseId IN (
            SELECT DISTINCT(IUCE.LeaseId) FROM [Search].[tbl_IndexingUnitChangeEvent] IUCE INNER JOIN [Search].[tbl_IndexingUnit] IU
                ON IUCE.IndexingUnitId = IU.IndexingUnitId AND IU.EntityType = @EntityTypeString AND IUCE.PartitionId = @partitionID)
            AND PartitionId = @partitionID
END

DELETE IUCE FROM [Search].[tbl_IndexingUnitChangeEvent] IUCE INNER JOIN [Search].[tbl_IndexingUnit] IU ON IUCE.IndexingUnitId = IU.IndexingUnitId AND IU.EntityType = @EntityTypeString AND IUCE.PartitionId = @partitionID

IF (OBJECT_ID(N'Search.tbl_ItemLevelFailures') IS NOT NULL)
BEGIN
    DELETE ILF FROM [Search].[tbl_ItemLevelFailures] ILF INNER JOIN [Search].[tbl_IndexingUnit] IU ON ILF.IndexingUnitId = IU.IndexingUnitId AND IU.EntityType = @EntityTypeString AND ILF.PartitionId = @partitionID
END

IF (OBJECT_ID(N'Search.tbl_IndexingUnitIndexingInformation') IS NOT NULL)
BEGIN
    DELETE FROM [Search].[tbl_IndexingUnitIndexingInformation] WHERE EntityType = @EntityTypeInt AND PartitionId = @partitionID
END

IF (OBJECT_ID(N'Search.tbl_JobYield') IS NOT NULL)
BEGIN
    DELETE FROM [Search].[tbl_JobYield] WHERE EntityType = @EntityTypeString AND PartitionId = @partitionID
END

IF (OBJECT_ID(N'Search.tbl_TreeStore') IS NOT NULL)
BEGIN
    DELETE FROM [Search].[tbl_TreeStore] WHERE EntityType = @EntityTypeString AND PartitionId = @partitionID
END

IF (@EntityTypeString = 'Code')
BEGIN
    IF (OBJECT_ID(N'Search.tbl_CustomRepositoryInfo') IS NOT NULL)
    BEGIN
        DELETE FROM [Search].[tbl_CustomRepositoryInfo] WHERE PartitionId = @partitionID
    END
    
    IF (OBJECT_ID(N'Search.tbl_DisabledFiles') IS NOT NULL)
    BEGIN
        DELETE FROM [Search].[tbl_DisabledFiles] WHERE PartitionId = @partitionID
    END
    
    IF (OBJECT_ID(N'Search.tbl_FileMetadataStore') IS NOT NULL)
    BEGIN
        DELETE FROM [Search].[tbl_FileMetadataStore] WHERE PartitionId = @partitionID
    END
    
    IF (OBJECT_ID(N'Search.tbl_TempFileMetadataStore') IS NOT NULL)
    BEGIN
        DELETE FROM [Search].[tbl_TempFileMetadataStore] WHERE PartitionId = @partitionID
    END
END

IF (@EntityTypeString = 'Wiki')
BEGIN
    IF (OBJECT_ID(N'Search.tbl_IndexingUnitWikis') IS NOT NULL)
    BEGIN
        DELETE FROM [Search].[tbl_IndexingUnitWikis] WHERE PartitionId = @partitionID
    END
END

IF (@EntityTypeString = 'WorkItem')
BEGIN
    IF (OBJECT_ID(N'Search.tbl_ClassificationNode') IS NOT NULL)
    BEGIN
        DELETE FROM [Search].[tbl_ClassificationNode] WHERE PartitionId = @partitionID
    END
END

DELETE FROM [Search].[tbl_IndexingUnit] WHERE EntityType = @EntityTypeString AND PartitionId = @partitionID

DECLARE @UninstallInProgressRegKey VARCHAR(MAX) = '#\Service\ALMSearch\Settings\IsExtensionOperationInProgress\' + @EntityTypeString + '\Uninstalled\';
EXEC prc_SetRegistryValue @partitionID, @UninstallInProgressRegKey, @value = NULL

DECLARE @InstallInProgressRegKey VARCHAR(MAX) = '#\Service\ALMSearch\Settings\IsExtensionOperationInProgress\' + @EntityTypeString + '\Installed\';
EXEC prc_SetRegistryValue @partitionID, @InstallInProgressRegKey, @value = NULL
