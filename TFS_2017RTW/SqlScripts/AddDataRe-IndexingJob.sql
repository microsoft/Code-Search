/** This sql script is to Add the data for Repair Job. The user needs to be update the variables marked following the **UPDATE** comment.
-- The script will update the data based the scenario of Collection/Repository Re-indexing.
-- The script needs to be executed on the Collection DB of the collection/collection to which the repository belongs to.
-- DATABASE : COLLECTION DB
-- ** !! POST running this script, please run the "QueueRepairJob" script against the Configuration DB. !! **/

-- **UPDATE**
-- The value here can be either "Git_Repository/TFVC_Repository" or "Collection", based on if you want to do some GIT/TFVC repository re-indexing or collection.
DECLARE @IndexingUnitType nvarchar(30) = $(IndexingUnitType)

-- **UPDATE**
-- Update the tfvc/git repository name here. For Repairing/Re-indexing a collection, this can be any string.
DECLARE @RepositoryName nvarchar(max) = $(RepositoryName)

-- **UPDATE**
-- Update the type of repository, use 'Git_Repository' for git repos and 'TFVC_Repository' for TFVC projects.
DECLARE @RepositoryType varchar(30) = $(RepositoryType)

DECLARE @CollectionId uniqueidentifier = $(CollectionId)
DECLARE @RepositoryId varchar(50) = ''
if(@IndexingUnitType <> 'Collection')
BEGIN
	SELECT @RepositoryId = TFSEntityId from Search.tbl_IndexingUnit
		 where TFSEntityAttributes Like '%<RepositoryName>'+@RepositoryName+'</RepositoryName>%' and IndexingUnitType Like '%Repository%'

	if(@RepositoryId is null)
	BEGIN
		PRINT N'We dont have the repository already indexed. Please try pushing some change to the repository to get it indexed.'
		RETURN
	END
END

DECLARE @JobData nvarchar(max) = '<CodeRepairJobDataModel><IndexingUnitType>$UnitType</IndexingUnitType><RepositoryId>$RepoId</RepositoryId><RepositoryType>$RepoType</RepositoryType></CodeRepairJobDataModel>'
SET @JobData = REPLACE(REPLACE(REPLACE(@JobData, '$UnitType', @IndexingUnitType),
					'$RepoId', @RepositoryId),
							'$RepoType', @RepositoryType)

DECLARE @partitionID varchar(50)
Select @partitionID = PartitionID from [dbo].[tbl_DatabasePartitionMap] where ServiceHostId = @CollectionId

-- ID of the job to be queued.
DECLARE @JobID uniqueIdentifier = 'C1F3C994-3C3A-4AC5-8A21-CDB6B5FC8EE8'

-- JobName of the job
DECLARE @JobName nvarchar(max) = 'Code Repair Job'

-- JobExtension
DECLARE @JobExtension nvarchar(max) = 'Microsoft.VisualStudio.Services.Search.Server.Jobs.CodeRepairJob';

DECLARE @definition dbo.typ_JobDefinitionTable
insert into @definition values (@JobID, @JobName, @JobExtension, @JobData, 0, 0, 4)

DECLARE @allowUpdate BIT = 1

DECLARE @scheduleUpdate typ_JobScheduleTable;
exec dbo.prc_UpdateJobs @partitionID, @definition, @scheduleUpdate, @allowUpdate
