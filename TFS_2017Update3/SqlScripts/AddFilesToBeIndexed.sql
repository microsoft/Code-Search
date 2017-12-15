/** 
    This sql script adds a file/folder of a GIT/TFVC repository to Search.tbl_ItemLevelFailures.
    The script needs to be executed on the Collection DB of the collection to which the repository belongs to.
**/

DECLARE @RepositoryName NVARCHAR(MAX) = $(RepositoryName)
DECLARE @ProjectName NVARCHAR(MAX) = $(ProjectName)
DECLARE @CollectionId UNIQUEIDENTIFIER = $(CollectionId)
DECLARE @Path NVARCHAR(MAX) = $(Path)
DECLARE @GIT_Repository NVARCHAR(MAX) = 'Git_Repository'
DECLARE @TFVC_Repository NVARCHAR(MAX) = 'TFVC_Repository'
DECLARE @ErrorMessage NVARCHAR(MAX)

DECLARE @PartitionID INT
SELECT @PartitionID = PartitionId FROM [dbo].[tbl_DatabasePartitionMap] WHERE ServiceHostId = @CollectionId

IF (@PartitionID <= 0)
    BEGIN
	    SELECT @ErrorMessage = FORMATMESSAGE('Invalid value of PartitionId: %d for Collection ID ''%s''.', @PartitionId, CONVERT(NVARCHAR(50), @CollectionId))
	    RAISERROR(@ErrorMessage, 16, -1, 'AddFilesToBeIndexed', 0);
	    RETURN
    END

DECLARE @ProjectIndexingUnitId INT
SELECT @ProjectIndexingUnitId = IndexingUnitId 
    FROM Search.tbl_IndexingUnit
    WHERE PartitionId = @PartitionID
        AND EntityType = 'Code'
        AND IndexingUnitType = 'Project'
        AND CAST(TFSEntityAttributes as xml).value('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
                  (/NS:TFSEntityAttributes/NS:ProjectName/text())[1]', 'NVARCHAR(MAX)') = @ProjectName

IF (@ProjectIndexingUnitId IS NULL)
    BEGIN
	    SELECT @ErrorMessage = FORMATMESSAGE('Project ''%s'' is not indexed.', @ProjectName)
	    RAISERROR(@ErrorMessage, 16, -1, 'AddFilesToBeIndexed', 0);
	    RETURN
    END

DECLARE @RepositoryIndexingUnitId INT
DECLARE @IndexingUnitType NVARCHAR(MAX)
DECLARE @TFSEntityAttributes XML
SELECT @RepositoryIndexingUnitId = IndexingUnitId, @IndexingUnitType = IndexingUnitType, @TFSEntityAttributes = CAST(TFSEntityAttributes as XML)
    FROM Search.tbl_IndexingUnit
    WHERE PartitionId = @PartitionID
    AND ParentUnitId = @ProjectIndexingUnitId
    AND TFSEntityAttributes Like '%<RepositoryName>'+@RepositoryName+'</RepositoryName>%'
    AND IndexingUnitType IN (@GIT_Repository, @TFVC_Repository)

IF (@RepositoryIndexingUnitId IS NULL)
    BEGIN
	    SELECT @ErrorMessage = FORMATMESSAGE('Repository ''%s'' is not indexed.', @RepositoryName)
	    RAISERROR(@ErrorMessage, 16, -1, 'AddFilesToBeIndexed', 0);
	    RETURN
    END

DECLARE @BranchName NVARCHAR(MAX) = '';
IF (@IndexingUnitType = @GIT_Repository)
    BEGIN
        -- Replace all '/' by '\' because this is what is being used while indexing Git Repos
	    SELECT @Path = Replace(@Path, '/' , '\')
        IF (RIGHT(@Path, 1) = '\')
            BEGIN
                -- Remove the trailing '\' if present
                SELECT @Path = STUFF(@Path, LEN(@Path), 1, '')
            END
        SELECT @BranchName = @TFSEntityAttributes.value('declare namespace NS="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common.Entities.EntityProperties";
                  (/NS:TFSEntityAttributes/NS:DefaultBranch/text())[1]', 'NVARCHAR(MAX)')
        IF (@BranchName IS NULL OR @BranchName = '')
            BEGIN
                SELECT @ErrorMessage = FORMATMESSAGE('Repository ''%s'' has no default branch, can''t configure any file/folder for re-indexing.', @RepositoryName)
                RAISERROR(@ErrorMessage, 16, -1, 'AddFilesToBeIndexed', 0);
                RETURN
            END
    END
ELSE IF (@IndexingUnitType = @TFVC_Repository)
    BEGIN
        -- Replace all '\' by '/' because this is what is being used while indexing TFVC Repos
	    SELECT @Path = Replace(@Path, '\' , '/')
        IF (RIGHT(@Path, 1) = '/')
            BEGIN
                -- Remove the trailing '/' if present
                SELECT @Path = STUFF(@Path, LEN(@Path), 1, '')
            END        
    END

DECLARE @FailureMetadata NVARCHAR(MAX);
SELECT @FailureMetadata = FORMATMESSAGE('<FailureMetadata xmlns:i="http://www.w3.org/2001/XMLSchema-instance" i:type="FileFailureMetadata"><Branches><BranchName>%s</BranchName></Branches></FailureMetadata>', @BranchName);

DECLARE @FileFailureRecord Search.typ_FileFailureRecord;
INSERT INTO @FileFailureRecord VALUES(@Path, 0, NULL, NULL, @BranchName)
EXEC Search.prc_MergeFileLevelFailures @PartitionID, @RepositoryIndexingUnitId, @FileFailureRecord

DECLARE @ChangeData NVARCHAR(MAX)
SELECT @ChangeData = FORMATMESSAGE('<ChangeEventData i:type="RepositoryPatchEventData" xmlns="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><Trigger>AddPatchOperationCmdLet</Trigger><CorrelationId>%s</CorrelationId><Delay>PT0S</Delay><Patch>ReIndexFailedItems</Patch></ChangeEventData>', CONVERT(NVARCHAR(50), NEWID()))

DECLARE @Prerequisites NVARCHAR(MAX)
SET @Prerequisites = '<IndexingUnitChangeEventPrerequisites i:nil="true" xmlns="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"/>'

DECLARE @ItemList Search.typ_IndexingUnitChangeEventDescriptorV2;
INSERT INTO @ItemList values (@RepositoryIndexingUnitId, 'Patch', @ChangeData, NULL, 'Pending', 0, @Prerequisites, NULL);

EXEC Search.prc_AddEntryForIndexingUnitChangeEvent @PartitionID, @ItemList