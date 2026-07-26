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

    $message = "Re-index [$EntityType] documents of collection [$CollectionName]"
    if (!$PSCmdlet.ShouldProcess($message.ToUpperInvariant(), "Are you sure you want to $($message)? Re-indexing may take a long time to complete for a large collection.".ToUpperInvariant(), "Confirm"))
    {
        return
    }

    # Disable indexing
    Disable-IndexingFeatureFlags `
        -SQLServerInstance $SQLServerInstance `
        -ConfigurationDatabaseName $ConfigurationDatabaseName `
        -CollectionDatabaseName $CollectionDatabaseName `
        -CollectionName $CollectionName `
        -EntityType $EntityType

    # Reset data from SQL
    $collectionId = Get-CollectionId -SqlServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionName $CollectionName
    $sqlParams = "CollectionId='$collectionId'", "EntityTypeString='$EntityType'", "EntityTypeInt=$(Get-EntityTypeId $EntityType)"
    $sqlFilePath = "$PSScriptRoot\..\SqlScripts\CleanUpCollectionIndexingState.sql"
    $response = Invoke-Sqlcmd -InputFile $sqlFilePath -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName -Variable $sqlParams
    Write-Log "Cleaned up all SQL tables storing indexing state."

    # Delete data indexed in Elasticsearch
    $allIndexRecords = (Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Get -Command "_cat/indices?v&h=index&format=json" -Verbose:$VerbosePreference).Content | ConvertFrom-Json
    if ($allIndexRecords.Count -eq 0)
    {
        Write-Log "There are no indices in Elasticsearch and hence nothing to delete."
    }
    else
    {
        foreach ($indexRecord in $allIndexRecords)
        {
            Write-Log $indexRecord -Level Verbose
            $indexName = $indexRecord.index
            if ($indexName.StartsWith($EntityType.ToLowerInvariant()))
            {
                Write-Log "Deleting [$EntityType] documents of collection [$CollectionName] from index [$indexName]..."
                Remove-IndexedDocumentsInBatches -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -IndexPattern $indexName -Body "{ `"query`": { `"term`": { `"collectionId`": `"$collectionId`" } } }"
            }
        }
    }

    # Get all Job Ids corresponding to all indexing units of the given entity type
    $indexingJobIds = Invoke-Sqlcmd -Query "SELECT AssociatedJobId FROM Search.tbl_IndexingUnit WHERE EntityType = '$EntityType' AND AssociatedJobId IS NOT NULL AND IsDeleted = 0 AND PartitionId = 1" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName | Select-Object -ExpandProperty AssociatedJobId
    if ($indexingJobIds)
    {
        $timeoutInMinutes = 15
        Write-Log "Waiting for indexing activity to die down upto $timeoutInMinutes minutes..."
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        while ($stopwatch.Elapsed.TotalMinutes -lt $timeoutInMinutes) # Waiting for a maximum of $timeoutInMinutes minutes
        {
            $indexingJobQueuedCount = [int](Invoke-Sqlcmd -Query "SELECT COUNT(1) As IndexingJobQueuedCount FROM dbo.tbl_JobQueue WHERE JobSource = '$collectionId' AND JobId IN ($(($indexingJobIds | ForEach-Object { "'$_'" }) -join ', '))" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName | Select-Object -ExpandProperty IndexingJobQueuedCount)
            if ($indexingJobQueuedCount -eq 0)
            {
                Write-Log "All $EntityType indexing jobs have completed."
                break
            }
            else
            {
                Write-Log "[$indexingJobQueuedCount] $EntityType indexing jobs are still queued/in-progress. Waiting for them to complete..." -Level Warn
            }

            Start-Sleep -Seconds 5
        }
    }
    else
    {
        Write-Log "There are no $EntityType indexing jobs in progress."
    }

    # Enable indexing
    Enable-IndexingFeatureFlags `
        -SQLServerInstance $SQLServerInstance `
        -ConfigurationDatabaseName $ConfigurationDatabaseName `
        -CollectionDatabaseName $CollectionDatabaseName `
        -CollectionName $CollectionName `
        -EntityType $EntityType `
        -WhatIf:$False `
        -Confirm:$False `
        -Verbose:$VerbosePreference

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