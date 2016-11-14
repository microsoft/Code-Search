/**	This sql script is to Add the data for Re-indexing job. The user needs to be update the variables marked following the **UPDATE** comment.
	The script will add the job data for the given collection id.
	DATABASE : COLLECTION DB
--  !! POST running this script, Run the "QueueRe-IndexingJob" script against the Configuration DB. !!**/

-- **UPDATE** the collection Id which has shards corrupted
DECLARE @CollectionId uniqueidentifier = 'EF426DB3-BE71-4F78-A957-027542E140BD';

DECLARE @IndexingUnitType nvarchar(30) = 'Collection' 
DECLARE @validCollectionId int;

-- ** UPDATE ** Update the configuration DB name in the query below if needed then run the script. By default, the configuration DB is Tfs_Configuration.
Select @validCollectionId =  Count(*) from [Tfs_Configuration].[dbo].[tbl_ServiceHost] where HostId = @CollectionId

if(@validCollectionId = 0)
BEGIN
	PRINT N'Please enter a valid Collection ID.'
	Return
END

DECLARE @JobData nvarchar(max) = '<CodeRepairJobDataModel><IndexingUnitType>$UnitType</IndexingUnitType><RepositoryId>$RepoId</RepositoryId><RepositoryType>$RepoType</RepositoryType></CodeRepairJobDataModel>'
SET @JobData = REPLACE(@JobData, '$UnitType', @IndexingUnitType)

DECLARE @partitionID varchar(50)
Select @partitionID = PartitionID from [dbo].[tbl_DatabasePartitionMap] where ServiceHostId = @CollectionId

-- ID of the job to be queued.
DECLARE @JobID uniqueIdentifier = 'C1F3C994-3C3A-4AC5-8A21-CDB6B5FC8EE8'

-- JobName of the job
DECLARE @JobName nvarchar(max) = 'Code Repair Job'

-- JobExtension 
DECLARE @JobExtension nvarchar(max) = 'Microsoft.VisualStudio.Services.Search.Server.Jobs.CodeRepairJob';

DECLARE @definition dbo.typ_JobDefinitionTable
insert into @definition values (@JobID, @JobName, @JobExtension, @JobData,0,0,4)

DECLARE @allowUpdate BIT = 1

DECLARE @scheduleUpdate typ_JobScheduleTable;
exec dbo.prc_UpdateJobs @partitionID, @definition, @scheduleUpdate, @allowUpdate

