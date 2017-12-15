--**UPDATE** Please enter the Collection id
/*
This script gets the number of repositories for which the DataCrawl stage has already completed.
*/

Declare @CollectionId uniqueidentifier = $(CollectionID);
Declare @Days int = $(DaysAgo);

Select Count(Distinct(JobId)) as IndexingCompletedCount from tbl_JobHistory
where
JobSource = @CollectionId
and EndTime >  DATEADD(DAY, -@Days, GETUTCDATE())
and ResultMessage like '%AccountFaultIn%RepositoryDataCrawlerOperation for %completed%'
