Set-StrictMode -Version Latest

function Import-SqlModule
{
    [CmdletBinding()]
    Param()

    $moduleCheck = Get-Module -List SQLSERVER
    if($moduleCheck)
    {
        Import-Module -Name SQLSERVER -DisableNameChecking
        Write-Log "Loaded SQLSERVER module."
    }
    else
    {
        $moduleCheck = Get-Module -List SQLPS
        if($moduleCheck)
        {
            Import-Module -Name SQLPS -DisableNameChecking
            Write-Log "Loaded SQLPS module."
        }
        else
        {
            throw "Could not load SqlServer or SqlPS modules. Try running the script from a machine with SQL Server 2014 or higher installed or powershell 5.0"
        }
    }
}

function Get-CollectionName
{
    [CmdletBinding()]
    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$True)]
        [guid] $CollectionId
    )

    try
    {
        $results = Invoke-Sqlcmd -Query "Select Name from dbo.tbl_ServiceHost WHERE HostId = '$CollectionId' AND HostType = 4" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName -ErrorAction Stop
        if (!$results)
        {
            throw "Either the collection with Id [$CollectionId] does not exist or it is in a detached state."
        }
    
        $collectionName = $results | Select-Object -ExpandProperty Name
        Write-Log "Collection Name: [$collectionName]." -Level Verbose
        return $collectionName
    }
    catch
    {
        throw [ArgumentException]$_.Exception.Message
    }
}

function Get-CollectionId
{
    [CmdletBinding()]
    [OutputType([guid])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName
    )

    try
    {
        $results = Invoke-Sqlcmd -Query "Select HostId from dbo.tbl_ServiceHost WHERE Name = '$CollectionName' AND HostType = 4" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName -ErrorAction Stop
        if (!$results)
        {
            throw "Either collection [$CollectionName] does not exist or it is in a detached state."
        }

        $collectionId = [guid]($results | Select-Object -ExpandProperty HostId)
        Write-Log "Collection Id: [$collectionId]." -Level Verbose
        return $collectionId
    }
    catch
    {
        throw [ArgumentException]$_.Exception.Message
    }
}

function Confirm-CollectionIsInStartedState
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName
    )

    $results = Invoke-Sqlcmd -Query "Select Status from dbo.tbl_ServiceHost WHERE Name = '$CollectionName' AND HostType = 4" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName
    if (!$results)
    {
        throw [ArgumentException]"Either collection [$CollectionName] does not exist or it is in a detached state."
    }
    
    $status = [int]($results | Select-Object -ExpandProperty Status)
    if ($status -eq 3)
    {
        throw [ArgumentException]"Collection [$CollectionName] is offline. Please start the collection from Azure DevOps Server Administration Console."
    }

    if ($status -ne 1)
    {
        throw [ArgumentException]"Collection [$CollectionName] is not online. It is currently in state [$status]. Please bring the collection online."
    }
}

function Get-DeploymentHostId
{
    [CmdletBinding()]
    [OutputType([guid])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName
    )

    $deploymentHostId = Invoke-Sqlcmd -Query "Select HostID from dbo.tbl_ServiceHost WHERE Name = 'TEAM FOUNDATION' AND HostType = 3" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName | Select-Object -ExpandProperty HostId
    if (!$deploymentHostId)
    {
        throw "Deployment host Id not found."
    }

    Write-Log "Deployment host Id: [$deploymentHostId]." -Level Verbose
    return $deploymentHostId
}

function Confirm-SqlIsReachable
{
    <#
    .SYNOPSIS
    Verifies the input connection parameters are correct and the collection is in started state.
    #>
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName
    )

    $collectionId = Get-CollectionId -SqlServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionName $CollectionName
    $partitionId = $null

    try
    {
        $partitionId = Invoke-Sqlcmd -Query "SELECT PartitionId FROM dbo.tbl_DatabasePartitionMap WHERE ServiceHostId = '$collectionId'" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName -ErrorAction Stop | Select-Object -ExpandProperty PartitionId
    }
    catch
    {
        throw [ArgumentException]$_.Exception.Message
    }
    
    if (!$partitionId)
    {
        throw [ArgumentException]"Collection [$CollectionName] does not belong to collection database [$CollectionDatabaseName]."
    }

    if ($partitionId -ne 1)
    {
        throw "Expected partition Id of the collection [$CollectionName] in database [$CollectionDatabaseName] to be 1, but found $partitionId. This could indicate a non-supported deployment."
    }

    Confirm-CollectionIsInStartedState -SqlServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionName $CollectionName
}

function Invoke-ElasticsearchCommand
{
    [CmdletBinding()]
    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [uri] $ElasticsearchServiceUrl,

        [Parameter(Mandatory=$True)]
        [PSCredential] $ElasticsearchServiceCredential,

        [Parameter(Mandatory=$True)]
        [Microsoft.PowerShell.Commands.WebRequestMethod] $Method,

        [Parameter(Mandatory=$False)]
        [string] $Command = "",

        [Parameter(Mandatory=$False)]
        [string] $Body
    )

    $uri = "$ElasticsearchServiceUrl$Command"

    $content = $null
    $statusCode = $null
    $errorMsg = $null
    try
    {
        if ($Method -eq "Get" -or $Method -eq "Head")
        {
            $response = Invoke-WebRequest -Method $Method -Uri $uri -Credential $ElasticsearchServiceCredential -ErrorAction Stop
        }
        else
        {
            $response = Invoke-WebRequest -Method $Method -Uri $uri -Body $Body -Credential $ElasticsearchServiceCredential -ContentType "application/json" -ErrorAction Stop
        }

        $content = $response.Content
        $statusCode = $response.StatusCode
    }
    catch
    {
        if (!$_.Exception.Message.Contains("Unable to connect to the remote server"))
        {
            $statusCode = $_.Exception.Response.StatusCode.value__
        }

        $errorMsg = $_ | Out-String
    }

    $response = New-Object PSObject -Property `
    @{
        StatusCode = $statusCode
        Content = $content
        ErrorMessage = $errorMsg
    }

    Write-Log "Response = [$($response | ConvertTo-Json)]" -Level Verbose
    return $response
}

function Confirm-ElasticsearchIsReachable
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [uri] $ElasticsearchServiceUrl,

        [Parameter(Mandatory=$True)]
        [PSCredential] $ElasticsearchServiceCredential
    )

    $response = Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Head -Verbose:$VerbosePreference
    if (!$response.StatusCode)
    {
        throw [ArgumentException]"An error occurred while establishing a connection to Elasticsearch service at [$ElasticsearchServiceUrl]. The service is either not installed or not in a started state."
    }
    elseif ($response.StatusCode -eq 403)
    {
        throw [ArgumentException]"An error occurred while establishing a connection to Elasticsearch service at [$ElasticsearchServiceUrl]. The service is reachable but the credential provided is incorrect."
    }
}

function Remove-IndexedDocumentsInBatches
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [uri] $ElasticsearchServiceUrl,

        [Parameter(Mandatory=$True)]
        [PSCredential] $ElasticsearchServiceCredential,

        [Parameter(Mandatory=$True)]
        [string] $IndexPattern,

        [Parameter(Mandatory=$False)]
        [string] $Body
    )

    $batchDeleteTimeout = "10s"
    $timedOut = $false
    do
    {
        $url = "$IndexPattern/_delete_by_query?timeout=$batchDeleteTimeout"
        $response = Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Post -Command $url -Body $body
        if ($response.StatusCode -eq 200)
        {
            $timedOut = [bool](($response.Content | ConvertFrom-Json).timed_out)
            $docsDeleted = [int](($response.Content | ConvertFrom-Json)._indices._all.deleted)
            $docsFound = [int](($response.Content | ConvertFrom-Json)._indices._all.found)
            $docsRemaining = $docsFound - $docsDeleted
            if ($timedOut)
            {
                Write-Log "Number of documents pending deletion = [$docsRemaining]. Reporting back in [$batchDeleteTimeout]..."
            }
            else
            {
                Write-Log "Number of documents pending deletion = [$docsRemaining]."
            }
        }
        else
        {
            Write-Log "Delete request failed with response: [$($response | Out-String)]." -Level Error
        }

        $url = "$IndexPattern/_refresh"
        $response = Invoke-ElasticsearchCommand -ElasticsearchServiceUrl $ElasticsearchServiceUrl -ElasticsearchServiceCredential $ElasticsearchServiceCredential -Method Post -Command $url
    } while ($timedOut)
}

function Test-ExtensionInstalled
{
    [CmdletBinding()]
    [OutputType([bool])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$True)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType
    )

    switch ($EntityType)
    {
        "Code"
        {
            $extensionName = Invoke-Sqlcmd -Query "SELECT ExtensionName FROM Extension.tbl_InstalledExtension WHERE PublisherName = 'ms' and ExtensionName = 'vss-code-search'" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName | Select-Object -ExpandProperty ExtensionName
            if (!$extensionName)
            {
                Write-Log "$_ search extension is not installed" -Level Warn
                return $false
            }

            $isExtensionInstalRecorded = Get-ServiceRegistryValue -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -RegistryPath "\Service\ALMSearch\Settings\IsCollectionIndexed"
            
            if (!$isExtensionInstalRecorded)
            {
                Write-Log "$_ search extension is installed but the corresponding registry key is not set in search service." -Level Warn
                return $false
            }
            
            return $true
        }

        "WorkItem"
        {
            $extensionName = Invoke-Sqlcmd -Query "SELECT ExtensionName FROM [Extension].[tbl_InstalledExtension] where PublisherName = 'ms' and ExtensionName = 'vss-workitem-searchonprem'" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName | Select-Object -ExpandProperty ExtensionName
            if (!$extensionName)
            {
                Write-Log "$_ search extension is not installed" -Level Warn
                return $false
            }
            
            $isExtensionInstalRecorded = Get-ServiceRegistryValue -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -RegistryPath "\Service\ALMSearch\Settings\IsCollectionIndexedForWorkItem"
            
            if (!$isExtensionInstalRecorded)
            {
                Write-Log "$_ search extension is installed but the corresponding registry key is not set in search service." -Level Warn
                return $false
            }
            
            return $true
        }

        "Wiki"
        {
            $extensionName = Invoke-Sqlcmd -Query "SELECT ExtensionName FROM [Extension].[tbl_InstalledExtension] where PublisherName = 'ms' and ExtensionName = 'vss-wiki-searchonprem'" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName | Select-Object -ExpandProperty ExtensionName
            if (!$extensionName)
            {
                Write-Log "$_ search extension is not installed" -Level Warn
                return $false
            }
            
            $isExtensionInstalRecorded = Get-ServiceRegistryValue -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -RegistryPath "\Service\ALMSearch\Settings\IsCollectionIndexedForWiki"
            
            if (!$isExtensionInstalRecorded)
            {
                Write-Log "$_ search extension is installed but the corresponding registry key is not set in search service." -Level Warn
                return $false
            }
            
            return $true
        }

        default
        {
            throw [System.NotImplementedException] "Test for entity type [$_] is not implemented."
        }
    }
}

function Test-IndexingFeatureFlagsAreEnabled
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,
        
        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,
       
        [Parameter(Mandatory=$True)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType
    )

    switch ($EntityType)
    {
        "Code"
        {
            if (!(Get-FeatureFlag -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.Code.Indexing"))
            {
                Write-Log "Search.Server.Code.Indexing feature flag is not enabled." -Level Error
                return $false
            }
            
            if (!(Get-FeatureFlag -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.Code.CrudOperations"))
            {
                Write-Log "Search.Server.Code.CrudOperations feature flag is not enabled." -Level Error
                return $false
            }

            return $true
        }

        "WorkItem"
        {
            if (!(Get-FeatureFlag -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.WorkItem.Indexing"))
            {
                Write-Log "Search.Server.WorkItem.Indexing feature flag is not enabled." -Level Error
                return $false
            }
            elseif (!(Get-FeatureFlag -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.WorkItem.CrudOperations"))
            {
                Write-Log "Search.Server.WorkItem.CrudOperations feature flag is not enabled." -Level Error
                return $false
            }

            return $true
        }

        "Wiki"
        {
            if (!(Get-FeatureFlag -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.Wiki.Indexing"))
            {
                Write-Log "Search.Server.Wiki.Indexing feature flag is not enabled." -Level Error
                return $false
            }
            elseif (!(Get-FeatureFlag -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.Wiki.ContinuousIndexing"))
            {
                Write-Log "Search.Server.Wiki.ContinuousIndexing feature flag is not enabled." -Level Error
                return $false
            }

            return $true
        }

        default
        {
            throw [System.NotImplementedException] "Test for entity type [$_] is not implemented."
        }
    }
}

function Disable-IndexingFeatureFlags
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,
        
        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,
       
        [Parameter(Mandatory=$True)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType
    )

    Write-Log "Disabling [$EntityType] indexing feature flags for collection [$CollectionName]..."
    switch ($EntityType)
    {
        "Code"
        {
            Set-FeatureFlag -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.Code.Indexing" -State Off
            Set-FeatureFlag -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.Code.CrudOperations" -State Off
            break
        }

        "WorkItem"
        {
            Set-FeatureFlag -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.WorkItem.Indexing" -State Off
            Set-FeatureFlag -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.WorkItem.CrudOperations" -State Off
            break
        }

        "Wiki"
        {
            Set-FeatureFlag -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.Wiki.Indexing" -State Off
            Set-FeatureFlag -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -FeatureName "Search.Server.Wiki.ContinuousIndexing" -State Off
            break
        }
            
        default
        {
            throw [System.NotImplementedException] "Support for entity type [$_] is not implemented."
        }
    }

    # Waiting for a few seconds for the feature flag changes to get processed
    Start-Sleep -Seconds 5
}

function Invoke-FaultInJob
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,
       
        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,
       
        [Parameter(Mandatory=$True)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType
    )

    Queue-ServiceJob -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionName $CollectionName -JobId (Get-AccountFaultInJobId -EntityType $EntityType)
    Write-Log "Queued [$EntityType] bulk indexing of collection [$CollectionName]."
}

function Get-ServiceRegistryValue
{
    [CmdletBinding()]
    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$False)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [string] $RegistryPath
    )

    $parentPath = "#$(Split-Path $RegistryPath -Parent -ErrorAction Stop)\"
    Write-Log "ParentPath = [$parentPath]." -Level Verbose
    $childItem = "$(Split-Path $RegistryPath -Leaf -ErrorAction Stop)\"
    Write-Log "ChildItem = [$childItem]." -Level Verbose

    if ($CollectionDatabaseName)
    {
        return Invoke-Sqlcmd -Query "SELECT RegValue FROM dbo.tbl_RegistryItems WHERE ParentPath = '$parentPath' AND ChildItem = '$childItem' AND PartitionId = 1" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName | Select-Object -ExpandProperty RegValue
    }
    else
    {
        return Invoke-Sqlcmd -Query "SELECT RegValue FROM dbo.tbl_RegistryItems WHERE ParentPath = '$parentPath' AND ChildItem = '$childItem' AND PartitionId = 1" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName | Select-Object -ExpandProperty RegValue
    }
}

function Set-ServiceRegistryValue
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$False)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [string] $RegistryPath,

        [Parameter(Mandatory=$False)]
        [string] $Value
    )

    if (!$Value)
    {
        $Value = "NULL"
    }
    else
    {
        $Value = "'$Value'"
    }

    $parentPath = "#$(Split-Path $RegistryPath -Parent -ErrorAction Stop)\"
    Write-Log "ParentPath = [$parentPath]." -Level Verbose
    $childItem = "$(Split-Path $RegistryPath -Leaf -ErrorAction Stop)\"
    Write-Log "ChildItem = [$childItem]." -Level Verbose

    if ($CollectionDatabaseName)
    {
        $command = "EXEC prc_SetRegistryValue @partitionId = 1, @key = '$parentPath$childItem', @value = $Value"
        Write-Log "Command = $command" -Level Verbose
        Invoke-Sqlcmd -Query $command -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName
    }
    else
    {
        $command = "EXEC prc_SetRegistryValue @partitionId = 1, @key = '$parentPath$childItem', @value = $Value"
        Write-Log "Command = $command" -Level Verbose
        Invoke-Sqlcmd -Query $command -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName
    }
}

function Get-FeatureFlag
{
    [CmdletBinding()]
    [OutputType([bool])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [string] $FeatureName
    )

    $parentPath = "#\FeatureAvailability\Entries\$FeatureName\"
    $childItem = "AvailabilityState\"

    if ($CollectionDatabaseName)
    {
        $collectionHostValue = Invoke-Sqlcmd -Query "SELECT RegValue from dbo.tbl_RegistryItems WHERE ParentPath = '$parentPath' AND ChildItem = '$childItem' AND PartitionId = 1" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName | Select-Object -ExpandProperty RegValue
        Write-Log "State of feature flag [$FeatureName] in collection DB is [$collectionHostValue]." -Level Verbose
        $deploymentHostValue = Invoke-Sqlcmd -Query "SELECT RegValue from dbo.tbl_RegistryItems WHERE ParentPath = '$parentPath' AND ChildItem = '$childItem' AND PartitionId = 1" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName | Select-Object -ExpandProperty RegValue
        Write-Log "State of feature flag [$FeatureName] in configuration DB is [$deploymentHostValue]." -Level Verbose

        $effectiveValue =  (($deploymentHostValue -eq 1 -and $collectionHostValue -eq $null) -or ($deploymentHostValue -eq $null -and $collectionHostValue -eq 1) -or ($deploymentHostValue -eq 1 -and $collectionHostValue -eq 1))
        return $effectiveValue
    }
    else
    {
        $deploymentHostValue = Invoke-Sqlcmd -Query "SELECT RegValue from dbo.tbl_RegistryItems WHERE ParentPath = '$parentPath' AND ChildItem = '$childItem' AND PartitionId = 1" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName | Select-Object -ExpandProperty RegValue
        return $deploymentHostValue -eq 1
    }
}

function Set-FeatureFlag
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$False)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [string] $FeatureName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("On", "Off", "Undefined")]
        [string] $State
    )

    $parentPath = "#\FeatureAvailability\Entries\$FeatureName\"
    $childItem = "AvailabilityState\"

    $regValue = 'NULL'
    if ($State -eq "On")
    {
        $regValue = '1'
    }
    elseif ($State -eq "Off")
    {
        $regValue = '0'
    }

    if ($CollectionDatabaseName)
    {
        Invoke-Sqlcmd -Query "EXEC prc_SetRegistryValue @partitionId = 1, @key = '$parentPath$childItem', @value = $regValue" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName
    }
    else
    {
        Invoke-Sqlcmd -Query "EXEC prc_SetRegistryValue @partitionId = 1, @key = '$parentPath$childItem', @value = $regValue" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName
    }
}

function Queue-ServiceJob
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$False)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [guid] $JobId
    )

    if (!$CollectionName) # Deployment host job
    {
        $hostId = Get-DeploymentHostId -SqlServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName
    }
    else # Collection host job
    {
        $hostId = Get-CollectionId -SqlServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionName $CollectionName
    }

    $sqlParams = "HostId='$hostId'", "JobId='$JobId'"
    $sqlFilePath = "$PSScriptRoot\..\SqlScripts\QueueJob.sql"
    $response = Invoke-Sqlcmd -InputFile $sqlFilePath -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName -Variable $sqlParams
}

function Test-BulkIndexingIsInProgress
{
    [CmdletBinding()]
    [OutputType([bool])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,

        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,
       
        [Parameter(Mandatory=$True)]
        [string] $CollectionDatabaseName,

        [Parameter(Mandatory=$True)]
        [string] $CollectionName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType
    )
    
    $collectionId = Get-CollectionId -SqlServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionName $CollectionName
    
    # If fault-in job in queue or in progress, bulk indexing is in progress.
    $faultInJobQueueTime = Invoke-Sqlcmd -Query "SELECT QueueTime FROM dbo.tbl_JobQueue WHERE JobSource = '$collectionId' AND JobId = '$(Get-AccountFaultInJobId -EntityType $EntityType)' AND JobState >= 0" -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName | Select-Object -ExpandProperty QueueTime
    if ($faultInJobQueueTime)
    {
        return $true
    }

    # If collection indexing unit is not present, bulk indexing is not in progress.
    $collectionIndexingUnitId = Invoke-Sqlcmd -Query "SELECT IndexingUnitId FROM Search.tbl_IndexingUnit WHERE TfsEntityId = '$collectionId' AND EntityType = '$EntityType' AND IndexingUnitType = 'Collection' AND IsDeleted = 0" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName | Select-Object -ExpandProperty IndexingUnitId
    if (!$collectionIndexingUnitId)
    {
        return $false
    }
    
    # If crawl metadata operation is in queue or in progress, bulk indexing is in progress.
    $crawlMetadataOperationId = Invoke-Sqlcmd -Query "SELECT Id FROM Search.tbl_IndexingUnitChangeEvent WHERE IndexingUnitId = $collectionIndexingUnitId AND ChangeType = 'CrawlMetadata' AND State IN ('Pending', 'Queued', 'InProgress')" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName | Select-Object -ExpandProperty Id
    if ($crawlMetadataOperationId)
    {
        return $true
    }
    
    # If collection begin bulk indexing operation is in queue or in progress, bulk indexing is in progress.
    $collectionBeginBulkIndexOperationId = Invoke-Sqlcmd -Query "SELECT Id FROM Search.tbl_IndexingUnitChangeEvent WHERE IndexingUnitId = $collectionIndexingUnitId AND ChangeType = 'BeginBulkIndex' AND State IN ('Pending', 'Queued', 'InProgress')" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName | Select-Object -ExpandProperty Id
    if ($collectionBeginBulkIndexOperationId)
    {
        return $true
    }
    
    # If collection complete bulk indexing operation is in queue or in progress, bulk indexing is in progress.
    $collectionCompleteBulkIndexOperationId = Invoke-Sqlcmd -Query "SELECT Id FROM Search.tbl_IndexingUnitChangeEvent WHERE IndexingUnitId = $collectionIndexingUnitId AND ChangeType = 'CompleteBulkIndex' AND State IN ('Pending', 'Queued', 'InProgress')" -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName | Select-Object -ExpandProperty Id
    if ($collectionCompleteBulkIndexOperationId)
    {
        return $true
    }

    return $false # Bulk indexing is not in progress.
}

function Get-EntityTypeId
{
    [CmdletBinding()]
    [OutputType([int])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType
    )

    switch ($EntityType)
    {
        "Code" { return 1 }
        "WorkItem" { return 4 }
        "Wiki" { return 6 }
        
        default
        {
            throw [System.NotImplementedException] "Support for entity type [$_] is not implemented."
        }
    }
}

function Get-AccountFaultInJobId
{
    [CmdletBinding()]
    [OutputType([guid])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType
    )

    switch ($EntityType)
    {
        "Code" { return "02f271f3-0d40-4fa0-9328-c77ebca59b6f" }
        "WorkItem" { return "03cee4b8-ecc1-4e57-95ce-fa430fe0dbfb" }
        "Wiki" { return "27b11fd5-1da5-48b4-a732-761ce99f5a5f" }
        
        default
        {
            throw [System.NotImplementedException] "Support for entity type [$_] is not implemented."
        }
    }
}

function Get-SupportedDocumentContractType
{
    [CmdletBinding()]
    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $SQLServerInstance,
        
        [Parameter(Mandatory=$True)]
        [string] $ConfigurationDatabaseName,

        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType
    )

    $registryPath = $null
    switch ($EntityType)
    {
        "Code" 
        {
            $registryPath = "\Service\ALMSearch\Settings\DefaultCodeDocumentContractType" 
            break
        }
        
        "WorkItem" 
        {
            $registryPath = "\Service\ALMSearch\Settings\WorkItemDocumentContractType" 
            break
        }
        
        "Wiki" 
        { 
            $registryPath = "\Service\ALMSearch\Settings\WikiDocumentContractType" 
            break
        }
        
        default
        {
            throw [System.NotImplementedException] "Support for entity type [$_] is not implemented."
        }
    }

    $supportedContractType = Get-ServiceRegistryValue -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -RegistryPath $registryPath
    Write-Log "Supported document contract type for entity type [$EntityType] = [$supportedContractType]." -Level Verbose
    return $supportedContractType
}

function Get-ExpectedDocumentContractType
{
    [CmdletBinding()]
    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [ValidateSet("Code", "WorkItem", "Wiki")]
        [string] $EntityType
    )

    switch ($EntityType)
    {
        "Code" { return "SourceNoDedupeFileContractV3" }
        "WorkItem" { return "WorkItemContract" }
        "Wiki" { return "WikiContract" }
        
        default
        {
            throw [System.NotImplementedException] "Support for entity type [$_] is not implemented."
        }
    }
}

function Get-MappingName
{
    [CmdletBinding()]
    [OutputType([string])]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $DocumentContractType
    )

    # This logic must be in sync with Microsoft.VisualStudio.Services.Search.Common.Enums.DocumentContractTypeExtension.GetMappingName() method.
    switch ($DocumentContractType)
    {
        "Unsupported" { throw [System.NotSupportedException] }
        "WorkItem" { return "workItemContract" }
        "PackageVersionContract" { return $_.ToLowerInvariant() }
        "ProjectContract" {}
        "RepositoryContract" { return "projectRepoContract" }
        default { return $_ }
    }
}

function Write-Log
{
    [CmdletBinding()]
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $Message,

        [Parameter(Mandatory=$False)]
        [ValidateSet("Verbose", "Info", "Warn", "Error", "Attention")]
        [string] $Level = "Info"
    )

    $foregroundColor = $null
    $backgroundColor = $null
    
    switch ($Level)
    {
        "Verbose" 
        {
            if ($RepairSearchVerbosePreference -eq "Continue")
            {
                $foregroundColor = "Yellow"
                $backgroundColor = "Black"
            }

            break
        }

        "Info" 
        {
            $foregroundColor = "White"
            break
        }

        "Warn" 
        {
            $foregroundColor = "Cyan"
            break
        }

        "Error" 
        {
            $foregroundColor = "Red"
            break
        }

        "Attention" 
        {
            $foregroundColor = "Black"
            $backgroundColor = "Cyan"
            break
        }

        default
        {
            throw [NotSupportedException] "Level [$_] is not supported."
        }
    }

    $msg = "[$(((Get-Date).ToUniversalTime()).ToString(`"yyyy-MM-ddTHH:mm:ssZ`"))][$Level] $Message"
    if ($foregroundColor)
    {
        if (!$backgroundColor)
        {
            Write-Host $msg -ForegroundColor $foregroundColor
        }
        else
        {
            Write-Host $msg -ForegroundColor $foregroundColor -BackgroundColor $backgroundColor
        }
    }

    Add-Content -Path $LogFilePath $msg
}