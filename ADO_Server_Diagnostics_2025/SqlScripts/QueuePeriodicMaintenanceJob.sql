/** This sql script is used to queue Periodic Maintenance Job for the given collection id.
-- The script needs to be executed on the Configuration DB.
**/

Declare @CollectionId uniqueidentifier = $(CollectionID);

-- ID of Periodic Maintenance job to be queued.
DECLARE @JobID uniqueIdentifier = '1761D61B-4708-42A2-9E29-A39540141277'

Declare @jobList dbo.typ_JobQueueUpdateTable
Insert into @jobList values (@JobID, 10);

Declare @priorityLevel int;
SET @priorityLevel = 10

Declare @delaySeconds int;
SET @delaySeconds = 0;

DECLARE @queueAsDormant bit;
SET @queueAsDormant = 0;

exec [dbo].[prc_QueueJobs] @CollectionId, @jobList, @priorityLevel, @delaySeconds, @queueAsDormant