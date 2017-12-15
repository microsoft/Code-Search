--**UPDATE** Please enter the Collection id and Days
/*
This script gets the number of repositories for which the Fresh Indexing(new repository) has already completed.
*/

Declare @CollectionId uniqueidentifier = $(CollectionID);
Declare @Days int = $(DaysAgo);

Select Count(Distinct(JobId)) as BulkIndexingCompletedCount from tbl_JobHistory
where 
JobSource = @CollectionId
and EndTime >  DATEADD(DAY, -@Days, GETUTCDATE())
and ResultMessage like '%BeginBulkIndex%Completed pipeline execution for IndexingUnit%EntityType: Code%'
