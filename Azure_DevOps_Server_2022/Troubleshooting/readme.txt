Note: These scripts need to run either from the DT machine or a machine with SQL Server 2012 or higher installed. 
The scripts currently are checked in here : https://github.com/microsoft/Code-Search Just download the complete folder to run the scripts.

List of scripts :

	1. MissingIndexFolderTriggerCollectionIndexing
	2. OptimizeElasticIndex
	3. PauseIndexing
	4. ResumeIndexing
	5. RecentIndexingActivity
	6. ReIndexFiles
	7. ReIndexingCodeRepository
	8. SetIndexingStateRepository
	9. CleanUpShardDetails
	10. ExludedTfvcFoldersForIndexing
	11. ExtensionInstallIndexingStatus
	12. FixIndexingIndexName
	13. GetCollectionReIndexingActivityStatus
	14. GetElasticsearchDocCountPerRepository
	15. GetRepositoryReInexingActivityStatus
	16. GetReIndexingStatusOfFiles
	17. TriggerCollectionIndexing
	18. WipeOutAndResetElasticSearch
	19. CollectionDBSearchDiagnostics
	20. ConfigurationDBSearchDiagnostics
	21. ElastiSearchDiagnostics
	22. RepairSearch
	

	1. MissingIndexFolderTriggerCollectionIndexing:

	Use of Script: 
	This script cleans up the collection indexing state. It uses "CleanUpCollectionIndexingState_IndexDelete.sql". 
	It Queue's Code, Work Item & Wiki Indexing job for the collection.
	This script is similar to the TriggerCollectionIndexing.ps1, the only difference being, this should be run on a specific scenario when the “Index folder was deleted manually”.
	Required Parameters:
	We need to provide certain parameters to run this script
		SQLServerInstance(ex:  C1ML***56-MS)
		CollectionDatabaseName(ex: AzureDevOps_ADO2022.0.1RC1)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		CollectionName(ex: ADO2022.0.1RC1)
	
	2. OptimizeElasticIndex:
	
	Use of Script: 
	The optimize index operation will expunge all deleted documents of a given index.
	This operation could cause very large shards to remain on disk until all the documents present in the index are just deleted documents.
	Required Parameters:
		ElasticServerUrl(ex: http://localhost:9200)
		IndexName(ex: Code* for all code indices)
		
	3. PauseIndexing:
	
	Use of Script: 
	This would pause indexing for all the collections.
	To run this script, We should have a machine running SQL Server 2012 or higher.
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		EntityType(ex: Code, WorkItem, Wiki or ALL)
		
	4. ResumeIndexing:
	
	Use of Script:
	This will Resume the indexing for all the collections.
	To run this script, We should have a machine running SQL Server 2012 or higher.
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		EntityType(ex: Code, WorkItem, Wiki or ALL)
		
	5. Re-IndexFiles:
	
	Use of Script:
	This script configures the provided path of a repository in a collection for Re-Indexing.
	It also queue's the maintenance job so that the above event is processed immediately or else it would wait for the next check-in/periodic job run to get processed.
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		CollectionDatabaseName(ex: AzureDevOps_ADO2022.0.1RC1)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		CollectionName(ex: ADO2022.0.1RC1)
		ProjectName(update the project name here in which re-indexing should take place)
		RepositoryName(update the repository name)
		Path(path of the file/folder that should be indexed ex:/ADO2022.0.1RC1/Test/_wiki/wikis/Test.wiki/1/Microsoft-Azure)
		
	6. RecentIndexingActivity:
	
	Use of Script:
	By running this script, we get the count of repositories for which indexing jobs(bulkIndexing/continuousIndexing) has completed and we can get the count of FailedIndexing jobs.
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		CollectionDatabaseName(ex: AzureDevOps_ADO2022.0.1RC1)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		CollectionName(ex: ADO2022.0.1RC1)
		Days(Enter the days since last indexing was triggered for this collection)
		EntityType(Code,WorkItem,Wiki or All)
		
	7. Re-IndexingCodeRepository:
	
	Use of Script:
	This script queue's re-indexing job for a selected repository.
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		CollectionDatabaseName(ex: AzureDevOps_ADO2022.0.1RC1)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		IndesxiUnitType(ex: Git_Repository/TFVC_Repository)
		CollectionName(ex: ADO2022.0.1RC1)
		RepositoryName(Provide the Repository Name that you want to re-index)
	
	8. SetIndexingStateRepository:

	Use of Script:
	This script sets the indexing state of the given repository in a collection to On or Off.
	It also queue's the maintenance job so that the above event is processed immediately or else it would wait for the next check-in/periodic job run to get processed.
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		CollectionDatabaseName(ex: AzureDevOps_ADO2022.0.1RC1)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		CollectionName(ex: ADO2022.0.1RC1)
		ProjectName(update the project name here in which re-indexing should take place)
		RepositoryName(update the repository name)
		IndexingState(Set the Indexing State On/Off)
		
	9. CleanUpShardDetails:

	Use of Script:
	This scripts cleans the shard details table from the configuration database
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		
	10. ExludedTfvcFoldersForIndexing:

	Use of Script:
	By using this script, we can add/remove desired folders to Indexing Exclusion list. Also we can delete all the folders in the list and fetch the list of folders present in exclusion list.
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		CollectionDatabaseName(ex: AzureDevOps_ADO2022.0.1RC1)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		CollectionName(ex: ADO2022.0.1RC1)
		OperationType(Add, Remove, Delete, Fetch)
		
	11. ExtensionInstallIndexingStatus:
	
	Use of Script:
	This script validates if the collection has code/WorkItem/Wiki extension installed and Fetches the Code/WorkItem/Wiki Extension install indexing status.
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		CollectionDatabaseName(ex: AzureDevOps_ADO2022.0.1RC1)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		CollectionName(ex: ADO2022.0.1RC1)
		Days(Enter the days since last indexing was triggered for this collection)
		EntityType(Code,WorkItem,Wiki or All)
		
	12. FixIndexingIndexName:

	Use of Script:
		This script is used to Fix the index name in all repo indexing units.
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		CollectionDatabaseName(ex: AzureDevOps_ADO2022.0.1RC1)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		CollectionName(ex: ADO2022.0.1RC1)
		
	13. GetCollectionReIndexingActivityStatus:
	
	Use of Script:
	By using this script, We can get the collection indexing status for a given collection like number of repositories completed bulk indexing and repositories in progress.
	Required Parameters:
		UserCollection(ex: ADO2022.0.1RC1)
		SQLServerInstance(ex:  C1ML***56-MS)
		CollectionDatabaseName(ex: AzureDevOps_ADO2022.0.1RC1)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		Source(Location of previous Elasticsearch aggregation output)
		Uri(URI for Elasticsearch instance/ex: http://localhost:9200)
		
	14. GetElasticsearchDocCountPerRepository:
	
	Use of Script:
	With this script, We can Fetch repository documents count data from provided ES instance. Output will be stored in a single json file at the given destination.
	Required Parameters: 
		Uri(URI for ElasticSearch instance. Ex: http://localhost:9200)
		Destination(Destination where the output file will be saved.)
		
	15. GetRepositoryReInexingActivityStatus:

	Use of Script:
	Display repository indexing status for a given collection.
	This script depends on the output of GetElasticSearchDocCountPerRepository.ps1
	Required Parameters:
		userCollection(ex: ADO2022.0.1RC1)
		userProject(Project name)
		userRepository( Repository name)
		Source(Location of previous Elasticsearch aggregation output)
		Uri(URI for ElasticSearch instance. Ex: http://localhost:9200)
		
	16. GetReIndexingStatusOfFiles:
	
	Use of Script:
	This script configures a path of a repository for re-indexing. This gives files/folders are yet to be indexed in repository.
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		CollectionDatabaseName(ex: AzureDevOps_ADO2022.0.1RC1)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		CollectionName(ex: ADO2022.0.1RC1)
		ProjectName(update the project name here in which re-indexing should take place)
		RepositoryName(update the repository name)
		Path(File/Folder for which re-index status has to be checked. Ex: /ADO2022.0.1RC1/Test/_wiki/wikis/Test.wiki/1/Microsoft-Azure)
		
	17. TriggerCollectionIndexing:

	Use of Script:
	This script uses "CleanUpCollectionIndexingState.sql" to clean- up the Code, WorkItem or Wiki Collection Indexing state and queue the Code, WorkItem or WikiIndexing job for the collection.
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		CollectionDatabaseName(ex: AzureDevOps_ADO2022.0.1RC1)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		CollectionName(ex: ADO2022.0.1RC1)
		EntityType(Code,WorkItem,Wiki or All)
		
	18. WipeOutAndResetElasticSearch:

	Use of Script:
	It will delete/cleans-up current indexed data for all the collections.
	This script would wipe out the index of all the collections, which would mean search won't work on any of the collections.
	Required Parameters:
	N/A

	19. CollectionDBSearchDiagnostics:

	Use of Script:
	Extracts the Search diagnostics data from the specified collection database and 
	Fetches IndexingUnit data into IndexingUnit.csv
	Fetches IndexingUnitChangeEvent data into IndexingUnitChangeEvent.csv
	Fetches ItemLevelFailures data into ItemLevelFailures.csv
	Fetches JobYield data into JobYield.csv
	Fetches ResourceLock data into ResourceLock.csv
	Fetches DisabledFiles data into DisabledFiles.csv
	Fetches Search registry data for collection into SearchSettingRegistriesOfCollection.csv
	Fetches ClassificationNode data into ClassificationNode.csv
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		CollectionDatabaseName(ex: AzureDevOps_ADO2022.0.1RC1)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		CollectionName(ex: ADO2022.0.1RC1)
	
	20. ConfigurationDBSearchDiagnostics:
	
	Use of Script:
	Extracts the Search diagnostics data from the specified configuration database and
	Fetches Service Host data into ServiceHost.csv
	Fetches Search URL config data into SearchConnectionUrlRegistries.csv
	Fetches Job Throttling config data into JobThrottlingRegistries.csv
	Fetches Search registry data into SearchSettingRegistries.csv
	Fetches JobQueue data into JobQueue.csv
	Fetches Job History data into JobHistory.csv
	
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		Days(number of days since when the tbl_JobHistory data needs to be fetched)

	21. ElastiSearchDiagnostics:
	
	Use of Script:
	This script is used to fetch all the diagnostics data(Basic connectivity test, _cluster/health, _cluster/allocation/explain, _cat/shards, _mapping, _cat/nodes, _settings, _cluster/settings, _aliases) of Elastic search by providing the elastic search url.
	
	Required Parameters:
		ElasticsearchServerUrl(URL of Elasticsearch service. Example: http://es-server:9200)
		
	22. RepairSearch:
	
	Usage of Script:
	.SYNOPSIS
	    For a given collection and entity type, detect and mitigate known issues.
	
	    .DESCRIPTION
	    Repair-Search works with two main concepts - Analyzers and Actions.
	        
	    Analyzers are cmdlets defined inside .\Analyzers directory. They are executed by Repair-Search in a well-defined order.
	    These analyzers try to detect any known issues or incorrect configuration in the system. After all analyzers are executed, 
	    they return one or more recommended actions.
	    
	    Actions are cmdlets defined inside .\Actions directory. Actions fix the problem detected earlier by the analyzers.
	    By default, actions that have high impact on the system are not executed without user confirmation. So, it is safe to execute this script.
	    If you feel the recommended action should not be executed, you can choose to do so when prompted by this script.
	    If you want to just check what actions would be executed without actually executing them, pass -WhatIf switch with this script.
	    If you want to execute all recommended actions without user confirmation, set $ConfirmPreference to 'None'.
	
	    Execute Repair-Search. Execute the recommended actions (manual or automated). Repeat this till no more action is recommended.
	Required Parameters:
		SQLServerInstance(ex:  C1ML***56-MS)
		CollectionDatabaseName(ex: AzureDevOps_ADO2022.0.1RC1)
		ConfigurationDatabaseName(ex: AzureDevOps_Configuration)
		CollectionName(ex: ADO2022.0.1RC1)
		ElasticsearchServerUrl(URL of Elasticsearch service. Example: http://es-server:9200)
		ElasticsearchServiceCredential(Credential for connecting to the Elasticsearch service.)
		EntityType( Code, WorkItem, Wiki or ALL)
        