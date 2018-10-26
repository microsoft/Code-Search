Import-Module $PSScriptRoot\SecurityGroupHelper.psm1
Import-Module $PSScriptRoot\JavaHelper.psm1
Import-Module $PSScriptRoot\ElasticsearchHelper.psm1 -Force
Import-Module $PSScriptRoot\FunctionHelper.psm1
Import-Module $PSScriptRoot\WindowsServiceHelper.psm1
Import-Module $PSScriptRoot\Helper.psm1
Import-Module $PSScriptRoot\Logger.psm1
Import-Module $PSScriptRoot\Constants.psm1 -Force
Import-Module $PSScriptRoot\MessageConstants.psm1 -Force
Import-Module $PSScriptRoot\ElasticsearchPluginHelper.psm1 -Force
Import-Module $PSScriptRoot\ElasticsearchCommandHelper.psm1 -Force

function LogFirewallStatus
{
    [CmdletBinding()]
    param()

    $profiles = Get-NetFirewallProfile -All | select name,enabled
    Foreach ($profile in $profiles)
    {
        if ($profile.enabled -eq $false -or $profile.enabled -like 'false')
        {
            LogWarning "Firewall profile '$($profile.name)' is Disabled".
        }
    }
}

function IsSupportedJavaInstalled
{
    [CmdletBinding()]
    param()
    
    LogVerbose 'Detecting Java'
    $javaConfig = DetectJava -Verbose:$VerbosePreference
    if (-Not (IsJavaSupported $javaConfig -Verbose:$VerbosePreference))
    {
        LogError $SupportedJavaNotFoundMessage
        return $false
    }
    
    LogVerbose $ValidJavaInstallationMessage
    return $true
}

function AddServiceAccountToSecurityGroup
{
    [CmdletBinding()]
    param
    (
        [string] $ServiceAccount
    )

    try
    {
        if (-not (SecurityGroupExists $SecurityConstants.SearchSecurityGroup -Verbose:$VerbosePreference))
        {
            LogVerbose "Creating local security group: $($SecurityConstants.SearchSecurityGroup)"
            CreateSecurityGroup $SecurityConstants.SearchSecurityGroup $SecurityConstants.SearchSecurityGroupDescription -Verbose:$VerbosePreference
        }

        $domainAndUserNamesArray = GetDomainAndUserFromAccount $ServiceAccount        
        $domain = $domainAndUserNamesArray[0]
        $userName = $domainAndUserNamesArray[1]

        $members = GetLocalGroupMembers $SecurityConstants.SearchSecurityGroup -Verbose:$VerbosePreference
        if ($members -notcontains $userName)
        {
            LogVerbose "Adding account: $($userName) to security group: $($SecurityConstants.SearchSecurityGroup)"
            AddUserToSecurityGroup $SecurityConstants.SearchSecurityGroup $domain $userName -Verbose:$VerbosePreference
        }
        return $true
    }
    catch
    {
        LogError "Exception occured in AddServiceAccountToSecurityGroup for account $($ServiceAccount) and group $($SecurityConstants.SearchSecurityGroup)"
        LogError $_.Exception.Message
        return $false
    }    
}

function SetPermissions
{
    [CmdletBinding()]
    param
    (
        [string] $ElasticsearchInstallPath,
        [string] $ElasticsearchIndexPath,
        [string] $javaPath,
        [string] $ServiceName,
        [string] $ServiceAccount
    )

    $dummySecPassword = ConvertTo-SecureString 'dummy' -AsPlainText -Force
    $ElasticsearchServiceCredential = New-Object System.Management.Automation.PSCredential($ServiceAccount, $dummySecPassword)

    $username = $ElasticsearchServiceCredential.UserName
    LogVerbose "Setting Elasticsearch service account to $username"
    $svc = gwmi win32_service -filter "name='$ServiceName'"

    if (-not $svc)
    {
        LogError "Unable to find Windows service: $ServiceName"
        return $false
    }

    $ret = ($svc.Change($null,                                                      # DisplayName
        $null,                                                                      # PathName
        $null,                                                                      # ServiceType
        $null,                                                                      # ErrorControl
        "Automatic",                                                                # StartMode
        $null,                                                                      # DesktopInteract
        $ElasticsearchServiceCredential.UserName,                                   # StartName
        $ElasticsearchServiceCredential.GetNetworkCredential().Password,            # StartPassword
        $null,                                                                      # LoadOrderGroup
        $null,                                                                      # LoadOrderGroupDependencies
        $null)).ReturnValue                                                         # ServiceDependencies

    switch($ret)
    {
        0 { LogVerbose "Successfully applied the credentials for '$ServiceName'"}
        15 { LogError " Error applying the credentials for '$ServiceName' : Service Logon Failed"}
        22 { LogError " Error applying the credentials for '$ServiceName' : Invalid Service Account"}
        default { LogError "Unknown error occurred while applying the credentials for '$ServiceName' : Error code: $ret"}
    }

    if ($ret -eq 0)
    {
        GrantPermissions $ElasticsearchInstallPath "f" $SecurityConstants.SearchSecurityGroup -Verbose:$VerbosePreference
        GrantPermissions $ElasticsearchIndexPath "f" $SecurityConstants.SearchSecurityGroup -Verbose:$VerbosePreference
        GrantPermissions $javaPath "rx" $SecurityConstants.SearchSecurityGroup -Verbose:$VerbosePreference
    }    

    return $ret -eq 0
}

function InstallTFSElasticsearch
{
    [CmdletBinding()]
    param (
        [string] $ElasticsearchInstallPath,
        [string] $ElasticsearchZipPath,
        [string] $AlmsearchPluginZipPath,
        [string] $ElasticsearchRelevancePath,
        [string] $ElasticsearchLoggingPath,
        [string] $ElasticsearchIndexPath,
        [int] $Port,
        [string] $ServiceName,
        [switch] $IgnoreEnvironmentVariable,
        [string] $ClusterName,
        [string] $User,
        [string] $Password
    )

    try
    {
               
        if (IsServiceInstalled $ServiceName)
        {
            LogError "Service: '$ServiceName' is already installed."
            exit
        }

        $serviceBatPath = Join-Path $ElasticsearchInstallPath $ElasticsearchConfigConstants.ElasticsearchServiceBatPath
        $pluginBatPath = Join-Path $ElasticsearchInstallPath $ElasticsearchConfigConstants.ElasticsearchPluginBatPath
        
        $elasticsearchUrl = "http://$($env:computername):$Port"
        $serviceAccount = GetNetworkServiceAccount

        [scriptblock[]]$stages = @()
        $stages += { AddServiceAccountToSecurityGroup $serviceAccount -Verbose:$VerbosePreference }
        $stages += { IsSupportedJavaInstalled -Verbose:$VerbosePreference }
        $stages += { StageElasticsearch $ElasticsearchInstallPath $ElasticsearchZipPath $AlmsearchPluginZipPath $ElasticsearchRelevancePath $ElasticsearchLoggingPath $ElasticsearchIndexPath $Port -IgnoreEnvironmentVariable:$IgnoreEnvironmentVariable $ClusterName $User $Password -Verbose:$VerbosePreference }
        $stages += { InstallElasticsearch $serviceBatPath $ServiceName $serviceAccount -Verbose:$VerbosePreference }
        $stages += { SetPermissions $ElasticsearchInstallPath $ElasticsearchIndexPath $env:JAVA_HOME $ServiceName $serviceAccount }
        $stages += { InstallElasticsearchPlugin $pluginBatPath $ElasticsearchConfigConstants.AlmsearchPlugin $ArtifactPaths.AlmsearchPluginZipPath -Verbose:$VerbosePreference }
        # if basic auth credentials are not provided, we do not install Authentication plugin (in devfabric)
        if(-not([string]::IsNullOrEmpty($User)))
        {
            $stages += { InstallElasticsearchPlugin $pluginBatPath $ElasticsearchConfigConstants.AlmsearchAuthPlugin $ArtifactPaths.AlmsearchAuthPluginZipPath -Verbose:$VerbosePreference }
        }
        $stages += { StartElasticsearch $serviceBatPath $ServiceName -Verbose:$VerbosePreference }
        $stages += { Update-ElasticsearchVersionInRegistry -Verbose:$VerbosePreference }

        $done = RunScriptBlocks $stages -Verbose:$VerbosePreference
        
        if ($done -eq $true)
        {
            LogMessage $InstallCompleteMessage
            LogMessage $SecurityConfigurationMessage
            LogMessage 'Your Search service URL is:'
            LogMessage $elasticsearchUrl
            LogMessage $ElasticsearchURLMessage
            LogFirewallStatus
        }
    }
    catch
    {
        LogError $_.Exception.Message
        exit
    }
}

function RemoveTFSElasticsearch
{
    [CmdletBinding()]
    param(
        [switch] $RemovePreviousESData,
        [string] $ServiceName,
        [switch] $IgnoreEnvironmentVariable
    )

    if (IsServiceInstalled($ServiceName))
    {
        if (-not (IsSupportedJavaInstalled))
        {
            exit
        }

        $elasticsearchExePath = GetServicePath $ServiceName -Verbose:$VerbosePreference
        LogVerbose "Found Elasticsearch at: $elasticsearchExePath"
        
        $serviceBatPath = Join-Path (GetBasePath $elasticsearchExePath 1 -Verbose:$VerbosePreference) elasticsearch-service.bat
        if (-Not(Test-Path $serviceBatPath))
        {
            $serviceBatPath = Join-Path (GetBasePath $elasticsearchExePath 1 -Verbose:$VerbosePreference) service.bat        
        }
        LogVerbose "elasticsearh service bat file path: $serviceBatPath"
    
        StopElasticsearch $serviceBatPath $ServiceName -Verbose:$VerbosePreference

        UninstallElasticsearch $serviceBatPath $ServiceName -Verbose:$VerbosePreference

        if (IsServiceInstalled($ServiceName))
        {
            LogError "Uninstallation of elasticsearch service failed"
            exit
        }

        $elasticSearchFolderPath = GetBasePath $elasticsearchExePath 2
        LogVerbose "Removing folder at: $elasticSearchFolderPath"
        
        if($IgnoreEnvironmentVariable)
        {
            LogVerbose "IgnoreEnvironmentVariable: $IgnoreEnvironmentVariable"
            $elasticsearchConfigFilePath = Join-Path $elasticSearchFolderPath 'config\elasticsearch.yml' 
            $ElasticsearchIndexPath = ParseElasticsearchIndexPath $elasticsearchConfigFilePath -Verbose:$VerbosePreference    
        }
        else
        {
            $ElasticsearchIndexPath = [Environment]::GetEnvironmentVariable($ElasticsearchConfigConstants.SearchIndexPathEnvVar, "Machine")
        }

        $removeElasticsearchScriptBlock = { Remove-Item -Recurse $elasticSearchFolderPath -ErrorAction Stop }
        RetryInvoke $removeElasticsearchScriptBlock 5 10 -Verbose:$VerbosePreference        

        if ($RemovePreviousESData)
        {
            LogVerbose "Removing folder at: $ElasticsearchIndexPath"
            $removeElasticsearchScriptBlock = { Remove-Item -Force -Recurse $ElasticsearchIndexPath -ErrorAction Stop }
            RetryInvoke $removeElasticsearchScriptBlock -RetryCount 5 -RetryDelay 10              
        }
        else
        {
            LogVerbose "Preserving current data at: $ElasticsearchIndexPath"
        }
    }
    else
    {
        LogVerbose "Service: '$ServiceName' was not found on the system."
    }
}

function UpdateTFSElasticsearch
{
    [CmdletBinding()]
    param(
        [string] $ElasticsearchZipPath,
        [string] $AlmsearchPluginZipPath,
        [string] $ElasticsearchRelevancePath,
        [string] $ElasticsearchLoggingPath,
        [string] $ServiceName,
        [switch] $IgnoreEnvironmentVariable,
        [string] $User,
        [string] $Password
    )
  
    if (-not (IsServiceInstalled($ServiceName)))
    {
        LogError 'Elasticsearch not found.'
        return;
    }    
    
    $elasticsearchExePath = GetServicePath $ServiceName -Verbose:$VerbosePreference
    LogVerbose "Found Elasticsearch at: $elasticsearchExePath"

    $elasticSearchFolderPath = GetBasePath $elasticsearchExePath 2
    $elasticsearchConfigFilePath = Join-Path $elasticSearchFolderPath 'config\elasticsearch.yml' 

    if($IgnoreEnvironmentVariable)
    {
            $ElasticsearchIndexPath = ParseElasticsearchIndexPath $elasticsearchConfigFilePath -Verbose:$VerbosePreference    
    }
    else
    {
            $ElasticsearchIndexPath = [Environment]::GetEnvironmentVariable($ElasticsearchConfigConstants.SearchIndexPathEnvVar, "Machine")
    }

    if ([string]::IsNullOrWhiteSpace($ElasticsearchIndexPath))
    {
        LogError "System environment variable: $($ElasticsearchConfigConstants.SearchIndexPathEnvVar) not found."
        return
    }

    # Get old credentials from config.yml
    $oldUser = ParseElasticsearchConfigValue $elasticsearchConfigFilePath "almsearchauth.http.user" -Verbose:$VerbosePreference
    $oldPassword = ParseElasticsearchConfigValue $elasticsearchConfigFilePath "almsearchauth.http.password"  -Verbose:$VerbosePreference

    # if no user / password is provided and no user / password exist in the config.yml throw error
    if([string]::IsNullOrEmpty($User) -and [string]::IsNullOrEmpty($oldUser))
    {
        LogError $UserMessage
        exit
    }
    elseif([string]::IsNullOrEmpty($User))
    {
        $User = $oldUser
    }
    if([string]::IsNullOrEmpty($Password) -and [string]::IsNullOrEmpty($oldPassword))
    {
        LogError $PasswordMessage
        exit
    }
    elseif([string]::IsNullOrEmpty($Password))
    {
        $Password = $oldPassword
    }

    $clusterName = ParseElasticsearchClusterName $elasticsearchConfigFilePath -Verbose:$VerbosePreference

    $Port = ParseElasticsearchPort $elasticsearchConfigFilePath -Verbose:$VerbosePreference    
    $elasticsearchInstallPath = GetBasePath $elasticsearchExePath 3
    $elasticsearchUrl = "http://$($env:computername):$Port"

    if (IsServiceRunning($ServiceName))
    {
        $installedVersion = [System.Version](GetElasticsearchVersion -elasticsearchUrl $elasticsearchUrl -user $oldUser -password $oldPassword)
        $currentVersion = [System.Version] $ElasticsearchConfigConstants.ElasticsearchVersion

        if ($installedVersion -eq $currentVersion)
        {
            UpdateTFSElasticsearchWithoutReinstall `
                -ElasticsearchZipPath $ElasticsearchZipPath `
                -ElasticsearchRelevancePath $ElasticsearchRelevancePath `
                -ElasticsearchInstallPath $elasticsearchInstallPath `
                -ElasticsearchIndexPath $ElasticsearchIndexPath `
                -ElasticsearchUrl $elasticsearchUrl `
                -ClusterName $clusterName `
                -ServiceName $ServiceName `
                -Port $Port `
                -User $User `
                -Password $Password `
                -OldUser $oldUser `
                -OldPassword $oldPassword
            return;
        }
    }

    $isReindexingRequired = IsReindexingRequired $elasticsearchUrl $ServiceName $oldUser $oldPassword -Verbose:$VerbosePreference
    
    RemoveTFSElasticsearch -RemovePreviousESData:$false $ServiceName -IgnoreEnvironmentVariable:$IgnoreEnvironmentVariable -Verbose:$VerbosePreference

    if (IsServiceInstalled($ServiceName))
    {
        LogError "Uninstallation of old elasticsearch failed"
        exit
    }

    # If Re-indexing is needed due to incompatible ES version, we remove the old index data
    if ($isReindexingRequired)
    {
        LogMessage "Reindexing is required during this upgrade. Renaming old elasticsearch data folder ..."
        RenameSearchIndexDataFolder -ElasticsearchIndexPath $ElasticsearchIndexPath
    }
    
    InstallTFSElasticsearch -ElasticsearchInstallPath $elasticsearchInstallPath `
    -ElasticsearchZipPath $ElasticsearchZipPath `
    -AlmsearchPluginZipPath $AlmsearchPluginZipPath `
    -ElasticsearchRelevancePath $ElasticsearchRelevancePath `
    -ElasticsearchLoggingPath $ElasticsearchLoggingPath `
    -ElasticsearchIndexPath $ElasticsearchIndexPath `
    -Port $Port `
    -ServiceName $ServiceName `
    -IgnoreEnvironmentVariable:$IgnoreEnvironmentVariable `
    -ClusterName $clusterName `
    -User $User `
    -Password $Password `
    -Verbose:$VerbosePreference 

}

function UpdateTFSElasticsearchWithoutReinstall
{
    [CmdletBinding()]
    param(
        [string] $ElasticsearchZipPath,
        [string] $ElasticsearchRelevancePath,
        [string] $ElasticsearchInstallPath,
        [string] $ElasticsearchIndexPath,
        [string] $ElasticsearchUrl,
        [string] $ServiceName,
        [string] $ClusterName,
        [string] $Port,
        [string] $User,
        [string] $Password,
        [string] $OldUser,
        [string] $OldPassword
    )
    $serviceBatPath = Join-Path $ElasticsearchInstallPath $ElasticsearchConfigConstants.ElasticsearchServiceBatPath
    $pluginBatPath = Join-Path $ElasticsearchInstallPath $ElasticsearchConfigConstants.ElasticsearchPluginBatPath
    $pluginInstallPath = Join-Path $ElasticsearchInstallPath $ElasticsearchConfigConstants.AlmsearchPluginPath

    $installedPluginVersion = [System.Version](GetElasticsearchPluginVersion -elasticsearchUrl $ElasticsearchUrl -pluginName $ElasticsearchConfigConstants.AlmsearchPlugin -user $OldUser -password $OldPassword)
    $currentPluginVersion = [System.Version] $ElasticsearchConfigConstants.AlmsearchPluginVersion

    $installedAuthPluginVersion = [System.Version](GetElasticsearchPluginVersion -elasticsearchUrl $ElasticsearchUrl -pluginName $ElasticsearchConfigConstants.AlmsearchAuthPlugin -user $OldUser -password $OldPassword)
    $currentAuthPluginVersion = [System.Version] $ElasticsearchConfigConstants.AlmsearchAuthPluginVersion    

    StopElasticsearch $serviceBatPath $ServiceName -Verbose:$VerbosePreference

    [scriptblock[]]$stages = @()
    $stages += { UpdateElasticsearchConfig $ElasticsearchInstallPath $ElasticsearchRelevancePath $ElasticsearchIndexPath $Port $ClusterName $User $Password -Verbose:$VerbosePreference }
    if($installedPluginVersion -ne $currentPluginVersion)
    {
        $stages += { RemoveElasticsearchPlugin $pluginBatPath $ElasticsearchConfigConstants.AlmsearchPlugin $pluginInstallPath -Verbose:$VerbosePreference }
        $stages += { InstallElasticsearchPlugin $pluginBatPath $ElasticsearchConfigConstants.AlmsearchPlugin $ArtifactPaths.AlmsearchPluginZipPath -Verbose:$VerbosePreference } 
    }
    
    if($installedAuthPluginVersion -ne $currentAuthPluginVersion)
    {
        $stages += { RemoveElasticsearchPlugin $pluginBatPath $ElasticsearchConfigConstants.AlmsearchAuthPlugin $pluginInstallPath -Verbose:$VerbosePreference }
        $stages += { InstallElasticsearchPlugin $pluginBatPath $ElasticsearchConfigConstants.AlmsearchAuthPlugin $ArtifactPaths.AlmsearchAuthPluginZipPath -Verbose:$VerbosePreference }
    }    
    $stages += { StartElasticsearch $serviceBatPath $ServiceName -Verbose:$VerbosePreference }
    $done = RunScriptBlocks $stages -Verbose:$VerbosePreference
        
    if ($done -eq $true)
    {
        LogMessage $InstallCompleteMessage
        LogMessage $SecurityConfigurationMessage
        LogMessage 'Your Search service URL is:'
        LogMessage $ElasticsearchUrl
        LogMessage $ElasticsearchURLMessage
        LogFirewallStatus
    }

}

function RenameSearchIndexDataFolder
{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$False)]
        $ElasticsearchIndexPath
    )
    if (Test-Path $ElasticsearchIndexPath)
    {
        $removeElasticsearchIndexScriptBlock = {
            $indexPath = $ElasticsearchIndexPath.Trim('\','/')
            $backupIndexPath = "{0}.{1}.old" -f $ElasticsearchIndexPath, $(get-date -f yyyyMMddHHmmss)
            Rename-Item -Path $ElasticsearchIndexPath -NewName $backupIndexPath -Force -ErrorAction Stop 
            
            LogVerbose "Renamed old index data folder $ElasticsearchIndexPath to $backupIndexPath"
        }
        RetryInvoke $removeElasticsearchIndexScriptBlock 5 10 -Verbose:$VerbosePreference
    }
}

function IsReindexingRequired
{
    [CmdletBinding()]
    Param
    (
        $ElasticsearchUrl,
        $ServiceName,
        [string] $User,
        [string] $Password
    )

    $installedVersion = $null
    if (IsServiceRunning($ServiceName))
    {
        $installedVersion = [System.Version](GetElasticsearchVersion $ElasticsearchUrl $User $Password)
        LogMessage "Elasticsearch version : $installedVersion"
    }
    
    if ($installedVersion -eq $null)
    {
        $installedVersion= [System.Version] (Get-ElasticsearchVersionFromRegistry)
        LogMessage "Elasticsearch version from registry: $installedVersion"
    }

    $minSupportedVersion = [System.Version] $ElasticsearchConfigConstants.MinESSupportedVersion

    if ($installedVersion -ge $minSupportedVersion)
    {
        return $false;
    }
    else
    {
        LogVerbose "Elasticsearch Index data is not compatible with the new elasticsearch version. Reindexing is required"
        return $true;
    }
}

function ValidateUserOrPasswordLength
{    
    [OutputType([boolean])]
    Param
    (
        [string] $InputText
    )
    if($InputText -eq $null -or $InputText.Length -lt 8 -or $InputText.Length -gt 64)
    {
        return $false
    }
    return $true
}

function ValidateUser
{    
    [OutputType([boolean])]
    Param
    (
        [string] $user
    )
    if($user -imatch "^[a-zA-Z0-9_]+$")
    {
        return $true
    }
    return $false
}

Export-ModuleMember -Function InstallTFSElasticsearch, RemoveTFSElasticsearch, UpdateTFSElasticsearch, ValidateUserOrPasswordLength, ValidateUser

# SIG # Begin signature block
# MIIkSwYJKoZIhvcNAQcCoIIkPDCCJDgCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAESh2pt9X8LLRj
# HckFtQu+57tJeC6uTe4dSmIkxSC3TaCCDYEwggX/MIID56ADAgECAhMzAAABA14l
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgsghvFvbN
# 4dJQGqOSfkQ11Wnqwodx0p+IESTehTPQLP8wQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBKNiDzZZFVO/nJ0SO4DisnYoOSQOpoR3kLbuZVBVvs
# vB9joYbtYnBjx2Q4KENxqF+BPHx3JH2/VNihj5mG3S08mU8SiftQIrKeOjDQ6EUo
# xq7a415hXnuEpkO1Ui92DjaOe3ug8uQchu7xJ70bE9pNxXcOOyhwti8HRtm+VMx6
# PqieLEyrlofVsKVzu9tbkP2of7JbHmcumEDJNBfTLd+VjgkN3cFMQo8wWe2YvP4t
# 6MWUYxWa8Sx8792cJqy7Qt6NOb7ZeoKLj0Mo0nGpgz94nirZFsozNPbr3Kw4cw9B
# sRXWAMG1Il9/0nCFvXx1l+4fLoGYBzHCQ98M2q4ohqf3oYITqjCCE6YGCisGAQQB
# gjcDAwExghOWMIITkgYJKoZIhvcNAQcCoIITgzCCE38CAQMxDzANBglghkgBZQME
# AgEFADCCAVQGCyqGSIb3DQEJEAEEoIIBQwSCAT8wggE7AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIGRmqbQd7/R4QA095q+xcWc+npVD73/RKbu1Jt7H
# jrwiAgZbzfy99NsYEzIwMTgxMDI0MjMzNDE3Ljk5N1owBwIBAYACAfSggdCkgc0w
# gcoxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsT
# HE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBU
# U1MgRVNOOjEyRTctMzA2NC02MTEyMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
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
# AQICEzMAAADq4c7/mrOmktEAAAAAAOowDQYJKoZIhvcNAQELBQAwfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMTgwODIzMjAyNzE3WhcNMTkxMTIzMjAy
# NzE3WjCByjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMG
# A1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046MTJFNy0zMDY0LTYxMTIxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDBf34+HliyJ6ZawA0LSkd2y6AD+hKWv8++nrPz65ylJuchUwkGSG+VTtdnee5y
# gGffOsyeer84cyVC9WmBoSOgT5M/4Yxfm0kA6wue82uO0BHHTBT8F7evnKrC8sD7
# EqB2eMUdmYhJ2RlngViqpttWFKdhjBw5rwhuHeEdQYO53eZi20a62GZnHHFXhHmB
# RQsi1XkbfrZjeY9EOPR38Qp1wAQDpeW7HlYaJRXYpixGI7bB4cwfj8b5Pum0PDEB
# FluA60vCUKVSd3h6gM5vwQ8SiSNTX0tE6FUQ2nHurJO2Uou38zrb3LS/fcHqm9LM
# WafYW/+d0w8n4y16s14HKKXtAgMBAAGjggEbMIIBFzAdBgNVHQ4EFgQU0sewF64Z
# vu1wgvtU6aRtt8fFpa4wHwYDVR0jBBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUw
# VgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9j
# cmwvcHJvZHVjdHMvTWljVGltU3RhUENBXzIwMTAtMDctMDEuY3JsMFoGCCsGAQUF
# BwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aS9jZXJ0cy9NaWNUaW1TdGFQQ0FfMjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIw
# ADATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0BAQsFAAOCAQEAp7vNG5qg
# BOhaRW3GkH9UhjujBHsceVgH/x8tLljQeNiNjwGROWsvzH9GZmYX/HE/HWr3WBmE
# bzqjOW4dk4oQNvVVyBeOjW8f+R1Mo74JP34fkXLmYBQHXXBMWy1xTgclhctFyNfr
# KSIT/+N/ZtGERMeIPrYcpBmYh7BO4pkoEZIVnqE0pj3tgCh/yKkedBQ7/FBP04G1
# 1oFMQnNIe/MssXGVxF44AiCukCwkWPUTciJxhKVKwL7497jfdV9ZSRCNwdgf1bfT
# 9n8uUWxrAya2eX7nCtlzkqTKUmfPfQ1j/eXcReFXx1cbIgwbiv5ISMRLaqi8VrB6
# eeEg0FsqLv7iyKGCA6gwggKQAgEBMIH6oYHQpIHNMIHKMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjoxMkU3LTMwNjQt
# NjExMjElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIlCgEB
# MAkGBSsOAwIaBQADFQA8ZhJFUNlWp1EOnc74tuoxDHgAVqCB2jCB16SB1DCB0TEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMebkNpcGhlciBOVFMg
# RVNOOjI2NjUtNEMzRi1DNURFMSswKQYDVQQDEyJNaWNyb3NvZnQgVGltZSBTb3Vy
# Y2UgTWFzdGVyIENsb2NrMA0GCSqGSIb3DQEBBQUAAgUA33tjzzAiGA8yMDE4MTAy
# NDIxMzQwN1oYDzIwMTgxMDI1MjEzNDA3WjB3MD0GCisGAQQBhFkKBAExLzAtMAoC
# BQDfe2PPAgEAMAoCAQACAg7uAgH/MAcCAQACAhhsMAoCBQDffLVPAgEAMDYGCisG
# AQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwGgCjAIAgEAAgMW42ChCjAIAgEAAgMH
# oSAwDQYJKoZIhvcNAQEFBQADggEBAAqepvfr/iCg3NFsWg8BLSaxYC+8+LrlNtLX
# G5ug2ksAWN2tt2sFyMYrLXPb1eUb8lMj8fQCeCQbYfSnI6/j3jNEz3VDQgyVxK71
# q9hSb5II7CiwpcBVJ8UtLTW8u7DSu2OJYUWUBXYezNDJvflHfQI17EsRUfhgd7PL
# acu0n/Y/cLoaozFJEgD5HhtCWZUp+xK3XvxsGvqTsYuq4vgFtZoQgTSZc1ycUE+N
# JXBfV72ALK/z8p19rCiZ6dQCyPUrZfk/YWIneeOqT3K4pXMOJfS91TKDI7aW0qoK
# fjG7ENYlK1l1I0GBNxczWmmc8VLUMpYqNK5C3cjfALESR0HJtRYxggL1MIIC8QIB
# ATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAOrhzv+as6aS
# 0QAAAAAA6jANBglghkgBZQMEAgEFAKCCATIwGgYJKoZIhvcNAQkDMQ0GCyqGSIb3
# DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCBdR7XKBx502F2K4ipK+LPDvhT55DqAh8S/
# A19fJOEOLjCB4gYLKoZIhvcNAQkQAgwxgdIwgc8wgcwwgbEEFDxmEkVQ2VanUQ6d
# zvi26jEMeABWMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAC
# EzMAAADq4c7/mrOmktEAAAAAAOowFgQUAZQ4gZ5t/Xr5ZukTk/myvBGtqQAwDQYJ
# KoZIhvcNAQELBQAEggEACb05XE0mTgmCEI2sLSH7m89lPRMMUoYDdYDJJaBskvEH
# nOpq231/FNHQINbOyrNwOtSpA1j2aZFXPBkt3NIhXtPd+2MpqGlikO7eLfr+xiTd
# lCfgM53hCrHkyTelda7F3NyiNAtaKE62YFe+xOM/oqvc3IzYTd/0umsFJ6FMX7be
# hzP7VPWV9PdY6z9KVEhk1vOnnaDsGlFfB5WAqiQ6Qe648P8pJXI1jdOPrVDj2hgU
# a/SlbS9+XrVdFLTD6M5f6kRWX8E09oHZV877tjFeaJf6LWSnGVJjnphJg2H7aHni
# eooJwM/d9BX6jeuMloc1/5wsjPBSGKCRD1Tt8Dn+Pg==
# SIG # End signature block
