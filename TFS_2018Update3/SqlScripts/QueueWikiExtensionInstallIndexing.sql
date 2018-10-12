/** This sql script is used to queue the Wiki AccountFault In Job in case of fresh indexing for the given collection id.
  * DATABASE : CONFIGURATION DB
  **/

Declare @CollectionId uniqueidentifier = $(CollectionID);
Declare @jobList dbo.typ_JobQueueUpdateTable

-- ID of the Account Fault In job to be queued.
DECLARE @JobID uniqueIdentifier = '27B11FD5-1DA5-48B4-A732-761CE99F5A5F'
Insert into @jobList values (@JobID, 10);
Declare @priorityLevel int;
SET @priorityLevel = 10
Declare @delaySeconds int;
SET @delaySeconds = 0;
DECLARE @queueAsDormant bit;
SET @queueAsDormant = 0;
exec [dbo].[prc_QueueJobs] @CollectionId, @jobList, @priorityLevel, @delaySeconds, @queueAsDormant