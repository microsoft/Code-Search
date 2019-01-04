--**UPDATE** Please enter the Collection id and Days
/*
This script gets the number of Continuous Indexing jobs completed in the given date range.
*/

Declare @CollectionId uniqueidentifier = $(CollectionID);
Declare @Days int = $(DaysAgo);

Select Count(JobId) as ContinuousIndexingCompletedCount from tbl_JobHistory
where 
JobSource = @CollectionId
and EndTime >  DATEADD(DAY, -@Days, GETUTCDATE())
and ResultMessage like '%UpdateIndex%Completed pipeline execution for IndexingUnit%EntityType: WorkItem%'
