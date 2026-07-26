/*
This script gets the Service Host table data.
*/

SELECT [HostId]
      ,[ParentHostId]
      ,[Name]
      ,[Status]
      ,[HostType]
      ,[ServiceLevel]
FROM tbl_ServiceHost
