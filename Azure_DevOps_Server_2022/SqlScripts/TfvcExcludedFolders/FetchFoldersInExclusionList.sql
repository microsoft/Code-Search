/** 
    This sql script fetches all folders present in exclusion list. Any files present inside these folders won't get indexed.
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

SELECT RegValue as ExcludedFolders FROM [dbo].[tbl_RegistryItems] WHERE ParentPath = '#\Service\ALMSearch\Settings\' AND ChildItem = 'TfvcFolderPathsExcludedFromIndexing\' AND PartitionId = @PartitionID