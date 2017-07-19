/** This sql script is used to queue the AccountFault In Job in case of fresh indexing for the given collection id.
  * Update the Collection id in the variable under the comment **UPDATE**
  * DATABASE : CONFIGURATION DB
  **/

Declare @CollectionId uniqueidentifier = $(CollectionID);
Declare @jobList dbo.typ_GuidInt32Table

-- ID of the Account Fault In job to be queued.
DECLARE @JobID uniqueIdentifier = '02F271F3-0D40-4FA0-9328-C77EBCA59B6F'
Insert into @jobList values (@JobID, 10);
Declare @priorityLevel int;
SET @priorityLevel = 10
Declare @delaySeconds int;
SET @delaySeconds = 0;
DECLARE @queueAsDormant bit;
SET @queueAsDormant = 0;
exec [dbo].[prc_QueueJobs] @CollectionId, @jobList, @priorityLevel, @delaySeconds, @queueAsDormant
