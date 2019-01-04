/** 
    This sql script deletes all folders present in exclusion list.
**/

DECLARE @CollectionId UNIQUEIDENTIFIER = $(CollectionId)
DECLARE @ErrorMessage NVARCHAR(MAX)

DECLARE @PartitionID INT
SELECT @PartitionID = PartitionId FROM [dbo].[tbl_DatabasePartitionMap] WHERE ServiceHostId = @CollectionId
IF(@PartitionID <= 0 OR @PartitionID is NULL)
    BEGIN
	    SELECT @ErrorMessage = FORMATMESSAGE('Invalid value of PartitionId: %d for Collection ID ''%s''.', @PartitionID, CONVERT(NVARCHAR(50), @CollectionId))
	    RAISERROR(@ErrorMessage, 16, -1, 'AddFoldersInExclusionList', 0);
	    RETURN
    END

DECLARE @features [dbo].[typ_KeyValuePairStringTableNullable]
INSERT INTO @features values('#\Service\ALMSearch\Settings\TfvcFolderPathsExcludedFromIndexing\', NULL)
EXEC prc_UpdateRegistry @partitionId = @PartitionID, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @features