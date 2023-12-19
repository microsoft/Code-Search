IF (OBJECT_ID(N'Search.tbl_ItemLevelFailures') IS NOT NULL)
BEGIN
SELECT [IndexingUnitId]
      ,[Id]
      ,[Item]
      ,[AttemptCount]
      ,[Stage]
      ,[Reason]
      ,[Metadata]
FROM [Search].[tbl_ItemLevelFailures]
END