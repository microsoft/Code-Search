/*
Gets the result of the WikiAccountFaultIn Job for the collection
*/

Declare @CollectionId uniqueidentifier = $(CollectionID);
SELECT Top 1 Result, ResultMessage 
	FROM tbl_JobHistory WITH (NOLOCK)
	WHERE JobId = '27B11FD5-1DA5-48B4-A732-761CE99F5A5F'
	AND JobSource = @CollectionId
	ORDER BY StartTime DESC
