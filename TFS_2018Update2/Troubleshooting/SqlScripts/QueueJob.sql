DECLARE @HostId UNIQUEIDENTIFIER = $(HostId)
DECLARE @JobId UNIQUEIDENTIFIER = $(JobId)

DECLARE @jobList dbo.typ_JobQueueUpdateTable
INSERT INTO @jobList VALUES (@JobId, 10)
DECLARE @priorityLevel INT = 10
DECLARE @delaySeconds INT = 0
DECLARE @queueAsDormant BIT = 0

EXEC dbo.prc_QueueJobs @HostId, @jobList, @priorityLevel, @delaySeconds, @queueAsDormant