/*
Gets the result of the AccountFaultIn Job for the collection
*/

Declare @CollectionId uniqueidentifier = $(CollectionID);
SELECT Top 1 Result, ResultMessage
	FROM tbl_JobHistory
	WHERE JobId = '03CEE4B8-ECC1-4E57-95CE-FA430FE0DBFB'
	AND JobSource = @CollectionId
	ORDER BY StartTime DESC
