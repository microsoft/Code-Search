Set-StrictMode -Version Latest

function Test-SqlHealth
{
    [CmdletBinding(SupportsShouldProcess=$True, ConfirmImpact = "None")]
    [OutputType([string[]])]
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
        [string] $EntityType
    )

    # Verify connection parameters are correct
    Confirm-SqlIsReachable -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName

    # Verify IsSearchConfigured setting in Configuration DB
    Write-Log "Verifying IsSearchConfigured setting in Configuration DB..."

    $configureRegKey = "\Service\ALMSearch\Settings\IsSearchConfigured"
    $isSearchConfigured = Get-ServiceRegistryValue -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -RegistryPath $configureRegKey
    if (!$isSearchConfigured -or $isSearchConfigured -eq "False")
    {
        Write-Log "Search is not configured." -Level Error
        return "Request-ConfigureSearch"
    }

    # Verify SearchUrl setting in Configuration DB
    Write-Log "Verifying Search URL settings in Configuration DB..."

    $atRegKey = "\Service\ALMSearch\Settings\ATSearchPlatformConnectionString"
    $atSearchPlatformConnectionString = Get-ServiceRegistryValue -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -RegistryPath $atRegKey
    if (!$atSearchPlatformConnectionString)
    {
        Write-Log "AT search platform connection string registry key [$atRegKey] not found." -Level Error
        return "Request-ReconfigureSearch"
    }
    
    if ([uri]$atSearchPlatformConnectionString -ne $ElasticsearchServiceUrl)
    {
        throw "Search URL configured [$atSearchPlatformConnectionString] is not equal to [$ElasticsearchServiceUrl]. If the URL provided to the script is incorrect, invoke this script again with the correct URL, else reconfigure Search feature with the correct URL."
    }

    $jaRegKey = "\Service\ALMSearch\Settings\JobAgentSearchPlatformConnectionString"
    $jaSearchPlatformConnectionString = Get-ServiceRegistryValue -SQLServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -RegistryPath $jaRegKey
    if (!$jaSearchPlatformConnectionString)
    {
        Write-Log "JobAgent search platform connection string registry key [$jaRegKey] not found." -Level Error
        return "Request-ReconfigureSearch"
    }
    
    if ([uri]$jaSearchPlatformConnectionString -ne $ElasticsearchServiceUrl)
    {
        throw "Search URL configured [$jaSearchPlatformConnectionString] is not equal to [$ElasticsearchServiceUrl]. If the URL provided to the script is incorrect, invoke this script again with the correct URL, else reconfigure Search feature with the correct URL."
    }

    # Verify entity specific extension is installed
    Write-Log "Verifying $EntityType search extension is installed..."

    $isExtensionInstalled = Test-ExtensionInstalled -SQLServerInstance $SQLServerInstance -CollectionDatabaseName $CollectionDatabaseName -EntityType $EntityType
    if (!$isExtensionInstalled)
    {
        Write-Log "$EntityType search extension is not installed." -Level Error
        return "Request-InstallSearchExtension"
    }

    # Verify primary indexing FFs in Configuration DB
    Write-Log "Verifying primary indexing feature flags..."
    $indexingFeatureFlagsEnabled = Test-IndexingFeatureFlagsAreEnabled -SqlServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionDatabaseName $CollectionDatabaseName -CollectionName $CollectionName -EntityType $EntityType
    if (!$indexingFeatureFlagsEnabled)
    {
        return "Enable-IndexingFeatureFlags"
    }

    # Verify Collection IU properties' Index and Query URL match the configuration DB URL
    # i.e. Connection string from properties <IndexESConnectionString>{URL}</IndexESConnectionString>
    #                                        <QueryESConnectionString>{URL}</QueryESConnectionString>
    Write-Log "Verifying Collection IU properties' Index and Query URL match the configuration DB connection URL..."

    $collectionId = Get-CollectionId -SqlServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -CollectionName $CollectionName

    $collectionPropUrlParams = "CollectionId='$collectionID'", "EntityType='$EntityType'"
    $SqlFullPath = "$PSScriptRoot\..\SqlScripts\SearchCollectionProperties.sql"
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName -Variable $collectionPropUrlParams
    if ($queryResults)
    {
        Write-Verbose "SQL query results: [$($queryResults | Out-String)]."
        
        $colIndexESConnectionString = [uri]($queryResults | Select-Object -ExpandProperty IndexESConnectionString)
        $colQueryESConnectionString = [uri]($queryResults | Select-Object -ExpandProperty QueryESConnectionString)
        if ($colIndexESConnectionString -ne $ElasticsearchServiceUrl)
        {
            Write-Log "Invalid Search URL in Collection IU properties' IndexESConnectionString [$colIndexESConnectionString] for entity type [$EntityType]." -Level Error
            return "Restart-Indexing"
        }
        
        if ($colQueryESConnectionString -ne $ElasticsearchServiceUrl)
        {
            Write-Log "Invalid Search URL in Collection IU properties' QueryESConnectionString [$colQueryESConnectionString] for entity type [$EntityType]." -Level Error
            return "Restart-Indexing"
        }
    }
    else
    {
        Write-Log "Collection indexing unit for entity type [$EntityType] and collection [$CollectionName] not found." -Level Error
        return "Restart-Indexing"
    }
    
    # Verify document contract type in registry is as expected
    $supportedDocumentContractType = Get-SupportedDocumentContractType -SqlServerInstance $SQLServerInstance -ConfigurationDatabaseName $ConfigurationDatabaseName -EntityType $EntityType
    $expectedDocumentContractType = Get-ExpectedDocumentContractType -EntityType $EntityType
    if ($supportedDocumentContractType -ne $expectedDocumentContractType)
    {
        # We have never encountered this discrepancy hence we are throwing instead of fixing
        throw "Expected document contract type for entity type $EntityType is [$expectedDocumentContractType] but found [$supportedDocumentContractType]."
    }

    # Verify Collection IU properties' ES ContractTypes for Indexing and Query
    # i.e. <IndexContractType>{contractType}</IndexContractType>
    #      <QueryContractType>{contractType}</QueryContractType>
    Write-Log "Verifying Collection IU properties' ES ContractTypes for Indexing and Query..."

    $collectionPropUrlParams = "CollectionId='$CollectionID'", "EntityType='$EntityType'"
    $SqlFullPath = "$PSScriptRoot\..\SqlScripts\SearchCollectionProperties.sql"
    $queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $CollectionDatabaseName -Variable $collectionPropUrlParams
    if ($queryResults)
    {
        Write-Verbose "SQL query results: [$($queryResults | Out-String)]."
        
        $colIndexContractType = $queryResults | Select-Object -ExpandProperty IndexContractType
        $colQueryContractType = $queryResults | Select-Object -ExpandProperty QueryContractType
        
        if ($colIndexContractType -ne $supportedDocumentContractType)
        {
            Write-Log "Invalid ES contract type in Collection IU properties' IndexContractType [$colIndexContractType] for entity type [$EntityType]. This can result in indexing failures." -Level Error
            return "Restart-Indexing"
        }
        
        if ($colQueryContractType -ne $supportedDocumentContractType)
        {
            Write-Log "Invalid ES contract type in Collection IU properties' QueryContractType [$colQueryContractType] for entity type [$EntityType]. This can result in indexing failures." -Level Error
            return "Restart-Indexing"
        }
    }
    else
    {
        Write-Log "Collection indexing unit for entity type [$EntityType] and collection [$CollectionName] not found." -Level Error
        return "Restart-Indexing"
    }

    return @() # No actions identified
}