Set-StrictMode -Version Latest

function Restart-Indexing
{
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = "High")]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,
        
        [Parameter(Mandatory=$True)]
        [uri] $ElasticsearchServiceUrl,
        
        [Parameter(Mandatory=$True)]
        [PSCredential] $ElasticsearchServiceCredential,
       
        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,
       
        [Parameter(Mandatory=$True)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType,

        [Parameter(Mandatory=$False)]
        [string] $AdditionalParam
    )

    if ($PSCmdlet.ShouldProcess("Entity type [$EntityType] of collection [$CollectionName]", "Reindex"))
    {
        # Reset uninstall in progress related registry keys
        Reset-ExtensionInstallationRegKeys `
            -SQLServerInstance $SQLServerInstance `
            -CollectionDatabaseName $CollectionDatabaseName `
            -CollectionName $CollectionName `
            -EntityType $EntityType `
            -AdditionalParam $AdditionalParam `
            -Confirm:$false # Don't need explicit confirmation again as executing Restart-Indexing was already confirmed by the user

        if (Test-BulkIndexingIsInProgress `
            -SQLServerInstance $SQLServerInstance `
            -ConfigurationDatabaseName $ConfigurationDatabaseName `
            -CollectionDatabaseName $CollectionDatabaseName `
            -CollectionName $CollectionName `
            -EntityType $EntityType)
        {
            Write-Log "$EntityType bulk indexing of collection [$CollectionName] is already in progress. Skipping re-indexing." -Level Warn
            return
        }

        $collectionId = Get-CollectionId -SqlServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionName $CollectionName

        # Delete data indexed in Elasticsearch
        $allIndexRecords = (Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Get -Command "_cat/indices?v&h=index&format=json").Content | ConvertFrom-Json
        if ($allIndexRecords.Count -eq 0)
        {
            Write-Log "There are no indices in Elasticsearch and hence nothing to delete."
        }
        else
        {
            foreach ($indexRecord in $allIndexRecords)
            {
                Write-Verbose $indexRecord
                $indexName = $indexRecord.index
                if ($indexName.StartsWith($EntityType.ToLowerInvariant()))
                {
                    Write-Log "Deleting [$EntityType] documents of collection [$CollectionName] from index [$indexName]..."
                    # TODO: [bsarkar] For large collections, this will need proper error handling and retries
                    $response = Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Post -Command "$indexName/_delete_by_query?q=collectionId:$collectionId" -Verbose:$VerbosePreference
                }
            }
        }

        # Disable indexing
        Disable-IndexingFeatureFlags `
            -SQLServerInstance $SQLServerInstance `
            -ConfigurationDatabaseName $ConfigurationDatabaseName `
            -CollectionDatabaseName $CollectionDatabaseName `
            -CollectionName $CollectionName `
            -EntityType $EntityType

        # Get all Job Ids corresponding to all indexing units of the given entity type
        $indexingJobIds = Invoke-Sqlcmd -Query "SELECT AssociatedJobId FROM Search.tbl_IndexingUnit WHERE EntityType = '$EntityType' AND AssociatedJobId IS NOT NULL AND IsDeleted = 0 AND PartitionId = 1" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName | Select-Object -ExpandProperty AssociatedJobId
        
        # Reset data from SQL
        $sqlParams = "CollectionId='$CollectionId'", "EntityTypeString='$EntityType'", "EntityTypeInt=$(Get-EntityTypeId $EntityType)"
        $sqlFilePath = "$PSScriptRoot\..\SqlScripts\CleanUpCollectionIndexingState.sql"
        $response = Invoke-Sqlcmd -InputFile $sqlFilePath -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName -Variable $sqlParams
        Write-Log "Cleaned up all SQL tables storing indexing state."

        if ($indexingJobIds)
        {
            Write-Log "Waiting for indexing activity to die down upto 15 minutes..."
            $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
            while ($stopwatch.Elapsed.TotalMinutes -lt 15) # Waiting for a maximum of 15 minutes
            {
                $indexingJobQueuedCount = [int](Invoke-Sqlcmd -Query "SELECT COUNT(1) As IndexingJobQueuedCount FROM dbo.tbl_JobQueue WHERE JobSource = '$collectionId' AND JobId IN ($(($indexingJobIds | ForEach-Object { "'$_'" }) -join ', '))" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName | Select-Object -ExpandProperty IndexingJobQueuedCount)
                if ($indexingJobQueuedCount -eq 0)
                {
                    break
                }

                Write-Log "[$indexingJobQueuedCount] $EntityType indexing jobs are still queued/in-progress. Waiting for them to complete..." -Level Warn
                Start-Sleep -Seconds 5
            }
        }

        # Enable indexing
        Enable-IndexingFeatureFlags `
            -SQLServerInstance $SQLServerInstance `
            -ConfigurationDatabaseName $ConfigurationDatabaseName `
            -CollectionDatabaseName $CollectionDatabaseName `
            -CollectionName $CollectionName `
            -EntityType $EntityType

        # Queue fault-in job if not queued already
        if (!(Test-BulkIndexingIsInProgress `
            -SQLServerInstance $SQLServerInstance `
            -ConfigurationDatabaseName $ConfigurationDatabaseName `
            -CollectionDatabaseName $CollectionDatabaseName `
            -CollectionName $CollectionName `
            -EntityType $EntityType))
        {
            Invoke-FaultInJob `
                -SQLServerInstance $SQLServerInstance `
                -ConfigurationDatabaseName $ConfigurationDatabaseName `
                -CollectionDatabaseName $CollectionDatabaseName `
                -CollectionName $CollectionName `
                -EntityType $EntityType
        }
        else
        {
            Write-Log "[$EntityType] bulk indexing of collection [$CollectionName] is already in progress. Not queuing the job again." -Level Warn
        }
    }
}