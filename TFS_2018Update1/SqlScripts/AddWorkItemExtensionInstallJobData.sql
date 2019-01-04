/** This sql script is to Add the data for Collection Indexing Job. 
-- The script needs to be executed on the Collection DB of the collection.
-- DATABASE : COLLECTION DB
-- ** !! POST running this script, please run the "QueueExtensionInstallIndexing" script against the Configuration DB. !! **/

Declare @CollectionId uniqueidentifier = $(CollectionID);

DECLARE @partitionID varchar(50)
Select @partitionID = PartitionID from [dbo].[tbl_DatabasePartitionMap] where ServiceHostId = @CollectionId 

-- ID of the job to be queued.
DECLARE @JobID uniqueIdentifier = '03CEE4B8-ECC1-4E57-95CE-FA430FE0DBFB'

-- JobName of the job
DECLARE @JobName nvarchar(max) = 'WorkItem Account Fault in Job'

-- JobExtension 
DECLARE @JobExtension nvarchar(max) = 'Microsoft.VisualStudio.Services.Search.Server.Jobs.WorkItemAccountFaultInJob';

DECLARE @definition dbo.typ_JobDefinitionTable
insert into @definition values (@JobID, @JobName, @JobExtension, NULL, 0, 0, 4)

DECLARE @allowUpdate BIT = 1

DECLARE @scheduleUpdate typ_JobScheduleTable;
exec dbo.prc_UpdateJobs @partitionID, @definition, @scheduleUpdate, @allowUpdate







