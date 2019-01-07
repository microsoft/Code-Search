****************************************************************************************************
To analyze Search issues in Team Foundation Server, please share the following data as listed below
****************************************************************************************************

1. Share Search Configuration log. Note that the below directory could be hidden. So enable viewing hidden items first.
   <DriveLocation>:\ProgramData\Microsoft\Team Foundation\Server Configuration\Logs

2. Share ElasticSearch logs
   Zip the folder <ElasticSearchFolderLocation>\elasticsearch-1.7.1-SNAPSHOT\logs

3. Share Configuration Database status for Search
   Run script .\ConfigurationDBSearchDiagnostics.ps1
   Diagnostics data will be generated in ConfigurationDatabaseName_Diagnostic.zip

4. Share Collection Database status for Search
   For each Collection (that needs analysis), run script .\CollectionDBSearchDiagnostics.ps1
   Diagnostics data will be generated in CollectionDatabaseName_Diagnostic.zip

5. Share Elasticsearch service status
   Run script .\ElasticsearchDiagnostics.ps1
   Diagnostics data will be generated in Elasticsearch_Diagnostic.zip