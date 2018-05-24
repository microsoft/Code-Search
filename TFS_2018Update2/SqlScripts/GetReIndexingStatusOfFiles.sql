/** 
    This sql script gets the count of files/folders yet to be indexed in a GIT/TFVC repository.
    The script needs to be executed on the Collection DB of the collection to which the repository belongs to.
    The script takes CollectionId, ProjectName, Repository Name and a path (file or folder). The script will
    check for paths under the given path and report the count.
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
SELECT @RepositoryIndexingUnitId = IndexingUnitId, @IndexingUnitType = IndexingUnitType
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

IF (@IndexingUnitType = @GIT_Repository)
    BEGIN
        -- Replace all '/' by '\' because this is what is being used while indexing Git Repos
	    SELECT @Path = Replace(@Path, '/' , '\')
        IF (RIGHT(@Path, 1) = '\')
            BEGIN
                -- Remove the trailing '\' if present
                SELECT @Path = STUFF(@Path, LEN(@Path), 1, '')
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

SELECT COUNT(1) AS Count FROM Search.tbl_ItemLevelFailures WHERE PartitionId = @PartitionID AND IndexingUnitId = @RepositoryIndexingUnitId AND Item LIKE @Path + '%'

