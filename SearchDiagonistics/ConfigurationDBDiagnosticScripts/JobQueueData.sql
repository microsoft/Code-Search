/*
This script gets the job queue status for the Account Fault-In jobs that trigger indexing.
*/

SELECT QueueTime, JobSource, JobId, JobState
FROM tbl_JobQueue
where JobId = '02F271F3-0D40-4FA0-9328-C77EBCA59B6F' or JobId = '03CEE4B8-ECC1-4E57-95CE-FA430FE0DBFB' 
