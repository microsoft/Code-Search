/*
Gets the result of the AccountFaultIn Job for the collection
*/

Declare @CollectionId uniqueidentifier = $(CollectionID);
SELECT Top 1 Result, ResultMessage 
	FROM tbl_JobHistory
	WHERE JobId = '02F271F3-0D40-4FA0-9328-C77EBCA59B6F'
	AND JobSource = @CollectionId 
	ORDER BY StartTime DESC
