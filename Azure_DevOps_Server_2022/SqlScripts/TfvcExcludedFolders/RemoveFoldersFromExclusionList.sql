/** 
    This sql script removes folders from Tfvc indexing exclusion list. It fetches the existing ones, finds if any of the proveded one exists, and deletes them.
    Any folders provided but not present already in exclusion list are ignored.
**/

DECLARE @CollectionId UNIQUEIDENTIFIER = $(CollectionId)
DECLARE @FolderPathsToRemove NVARCHAR(MAX) = $(FolderPaths)
DECLARE @ErrorMessage NVARCHAR(MAX)

IF (@FolderPathsToRemove is NULL)
    BEGIN
	    RAISERROR('FolderPaths cannot be null', 16, -1, 'RemoveFoldersFromExclusionList', 0);
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

DECLARE @DeleteFoldersTable TABLE (
    FolderPath    nvarchar(max) NOT NULL
)
DECLARE @ExistingFoldersTable TABLE (
    FolderPath    nvarchar(max) NOT NULL
)

INSERT into @DeleteFoldersTable SELECT value FROM string_split(@FolderPathsToRemove, ',')
INSERT into @ExistingFoldersTable SELECT value FROM string_split(@ExistingPaths, ',')

DELETE @ExistingFoldersTable FROM @ExistingFoldersTable A
INNER JOIN @DeleteFoldersTable B on A.FolderPath = B.FolderPath


DECLARE @NewFolderPaths NVARCHAR(MAX) = ''
SELECT @NewFolderPaths = @NewFolderPaths + FolderPath + ',' FROM @ExistingFoldersTable
SET @NewFolderPaths = SUBSTRING(@NewFolderPaths, 0, LEN(@NewFolderPaths))
	
DECLARE @features [dbo].[typ_KeyValuePairStringTableNullable]
INSERT INTO @features values('#\Service\ALMSearch\Settings\TfvcFolderPathsExcludedFromIndexing\', @NewFolderPaths)
EXEC prc_UpdateRegistry @partitionId = @PartitionID, @identityName = '00000000-0000-0000-0000-000000000000', @registryUpdates = @features