Import-Module $PSScriptRoot\Helper.psm1
Import-Module $PSScriptRoot\Logger.psm1
Import-Module $PSScriptRoot\FunctionHelper.psm1
Import-Module $PSScriptRoot\Constants.psm1 -Force
Import-Module $PSScriptRoot\WindowsServiceHelper.psm1
Import-Module $PSScriptRoot\ElasticsearchConfig.psm1

function CopyElasticsearchArtifacts
{
    [CmdletBinding()]
    Param
    (
        [string] $ElasticsearchInstallPath,
        [string] $ElasticsearchZipPath,
        [string] $AlmsearchPluginZipPath,
        [string] $ElasticsearchRelevancePath,
        [string] $ElasticsearchLoggingPath
    )
    
    ExtractFiles $ElasticsearchZipPath $ElasticsearchInstallPath -Verbose:$VerbosePreference

    #copy relevance
    $esRelevanceInstallPath = Join-Path $ElasticsearchInstallPath $ElasticsearchConfigConstants.ElasticsearchConfigPath
    LogVerbose "Copying $ElasticsearchRelevancePath to $esRelevanceInstallPath"
    Copy-Item $ElasticsearchRelevancePath $esRelevanceInstallPath

    #copy logging config file
    $esLoggingInstallPath = Join-Path $ElasticsearchInstallPath $ElasticsearchConfigConstants.ElasticsearchConfigPath
    LogVerbose "Copying $ElasticsearchLoggingPath to $esLoggingInstallPath"
    Copy-Item $ElasticsearchLoggingPath $esLoggingInstallPath
}

function StageElasticsearch
{
    <#
        .DESCRIPTION
        Copies all the artifacts to install elasticsearch

        .PARAMETER ElasticsearchInstallPath
        Path where elasticsearch will be installed

        .PARAMETER ElasticsearchZipPath
        Path of the zip file containing elasticsearch binaries

        .PARAMETER AlmsearchPluginZipPath
        path of almsearch plugin zip file

        .PARAMETER ElasticsearchRelevancePath
        path of relevance.xml

        .PARAMETER ElasticsearchLoggingPath
        path of log4j2.properties

        .PARAMETER ElasticsearchIndexPath
        path where indices will be stored

        .PARAMETER Port
        port on which Elasticsearch will be running

        .PARAMETER IgnoreEnvironmentVariable
        switch to indicate whether to use environment variable or use the user input.
        If not present, script will set SEARCH_ES_INDEX_PATH as path.data in elasticsearch.yml file and
        update this environment variable to point to the ElasticsearchIndexPath folder specified by user.
        If present, script will set path.data to ElasticsearchIndexPath but would not update the 
        environment variable SEARCH_ES_INDEX_PATH.

        .PARAMETER ClusterName
        name of the elasticsearch cluster.
        
        .PARAMETER user
        user
        
        .PARAMETER password
        password

    #>
    [CmdletBinding()]
    [OutputType([boolean])]
    Param
    (
        [string] $ElasticsearchInstallPath,
        [string] $ElasticsearchZipPath,
        [string] $AlmsearchPluginZipPath,
        [string] $ElasticsearchRelevancePath,
        [string] $ElasticsearchLoggingPath,
        [string] $ElasticsearchIndexPath,
        [int] $Port,
        [switch] $IgnoreEnvironmentVariable,
        [string] $ClusterName,
        [string] $User,
        [string] $Password
    )

    if (-Not (Test-Path -Path $ElasticsearchZipPath))
    {
        LogError "Elasticsearch does not exist at: $ElasticsearchZipPath"
        return $false
    }
    
    if (-Not (Test-Path -Path $AlmsearchPluginZipPath))
    {
        LogError "Almsearch plugin does not exist at: $AlmsearchPluginZipPath"
        return $false
    }

    if ($Port -lt $ElasticsearchConfigConstants.MinESPort -Or $Port -gt $ElasticsearchConfigConstants.MaxESPort)
    {
        LogError "Elasticsearch port should be within the range 9200-9299."
        return $false
    }

    if (-Not (Test-Path -Path $ElasticsearchInstallPath))
    {
        LogVerbose "Elasticsearch InstallPath: $ElasticsearchInstallPath does not exists"
        LogVerbose "Creating folder: $ElasticsearchInstallPath"
        if (-not (InvokeFunction { New-Item $ElasticsearchInstallPath -type directory -ErrorAction Stop }))
        {
            return $false
        }
    }

    if (-Not (Test-Path -Path $ElasticsearchIndexPath))
    {
        LogVerbose "Elasticsearch IndexPath does not exists at: $ElasticsearchIndexPath"
        LogVerbose "Creating folder: $ElasticsearchIndexPath"
        if(-not (InvokeFunction { New-Item $ElasticsearchIndexPath -type directory -ErrorAction Stop }))
        {
            return $false
        }
    }
    
    if (-not (InvokeFunction { CopyElasticsearchArtifacts $ElasticsearchInstallPath $ElasticsearchZipPath $AlmsearchPluginZipPath $ElasticsearchRelevancePath $ElasticsearchLoggingPath -ErrorAction Stop -Verbose:$VerbosePreference}))
    {
        return $false
    }

    $indexPath = '${SEARCH_ES_INDEX_PATH}'

    if ($IgnoreEnvironmentVariable)
    {
        $indexPath = $ElasticsearchIndexPath
    }

    #Set Elasticsearch config
    LogVerbose "Setting Elasticsearch configuration: $($ElasticsearchConfigConstants.ElasticsearchYMLPath)"

    $esSettings = GetElasticSearchConfig $indexPath $Port $ClusterName $User $Password
    $esSettingsFilePath = Join-Path $ElasticsearchInstallPath $ElasticsearchConfigConstants.ElasticsearchYMLPath
    ConvertToJson $esSettings | Out-File -Encoding UTF8 $esSettingsFilePath -Verbose:$VerbosePreference

    #Set SEARCH_ES_INDEX_PATH
    if ( -not($IgnoreEnvironmentVariable))
    {
        LogMessage "Setting environment variable 'SEARCH_ES_INDEX_PATH' as $ElasticsearchIndexPath"
        [Environment]::SetEnvironmentVariable($ElasticsearchConfigConstants.SearchIndexPathEnvVar, $ElasticsearchIndexPath, "Machine")
        [Environment]::SetEnvironmentVariable($ElasticsearchConfigConstants.SearchIndexPathEnvVar, $ElasticsearchIndexPath, "Process")
    }

    LogMessage "Removing environment variable $($ElasticsearchConfigConstants.ESHeapSizeEnvironmentVar)"
    [Environment]::SetEnvironmentVariable($ElasticsearchConfigConstants.ESHeapSizeEnvironmentVar, $null, "Machine")
    [Environment]::SetEnvironmentVariable($ElasticsearchConfigConstants.ESHeapSizeEnvironmentVar, $null, "Process")

    LogMessage "Removing environment variable $($ElasticsearchConfigConstants.ESJavaOptsEnvironmentVar)"
    [Environment]::SetEnvironmentVariable($ElasticsearchConfigConstants.ESJavaOptsEnvironmentVar, $null, "Machine")
    [Environment]::SetEnvironmentVariable($ElasticsearchConfigConstants.ESJavaOptsEnvironmentVar, $null, "Process")
    
    # TODO Use for JVM settings - add retries
    Update-ElasticSearchJvmOptions
    return $true
}

function UpdateElasticsearchConfig
{
    <#
        .DESCRIPTION
        updates elasticsearch config.yml and relevance

        .PARAMETER ElasticsearchInstallPath
        Path where elasticsearch will be installed

        .PARAMETER ElasticsearchRelevancePath
        path of relevance.xml

        .PARAMETER Port
        port on which Elasticsearch will be running

        .PARAMETER IgnoreEnvironmentVariable
        switch to indicate whether to use environment variable or use the user input.
        If not present, script will set SEARCH_ES_INDEX_PATH as path.data in elasticsearch.yml file and
        update this environment variable to point to the ElasticsearchIndexPath folder specified by user.
        If present, script will set path.data to ElasticsearchIndexPath but would not update the 
        environment variable SEARCH_ES_INDEX_PATH.

        .PARAMETER ClusterName
        name of the elasticsearch cluster.
        
        .PARAMETER user
        user
        
        .PARAMETER password
        password

    #>
    [CmdletBinding()]
    [OutputType([boolean])]
    Param
    (
        [string] $ElasticsearchInstallPath,
        [string] $ElasticsearchRelevancePath,
        [string] $ElasticsearchIndexPath,
        [int] $Port,
        [string] $ClusterName,
        [string] $User,
        [string] $Password
    )

    #copy relevance
    $esRelevanceInstallPath = Join-Path $ElasticsearchInstallPath $ElasticsearchConfigConstants.ElasticsearchConfigPath
    LogVerbose "Copying $ElasticsearchRelevancePath to $esRelevanceInstallPath"
    Copy-Item $ElasticsearchRelevancePath $esRelevanceInstallPath
    
    #Set Elasticsearch config
    LogVerbose "Setting Elasticsearch configuration: $($ElasticsearchConfigConstants.ElasticsearchYMLPath)"
    $esSettings = GetElasticSearchConfig $ElasticsearchIndexPath $Port $ClusterName $User $Password
    $esSettingsFilePath = Join-Path $ElasticsearchInstallPath $ElasticsearchConfigConstants.ElasticsearchYMLPath
    ConvertToJson $esSettings | Out-File -Encoding UTF8 $esSettingsFilePath -Verbose:$VerbosePreference
    return $true
}

function InstallElasticsearch
{
    <#
        .DESCRIPTION
        Installs the elasticsearch windows service

        .PARAMETER ServiceBatPath
        path of the service.bat file used to install the elasticsearch      
        
        .PARAMETER ServiceName
        Name with which elasticsearch service will be installed

        .PARAMETER ServiceAccount
        Account with which elasticsearch service will run
    #>
    [CmdletBinding()]
    [OutputType([boolean])]
    Param
    (
        [string] $ServiceBatPath,
        [string] $ServiceName,
        [string] $ServiceAccount
    )
    
    if (-Not (Test-Path -Path $ServiceBatPath))
    {
        LogError "Elasticsearch elasticsearch-service.bat not found at: $ServiceBatPath"
        return $false
    }

    $dummySecPassword = ConvertTo-SecureString 'dummy' -AsPlainText -Force
    $ElasticsearchServiceCredential = New-Object System.Management.Automation.PSCredential($ServiceAccount, $dummySecPassword)
    
    [Environment]::SetEnvironmentVariable("SERVICE_USERNAME", $ElasticsearchServiceCredential.UserName, "Process")
    [Environment]::SetEnvironmentVariable("SERVICE_PASSWORD", $ElasticsearchServiceCredential.GetNetworkCredential().Password, "Process")

    LogVerbose "Installing Elasticsearch with name $ServiceName"
    $output = & $ServiceBatPath install $ServiceName 2>&1 | Out-String
    LogVerbose "Elasticsearch output: $output" 
    
    $successCondition = { IsServiceInstalled $ServiceName }

    $retryCount = $ElasticsearchServiceRetryConstants.RetryCount
    Do
    {
        LogVerbose "Waiting for the windows service: $ServiceName to be installed ..."
        Start-Sleep -Seconds 5
        $retryCount = $retryCount - 1
    }
    while(-not (& $successCondition) -and $retryCount -gt 0)
    
    if (& $successCondition)
    {
        LogVerbose "Elasticsearch has been installed."
    }    
    else
    {
        LogError 'Error installing the elasticsearch'
        return $false
    }

    LogVerbose "Setting $ServiceName startup type to 'Automatic (Delayed)'"
    $scConfigOutput = & sc.exe Config $ServiceName Start= Delayed-Auto
    LogVerbose $scConfigOutput
    
    LogVerbose "Setting the recovery options for $ServiceName"
    $scRecoveryOutput = & sc.exe failure $ServiceName reset= 86400 actions= restart/60000/restart/60000/restart/60000
    LogVerbose $scRecoveryOutput

    return $true
}

function StartElasticsearch
{
    <#
        .DESCRIPTION
        Starts the elasticsearch windows service

        .PARAMETER ServiceBatPath
        path of the service.bat file used to start the elasticsearch   
        
        .PARAMETER ServiceName
        Name with which elasticsearch service will be installed    
    #>
    [CmdletBinding()]
    [OutputType([boolean])]
    Param
    (
        [String]$ServiceBatPath,
        [String]$ServiceName
    )
    
    if (-Not (Test-Path -Path $ServiceBatPath))
    {
        LogVerbose "Elasticsearch elasticsearch-service.bat not found at: $ServiceBatPath"
        return $false
    }

    LogVerbose 'Starting Elasticsearch'
    $output = & $ServiceBatPath start $ServiceName 2>&1 | Out-String
    LogVerbose "Elasticsearch output: $output"
    
    $successCondition = { IsServiceRunning $ServiceName }
    $retryCount = $ElasticsearchServiceRetryConstants.RetryCount
    Do
    {
        LogVerbose "Waiting for the Windows service: $ServiceName to start ..."
        Start-Sleep -Seconds 5
        $retryCount = $retryCount - 1
    }
    while(-not (& $successCondition) -and $retryCount -gt 0)

    if (& $successCondition)
    {
        LogVerbose 'Elasticsearch was successfully started.'
    }
    else
    {
        LogVerbose 'Error starting the elasticsearch'
        return $false
    }
    
    return $true
}

function StopElasticsearch
{
    <#
        .DESCRIPTION
        Removes the elasticsearch windows service from the system

        .PARAMETER ServiceBatPath
        path of the service.bat file used to remove the elasticsearch        

        .PARAMETER ServiceName
        Name with which elasticsearch service will be installed 
    #>
    [CmdletBinding()]
    param
    (
        [string] $ServiceBatPath,
        [string] $ServiceName
        
    )

    if (-Not (Test-Path -Path $ServiceBatPath))
    {
        LogError "File not found: $ServiceBatPath"
        return;
    }
 
    $output = & $ServiceBatPath stop $ServiceName 2>&1 | Out-String

    LogVerbose "Elasticsearch output: $output"
    
    $successCondition = { -not (IsServiceRunning $ServiceName) }
    $retryCount = $ElasticsearchServiceRetryConstants.RetryCount
    Do
    {
        LogVerbose "Waiting for the Windows service: $ServiceName to be stopped ..."
        Start-Sleep -Seconds 5
        $retryCount = $retryCount - 1
    }
    while(-not (& $successCondition) -and $retryCount -gt 0)
    
    if (& $successCondition)
    {
        LogVerbose 'Elasticsearch has been stopped'
    }    
    else
    {
        LogError 'Error stopping Elasticsearch'    
    }
}

function UninstallElasticsearch
{
    <#
        .DESCRIPTION
        Removes the elasticsearch windows service from the system

        .PARAMETER ServiceBatPath
        path of the service.bat file used to remove the elasticsearch      
        
        .PARAMETER ServiceName
        Name with which elasticsearch service will be installed   
    #>
    [CmdletBinding()]
    param
    (
        [string] $ServiceBatPath,
        [string] $ServiceName
    )

    if (-Not (Test-Path -Path $ServiceBatPath))
    {
        LogError "File not found: $ServiceBatPath"
        return;
    }    

    [Environment]::SetEnvironmentVariable($ElasticsearchConfigConstants.ESHeapSizeEnvironmentVar, $null, "Machine")
    [Environment]::SetEnvironmentVariable($ElasticsearchConfigConstants.ESHeapSizeEnvironmentVar, $null, "Process")   

    $output = & $ServiceBatPath remove $ServiceName 2>&1 | Out-String    

    LogVerbose "Elasticsearch output: $output"

    $successCondition = { -not (IsServiceInstalled $ServiceName) }
    $retryCount = $ElasticsearchServiceRetryConstants.RetryCount
    Do
    {
        LogVerbose "Waiting for the windows service:$ServiceName to be competely removed from the system ..."
        Start-Sleep -Seconds 5
        $retryCount = $retryCount - 1
    }
    while(-not (& $successCondition) -and $retryCount -gt 0)

    if (& $successCondition)
    {
        LogVerbose 'Elasticsearch has been removed'
    }
    else
    {
        LogError 'Error removing Elasticsearch'    
    }
}

function ParseElasticsearchPort
{
    <#
        .DESCRIPTION
        Parses the port from the elasticsearch configuration file (elasticsearch.yml)

        .PARAMETER elasticsearchConfigFile
        path of the elasticsearch.yml        
    #>
    [CmdletBinding()]
    Param
    (
        [string] $elasticsearchConfigFile
    )

    if (-not (Test-Path $elasticsearchConfigFile))
    {
        LogError "File does not exist: $elasticsearchConfigFile"
        return 9200
    }

    $config = ReadJsonFromFile $elasticsearchConfigFile

    if ($config -eq $null)
    {
        LogWarning "Unable to parse port from: $elasticsearchConfigFile"
        LogVerbose 'Defaulting to port 9200'
        return 9200
    }
    LogVerbose "Elasticsearch port successfully detected: $($config."http.port")"

    return $config."http.port"
}

function ParseElasticsearchIndexPath
{
    <#
        .DESCRIPTION
        Parses the Elasticsearch index path from the elasticsearch configuration file (elasticsearch.yml)

        .PARAMETER elasticsearchConfigFile
        path of the elasticsearch.yml        
    #>
    [CmdletBinding()]
    Param
    (
        [string] $elasticsearchConfigFile
    )

    if (-not (Test-Path $elasticsearchConfigFile))
    {
        LogError "File does not exist: $elasticsearchConfigFile"
        return ""
    }

    $config = ReadJsonFromFile $elasticsearchConfigFile

    if ($config -eq $null)
    {
        LogWarning "Unable to parse index path from: $elasticsearchConfigFile"
        return ""
    }
    LogVerbose "Elasticsearch index path successfully detected: $($config."path.data")"

    return $config."path.data"
}

function ParseElasticsearchConfigValue
{
    <#
        .DESCRIPTION
        Parses the port from the elasticsearch configuration file (elasticsearch.yml)

        .PARAMETER elasticsearchConfigFile
        path of the elasticsearch.yml

        .PARAMETER configName
        name of the config
    #>
    [CmdletBinding()]
    Param
    (
        [string] $elasticsearchConfigFile,
        [string] $configName
    )

    if (-not (Test-Path $elasticsearchConfigFile))
    {
        LogWarning "Unable to parse $configName from: $elasticsearchConfigFile"
        return ""
    }

    $content = [IO.File]::ReadAllText($elasticsearchConfigFile)
    $config = ConvertFromJson $content
    if ($config -eq $null)
    {
        LogWarning "Unable to parse $configName from: $elasticsearchConfigFile"
        return ""
    }
    LogVerbose "Elasticsearch $configName successfully detected: $($config.$($configName))"

    return $config."$($configName)"
}

function ParseElasticsearchClusterName
{
    <#
        .DESCRIPTION
        Parses the Elasticsearch cluster name from the elasticsearch configuration file (elasticsearch.yml)

        .PARAMETER elasticsearchConfigFile
        path of the elasticsearch.yml        
    #>
    [CmdletBinding()]
    Param
    (
        [string] $elasticsearchConfigFile
    )

    if (-not (Test-Path $elasticsearchConfigFile))
    {
        LogError "File does not exist: $elasticsearchConfigFile"
        LogVerbose 'Defaulting to TFS_Search_${COMPUTERNAME}'
        return 'TFS_Search_${COMPUTERNAME}'
    }
   
    $config = ReadJsonFromFile $elasticsearchConfigFile
    if ($config -eq $null)
    {
        LogWarning "Unable to parse cluster name from: $elasticsearchConfigFile"
        LogVerbose 'Defaulting to TFS_Search_${COMPUTERNAME}'
        return 'TFS_Search_${COMPUTERNAME}'
    }

    LogVerbose "Elasticsearch cluster name successfully detected: $($config."cluster.name")"

    return $config."cluster.name"
}

function ReadJsonFromFile
{
    <#
        .DESCRIPTION
        read text from a file

        .PARAMETER elasticsearchConfigFile
        path of the elasticsearch.yml
    #>
    [CmdletBinding()]
    Param
    (
        [string] $elasticsearchConfigFile
    )

    $content = [IO.File]::ReadAllText($elasticsearchConfigFile)
    $config = ConvertFromJson $content

    return $config
}

function Update-ElasticSearchJvmOptions
{
    <#
        .DESCRIPTION
        Updates elasticsearch JVM options file
    #>
    [CmdletBinding()]
    Param
    ()

    $memoryInGB = GetPhysicalMemoryInGB
    $adjustedMemoryInMB = [int][System.Math]::Min($JavaConstants.ESMaxHeapSizeInMB, $memoryInGB * 1024 * 0.5)

    # Check whether $adjustedMemoryInMB satisfies the minimum heap size criterion.
    if ($adjustedMemoryInMB -lt $JavaConstants.ESMinHeapSizeInMB)
    {
        LogWarning "System does not satisfy minimum heap size requirements."
        LogWarning "Available memory for heap allocation: $adjustedMemoryInMB"
        LogWarning "Minimum heap requirements: $($JavaConstants.ESMinHeapSizeInMB)"
    }

    $adjustedMemoryInMBString = "$adjustedMemoryInMB"+"m"
    
    # Setup jvm.options file content
    LogVerbose "Setting jvm.options : $($ElasticsearchConfigConstants.ElasticsearchJVMOptionsPath)"
    $jvmOptions = @{
        # Heap size
        "MinHeapSize" = "-Xms$adjustedMemoryInMBString"
        "MaxHeapSize" = "-Xmx$adjustedMemoryInMBString"

        ## GC configuration
        "UseConcMarkSweepGC" = "-XX:+UseConcMarkSweepGC"
        "CMSInitiatingOccupancyFraction" = "-XX:CMSInitiatingOccupancyFraction=75"
        "UseCMSInitiatingOccupancyOnly" = "-XX:+UseCMSInitiatingOccupancyOnly"

        ## optimizations

        # pre-touch memory pages used by the JVM during initialization
        "AlwaysPreTouch" = "-XX:+AlwaysPreTouch"

        ## basic

        # force the server VM (remove on 32-bit client JVMs)
        "Server" = "-server"

        # explicitly set the stack size (reduce to 320k on 32-bit client JVMs)
        "StackSize" = "-Xss1m"

        # set to headless, just in case
        "Headless" = "-Djava.awt.headless=true"

        # ensure UTF-8 encoding by default (e.g. filenames)
        "UTF8" = "-Dfile.encoding=UTF-8"

        # use our provided JNA always versus the system one
        "JNA" = "-Djna.nosys=true"

        # use old-style file permissions on JDK9
        "PermissionsUseCanonicalPath" = "-Djdk.io.permissionsUseCanonicalPath=true"

        # flags to configure Netty
        "NettyNoUnsafe" = "-Dio.netty.noUnsafe=true"
        "NettyNoKeySetOptimization" = "-Dio.netty.noKeySetOptimization=true"
        "NettyRecyclerMaxCapacityPerThread" = "-Dio.netty.recycler.maxCapacityPerThread=0"

        # log4j 2
        "Log4jDisableShutdownHook" = "-Dlog4j.shutdownHookEnabled=false"
        "Log4jDisableJMX" = "-Dlog4j2.disable.jmx=true"
        "SkipJansi" = "-Dlog4j.skipJansi=true"

        ## heap dumps

        # generate a heap dump when an allocation from the Java heap fails
        # heap dumps are created in the working directory of the JVM
        "HeapDumpOnOutOfMemoryError" = "-XX:+HeapDumpOnOutOfMemoryError"
    }

    $elasticsearchJVMOptionsFile = Join-Path $ElasticsearchInstallPath $ElasticsearchConfigConstants.ElasticsearchJVMOptionsPath

    $stringBuilder = New-Object -TypeName "System.Text.StringBuilder"
    foreach ($keyValue in $jvmOptions.GetEnumerator() | Sort -Property Value)
    {
        [void]$stringBuilder.AppendLine($keyvalue.Value)
    }

    $newContent = $stringBuilder.ToString().Trim()
    Set-Content -Path $elasticsearchJVMOptionsFile -Value $newContent -Force -ErrorAction Stop
}

function Update-ElasticsearchVersionInRegistry
{
    <#
        .DESCRIPTION
        Updates elasticsearch version in windows registry

    #>
    [CmdletBinding()]
    Param
    ()
    if (-not(Test-Path $ElasticsearchConfigConstants.ESVersionRegistryPath))
    {
        New-Item -Path $ElasticsearchConfigConstants.ESVersionRegistryPath -Force | Out-Null
    }

    New-ItemProperty -Path $ElasticsearchConfigConstants.ESVersionRegistryPath -Name $ElasticsearchConfigConstants.ESVersionRegistryProperty -Value $ElasticsearchConfigConstants.ElasticsearchVersion -PropertyType String -Force
    LogVerbose "Updated elasticsearch version in windows registry: $($ElasticsearchConfigConstants.ElasticsearchVersion)"
}

function Get-ElasticsearchVersionFromRegistry
{
    <#
        .DESCRIPTION
        Gets elasticsearch version in windows registry

    #>
    [CmdletBinding()]
    Param
    ()    
    
    $versionProperty = $ElasticsearchConfigConstants.ESVersionRegistryProperty
    $version = Get-ItemProperty -Path $ElasticsearchConfigConstants.ESVersionRegistryPath -Name $versionProperty -ErrorAction SilentlyContinue
    if ($version -ne $null)
    {        
        return $version."$($versionProperty)"
    }

    return "0.0.0"
}
Export-ModuleMember -Function StageElasticsearch, InstallElasticsearch, StartElasticsearch, StopElasticsearch, UninstallElasticsearch, RemoveElasticsearchEnvironmentVars, ParseElasticsearchPort, Get-ElasticsearchVersionFromRegistry, Update-ElasticsearchVersionInRegistry, ParseElasticsearchIndexPath, ParseElasticsearchClusterName, ParseElasticsearchConfigValue, UpdateElasticsearchConfig
# SIG # Begin signature block
# MIIkSwYJKoZIhvcNAQcCoIIkPDCCJDgCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA90Nxrx/IZfw4x
# 14KBfabQ4yMSCRxFJhA4tTMr3WYFMKCCDYEwggX/MIID56ADAgECAhMzAAABA14l
# HJkfox64AAAAAAEDMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTgwNzEyMjAwODQ4WhcNMTkwNzI2MjAwODQ4WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDRlHY25oarNv5p+UZ8i4hQy5Bwf7BVqSQdfjnnBZ8PrHuXss5zCvvUmyRcFrU5
# 3Rt+M2wR/Dsm85iqXVNrqsPsE7jS789Xf8xly69NLjKxVitONAeJ/mkhvT5E+94S
# nYW/fHaGfXKxdpth5opkTEbOttU6jHeTd2chnLZaBl5HhvU80QnKDT3NsumhUHjR
# hIjiATwi/K+WCMxdmcDt66VamJL1yEBOanOv3uN0etNfRpe84mcod5mswQ4xFo8A
# DwH+S15UD8rEZT8K46NG2/YsAzoZvmgFFpzmfzS/p4eNZTkmyWPU78XdvSX+/Sj0
# NIZ5rCrVXzCRO+QUauuxygQjAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUR77Ay+GmP/1l1jjyA123r3f3QP8w
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDM3OTY1MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAn/XJ
# Uw0/DSbsokTYDdGfY5YGSz8eXMUzo6TDbK8fwAG662XsnjMQD6esW9S9kGEX5zHn
# wya0rPUn00iThoj+EjWRZCLRay07qCwVlCnSN5bmNf8MzsgGFhaeJLHiOfluDnjY
# DBu2KWAndjQkm925l3XLATutghIWIoCJFYS7mFAgsBcmhkmvzn1FFUM0ls+BXBgs
# 1JPyZ6vic8g9o838Mh5gHOmwGzD7LLsHLpaEk0UoVFzNlv2g24HYtjDKQ7HzSMCy
# RhxdXnYqWJ/U7vL0+khMtWGLsIxB6aq4nZD0/2pCD7k+6Q7slPyNgLt44yOneFuy
# bR/5WcF9ttE5yXnggxxgCto9sNHtNr9FB+kbNm7lPTsFA6fUpyUSj+Z2oxOzRVpD
# MYLa2ISuubAfdfX2HX1RETcn6LU1hHH3V6qu+olxyZjSnlpkdr6Mw30VapHxFPTy
# 2TUxuNty+rR1yIibar+YRcdmstf/zpKQdeTr5obSyBvbJ8BblW9Jb1hdaSreU0v4
# 6Mp79mwV+QMZDxGFqk+av6pX3WDG9XEg9FGomsrp0es0Rz11+iLsVT9qGTlrEOla
# P470I3gwsvKmOMs1jaqYWSRAuDpnpAdfoP7YO0kT+wzh7Qttg1DO8H8+4NkI6Iwh
# SkHC3uuOW+4Dwx1ubuZUNWZncnwa6lL2IsRyP64wggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIWIDCCFhwCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAQNeJRyZH6MeuAAAAAABAzAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgY3/Z70jd
# Knus7qN3H8zGL/3UGxTZakO6dc+zWcznm+AwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQClizg6TX2MM0UHkDYcZVGgvqxDpLIMsNDut5nCIiAm
# 2hHwJ9gDQgA9dTW3tF+/EgiVUg/Ar/oSRi7Vgt1XgnljFnuI5Ub+0/oVL4vBpqW8
# vc/ghTEqEk8ZEx09TNJXHXxS6ZsKbRB+uJfbcYlKJvmZA1jxjpWrtDzfnItR696o
# 9mz+7ec5oqUP37R3DGMPRiN711zdtCWpTooivPGaEMkJQ0xKJxvK3iEbuwmFt+kh
# deKjTLrGOssHz6fu8Svq0j3LSoeXOLEp+ZzFNIFLzsXxDEAk4WgBU4C+Ki44BxdB
# 9UcM7yK9f1mDwMf7iCci2nz62N/XpaYOxZfPE+OaEcoYoYITqjCCE6YGCisGAQQB
# gjcDAwExghOWMIITkgYJKoZIhvcNAQcCoIITgzCCE38CAQMxDzANBglghkgBZQME
# AgEFADCCAVQGCyqGSIb3DQEJEAEEoIIBQwSCAT8wggE7AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIA6eAwpI7xqXnIl9N3PUSvigatH/sLeuMSIziKRa
# OZ6nAgZbzfORt9kYEzIwMTgxMDI0MjMzNDE3LjY3MVowBwIBAYACAfSggdCkgc0w
# gcoxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsT
# HE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBU
# U1MgRVNOOjU3QzgtMkQxNS0xQzhCMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
# dGFtcCBTZXJ2aWNloIIPFjCCBnEwggRZoAMCAQICCmEJgSoAAAAAAAIwDQYJKoZI
# hvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# MjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDEwMB4XDTEwMDcwMTIxMzY1NVoXDTI1MDcwMTIxNDY1NVowfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTAwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCpHQ28dxGKOiDs/BOX9fp/aZRrdFQQ1aUKAIKF++18aEssX8XD5WHCdrc+Zitb
# 8BVTJwQxH0EbGpUdzgkTjnxhMFmxMEQP8WCIhFRDDNdNuDgIs0Ldk6zWczBXJoKj
# RQ3Q6vVHgc2/JGAyWGBG8lhHhjKEHnRhZ5FfgVSxz5NMksHEpl3RYRNuKMYa+YaA
# u99h/EbBJx0kZxJyGiGKr0tkiVBisV39dx898Fd1rL2KQk1AUdEPnAY+Z3/1ZsAD
# lkR+79BL/W7lmsqxqPJ6Kgox8NpOBpG2iAg16HgcsOmZzTznL0S6p/TcZL2kAcEg
# CZN4zfy8wMlEXV4WnAEFTyJNAgMBAAGjggHmMIIB4jAQBgkrBgEEAYI3FQEEAwIB
# ADAdBgNVHQ4EFgQU1WM6XIoxkPNDe3xGG8UzaFqFbVUwGQYJKwYBBAGCNxQCBAwe
# CgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0j
# BBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0
# cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2Vy
# QXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRf
# MjAxMC0wNi0yMy5jcnQwgaAGA1UdIAEB/wSBlTCBkjCBjwYJKwYBBAGCNy4DMIGB
# MD0GCCsGAQUFBwIBFjFodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vUEtJL2RvY3Mv
# Q1BTL2RlZmF1bHQuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAFAA
# bwBsAGkAYwB5AF8AUwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUA
# A4ICAQAH5ohRDeLG4Jg/gXEDPZ2joSFvs+umzPUxvs8F4qn++ldtGTCzwsVmyWrf
# 9efweL3HqJ4l4/m87WtUVwgrUYJEEvu5U4zM9GASinbMQEBBm9xcF/9c+V4XNZgk
# Vkt070IQyK+/f8Z/8jd9Wj8c8pl5SpFSAK84Dxf1L3mBZdmptWvkx872ynoAb0sw
# RCQiPM/tA6WWj1kpvLb9BOFwnzJKJ/1Vry/+tuWOM7tiX5rbV0Dp8c6ZZpCM/2pi
# f93FSguRJuI57BlKcWOdeyFtw5yjojz6f32WapB4pm3S4Zz5Hfw42JT0xqUKloak
# vZ4argRCg7i1gJsiOCC1JeVk7Pf0v35jWSUPei45V3aicaoGig+JFrphpxHLmtgO
# R5qAxdDNp9DvfYPw4TtxCd9ddJgiCGHasFAeb73x4QDf5zEHpJM692VHeOj4qEir
# 995yfmFrb3epgcunCaw5u+zGy9iCtHLNHfS4hQEegPsbiSpUObJb2sgNVZl6h3M7
# COaYLeqN4DMuEin1wC9UJyH3yKxO2ii4sanblrKnQqLJzxlBTeCG+SqaoxFmMNO7
# dDJL32N79ZmKLxvHIa9Zta7cRDyXUHHXodLFVeNp3lfB0d4wwP3M5k37Db9dT+md
# Hhk4L7zPWAUu7w2gUDXa7wknHNWzfjUeCLraNtvTX4/edIhJEjCCBPEwggPZoAMC
# AQICEzMAAADo+AcjNuFS1aYAAAAAAOgwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMTgwODIzMjAyNzEyWhcNMTkxMTIzMjAy
# NzEyWjCByjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMG
# A1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046NTdDOC0yRDE1LTFDOEIxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCRJclNRxK+3piyBQKC4aGT+h9BurW4G32UXkZxtQpKZbiFlGuQYLL0sX34t2uA
# p9VWPNDQgZNjO4sT2G0FwRw0laF7UHZty/0Yd6kjfBMt2wvmBsYXcznyF5E1E8hq
# R1/sgY7RV7rtL9G3VpLQv8NotnmKiNuMJRfTpQ/v35JOtxjICIIigkmdDQUm6ecT
# JHbFn22o9wtGqMazrqa/W4LwW6AFvc+bFu0v47FhbrRtqxLUw6z+t99TBg79/7zP
# OMwuC3tqQDKM+9OOWgQCZOYeNO0Numd6dnPxDXVOFaoIJyosiUdC/4wAKnOxvp+W
# CJhJqBSTKz+szom2sYdMugODAgMBAAGjggEbMIIBFzAdBgNVHQ4EFgQUFKBhS2aw
# 5+8pJcocf5GQ+zgcKlMwHwYDVR0jBBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUw
# VgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9j
# cmwvcHJvZHVjdHMvTWljVGltU3RhUENBXzIwMTAtMDctMDEuY3JsMFoGCCsGAQUF
# BwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aS9jZXJ0cy9NaWNUaW1TdGFQQ0FfMjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIw
# ADATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0BAQsFAAOCAQEASY4Rl140
# 5e0zv7vynVQOOuQuozeznMqHUK8FMrJ3oNIxeqTL49mNiSh2kXvlx7a1vRSxuLAn
# D85UIDc2w3craEy9mI2VmdpktF1DzzlbAuQsesP5uVo5ho8NbLQ3QiNFZYiW93nj
# 8UnPaRcTPKzbvtTxwXb7FXB7l4mShYOeh0lPs13QDnjSWbuzLo+WYTDmKx5XWTlW
# Bx2+3EIFjZYAWO+AJUCMQfYXOklzhJQdcZ2nVCAf8LCcUNp+JFFSXzKsdeQdKkZf
# dNPndYTZaiM/u3oT0r2UAq4tOAnF9a6goG/zmuIlFyFfgNZah/GO3U7tw+G3bOvN
# gI0xmS9NaFLSTqGCA6gwggKQAgEBMIH6oYHQpIHNMIHKMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjo1N0M4LTJEMTUt
# MUM4QjElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIlCgEB
# MAkGBSsOAwIaBQADFQBQBDnzeihbJLNeoQxQYYaUhzAWD6CB2jCB16SB1DCB0TEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMebkNpcGhlciBOVFMg
# RVNOOjI2NjUtNEMzRi1DNURFMSswKQYDVQQDEyJNaWNyb3NvZnQgVGltZSBTb3Vy
# Y2UgTWFzdGVyIENsb2NrMA0GCSqGSIb3DQEBBQUAAgUA33th9DAiGA8yMDE4MTAy
# NDIxMjYxMloYDzIwMTgxMDI1MjEyNjEyWjB3MD0GCisGAQQBhFkKBAExLzAtMAoC
# BQDfe2H0AgEAMAoCAQACAhcFAgH/MAcCAQACAhjGMAoCBQDffLN0AgEAMDYGCisG
# AQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwGgCjAIAgEAAgMW42ChCjAIAgEAAgMe
# hIAwDQYJKoZIhvcNAQEFBQADggEBAF0bGkQyJg90leuk45cscEZ5UkppTPTtresO
# KWQ0Lr6wskFqqYx7hFExmHkGEhIFtrFnqG+0y3IjDFHav4hoJrO6cD4zWQVCZdrP
# gsgCV0qZIlKPdVVldardt5RQ5JimlZUtoIM+Px64m4EBAZRuSlq8o21V5Lvu8cPG
# 6kkV4dFahIy1ZOSyiP1bhh1kX4bf88Y/6whzwFlRQBrlUMC0zPGbKhPD4Xs3X3fs
# F6lao/lPPLmLkxtiefLq6H4iCuB4wj7k4sPBw3UQKLlYFoc11IUI6jGInsiQ6f5I
# Dydndt1Lpbq7ppc6wge++isMW0iDFdENh4lx3801szhagPzOGpoxggL1MIIC8QIB
# ATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAOj4ByM24VLV
# pgAAAAAA6DANBglghkgBZQMEAgEFAKCCATIwGgYJKoZIhvcNAQkDMQ0GCyqGSIb3
# DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCDmQS1fCIC6fRxB5cDZXb9LkuUZflPL2cAv
# KO98NqU32TCB4gYLKoZIhvcNAQkQAgwxgdIwgc8wgcwwgbEEFFAEOfN6KFsks16h
# DFBhhpSHMBYPMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAC
# EzMAAADo+AcjNuFS1aYAAAAAAOgwFgQUao76YMQ2xSM8RJnQmurXWODoM/4wDQYJ
# KoZIhvcNAQELBQAEggEAAcD8TNVblD11JkOADJbUGBJUMBvuckBpz5wflftFdZud
# U2IGlQGQKRr8Yvuj6+LpD0bLZGEpyytbNFHf3AhLJDLZQimtbs+rx1Z2rfspgRZM
# uuGCNc/cswclODYN+6qr7any1OJJ4AZRN1wXUMXSm/7lUtfDFKkqVBTjwo9eXN6Q
# CUz+Amj6YFsL8+eJE9MUkx/CpnMJ95XuEDq0qzSX4sZafcwjmBsgTdX6UvvPWuac
# yBorlzesrVdDrHIJqsxHP/1ZW3lbFB2CRHgsYw8OD3LW0RrDXHNXlV5xOmrbJPpL
# saprZMcrfhs0IXmYm5s/AA/B17lGfl6FvMk0OPwukA==
# SIG # End signature block
