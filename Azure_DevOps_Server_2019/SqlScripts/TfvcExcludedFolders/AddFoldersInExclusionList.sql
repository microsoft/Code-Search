/** 
    This sql script adds Tfvc folders to exclusion list. It fetches the existing ones, if any, and merges both.
    Any files present inside these folders won't get indexed.
**/

DECLARE @CollectionId UNIQUEIDENTIFIER = $(CollectionId)
DECLARE @FolderPaths NVARCHAR(MAX) = $(FolderPaths)
DECLARE @ErrorMessage NVARCHAR(MAX)

IF (@FolderPaths is NULL)
    BEGIN
	    RAISERROR('FolderPaths cannot be null', 16, -1, 'AddFoldersInExclusionList', 0);
	    RETURN
    END

DECLARE @PartitionID INT
SELECT @PartitionID = PartitionId FROM [dbo].[tbl_DatabasePartitionMap] WHERE ServiceHostId = @CollectionId
IF(@PartitionID <= 0 OR @PartitionID is NULL)
    BEGIN
	    SELECT @ErrorMessage = FORMATMESSAGE('Invalid value of PartitionId: %d for Collection ID ''%s''.', @PartitionID, CONVERT(NVARCHAR(50), @CollectionId))
	    RAISERROR(@ErrorMessage, 16, -1, 'AddFoldersInExclusionList', 0);
	    RETURN
    END


DECLARE @ExistingPaths NVARCHAR(MAX)
SELECT  @ExistingPaths = RegValue FROM [dbo].[tbl_RegistryItems] WHERE ParentPath = '#\Service\ALMSearch\Settings\' AND ChildItem = 'TfvcFolderPathsExcludedFromIndexing\' AND PartitionId = @PartitionID

DECLARE @NewFolderPaths NVARCHAR(MAX)
IF(@ExistingPaths is NULL)
	BEGIN
	SET @NewFolderPaths = @FolderPaths
	END
ELSE
	BEGIN
	SET @NewFolderPaths = @ExistingPaths + ',' + @FolderPaths
	END
	
DECLARE @features [dbo].[typ_KeyValuePairStringTableNullable]
INSERT INTO @features values('#\Service\ALMSearch\Settings\TfvcFolderPathsExcludedFromIndexing\', @NewFolderPaths)
EXEC prc_UpdateRegistry @partitionId = @PartitionID, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @features