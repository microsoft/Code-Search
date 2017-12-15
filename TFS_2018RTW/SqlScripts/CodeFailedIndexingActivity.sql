--**UPDATE** Please enter the Collection id and Days
/*
This script gets the number of Indexing jobs failed in the given date range.
*/

Declare @CollectionId uniqueidentifier = $(CollectionID);
Declare @Days int = $(DaysAgo);

Select Count(Distinct(JobId)) as FailedIndexingCount from tbl_JobHistory
where 
JobSource = @CollectionId
and EndTime >  DATEADD(DAY, -@Days, GETUTCDATE())
and ResultMessage like '%events%completed with status Failed.%EntityType: Code%'
