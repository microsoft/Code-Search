/** This sql script is used to queue the WorkItem AccountFault In Job in case of fresh indexing of the WorkItems for the given collection id.
  **/

Declare @CollectionId uniqueidentifier = $(CollectionID);
Declare @jobList dbo.typ_JobQueueUpdateTable

-- ID of the WorkItem Account Fault In job to be queued.
DECLARE @JobID uniqueIdentifier = '03CEE4B8-ECC1-4E57-95CE-FA430FE0DBFB'
Insert into @jobList values (@JobID, 10);
Declare @priorityLevel int;
SET @priorityLevel = 10
Declare @delaySeconds int;
SET @delaySeconds = 0;
DECLARE @queueAsDormant bit;
SET @queueAsDormant = 0;
exec [dbo].[prc_QueueJobs] @CollectionId, @jobList, @priorityLevel, @delaySeconds, @queueAsDormant