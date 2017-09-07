/** This sql script is to Add the IndexingUnitChangeEvent to Set Indexing State for the repository.
-- The script needs to be executed on the Collection DB of the collection to which the repository belongs to.
-- ** !! POST running this script, please run the "QueuePeriodicMaintenanceJob" script against the Configuration DB. !! **/

DECLARE @RepositoryName nvarchar(max) = $(RepositoryName)
DECLARE @ProjectName nvarchar(max) = $(ProjectName)
DECLARE @CollectionId uniqueidentifier = $(CollectionId)
DECLARE @IndexingState nvarchar(50) = $(IndexingState)

DECLARE @PartitionID int
SELECT @PartitionID = PartitionId from [dbo].[tbl_DatabasePartitionMap] where ServiceHostId = @CollectionId

IF (@PartitionID <= 0)
    BEGIN
	    PRINT N'Not updating Metadata of Repository. Collection not indexed.'
	    RETURN
    END

DECLARE @ProjectIndexingUnitId int
SELECT @ProjectIndexingUnitId = IndexingUnitId from Search.tbl_IndexingUnit
    WHERE PartitionId = @PartitionID
    AND TFSEntityAttributes Like '%<ProjectName>'+@ProjectName+'</ProjectName>%'
    AND IndexingUnitType Like '%Project%'
    AND EntityType Like 'Code'

DECLARE @RepositoryIndexingUnitId int
SELECT @RepositoryIndexingUnitId = IndexingUnitId from Search.tbl_IndexingUnit
    WHERE PartitionId = @PartitionID
    AND ParentUnitId = @ProjectIndexingUnitId
    AND TFSEntityAttributes Like '%<RepositoryName>'+@RepositoryName+'</RepositoryName>%'
    AND IndexingUnitType Like '%Repository%'

IF (@ProjectIndexingUnitId is null OR @RepositoryIndexingUnitId is null)
    BEGIN
	    PRINT N'We dont have this project/repository indexed.'
	    RETURN
    END

DECLARE @DisabledState nvarchar(20)
IF (@IndexingState = 'Off')
    BEGIN
	    SET @DisabledState = 'True'
    END
ELSE IF (@IndexingState = 'On')
    BEGIN
	    SET @DisabledState = 'False'
    END
ELSE
    BEGIN
	    PRINT N'Unknown Indexing State. Please try passing value as "On" or "Off"'
	    RETURN
    END


DECLARE @ChangeData nvarchar(max) = '<ChangeEventData i:type="UpdateMetadataEventData" xmlns="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"><Trigger>None</Trigger><CorrelationId>$CorrelationId</CorrelationId><UpdatedData>$DisabledState</UpdatedData><UpdateType>SetIndexingState</UpdateType></ChangeEventData>'
SET @ChangeData = REPLACE(@ChangeData, '$DisabledState', @DisabledState)
SET @ChangeData = REPLACE(@ChangeData, '$CorrelationId', NEWID())

DECLARE @Prerequisites nvarchar(max)
SET @Prerequisites = '<IndexingUnitChangeEventPrerequisites i:nil="true" xmlns="http://schemas.datacontract.org/2004/07/Microsoft.VisualStudio.Services.Search.Common" xmlns:i="http://www.w3.org/2001/XMLSchema-instance"/>'

DECLARE @ItemList Search.typ_IndexingUnitChangeEventDescriptorV2;
INSERT INTO @ItemList values (@RepositoryIndexingUnitId, 'UpdateMetadata', @ChangeData, NULL, 'Pending', 0, @Prerequisites, NULL);

EXEC Search.prc_AddEntryForIndexingUnitChangeEvent @PartitionID, @ItemList
