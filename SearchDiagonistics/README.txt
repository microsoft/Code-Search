***************************************************************************************************
To analyze Search issue in Team Foundation Server, please share the following data as listed below
***************************************************************************************************

1. Share TFS/Search Configuration log
   <DriveLocation>:\ProgramData\Microsoft\Team Foundation\Server Configuration\Logs

2. Share ElasticSearch logs
   <ElasticSearchFolderLocation>\elasticsearch-2.4.1\logs

3. Share Configuration Database status for Search
   Run script .\ConfigurationDBSearchDiagnostics.ps1
   Diagnostics data will be generated in $ConfigurationDatabaseName_Diagnostic.zip

4. Share Collection Database status for Search
   For each Collection (that needs analysis), run script .\CollectionDBSearchDiagnostics.ps1
   Diagnostics data will be generated in $CollectionDatabaseName_Diagnostic.zip

5. Share Elasticsearch service status
   Refer REST calls listed in .\ESStatus.txt

____________________________________________________________________________________________________
      
  

