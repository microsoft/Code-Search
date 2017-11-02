/*
This script gets the job history data.
*/

Declare @Days int = $(DaysAgo);

SELECT [JobSource]
      ,[JobId]
      ,[QueueTime]
      ,[StartTime]
      ,[EndTime]
      ,[Result]
      ,[ResultMessage]
  FROM tbl_JobHistory
  where QueueTime >  DATEADD(DAY, -@Days, GETUTCDATE()) and 
  (JobId = '02F271F3-0D40-4FA0-9328-C77EBCA59B6F' or JobId = '03CEE4B8-ECC1-4E57-95CE-FA430FE0DBFB' 
  or ResultMessage like '%completed with status%'
  or ResultMessage like '%back to Pending state with requeueDelay%'
  or ResultMessage like '%Installed extension%')
  order by StartTime desc
