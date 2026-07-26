<#
Script to add search support for Chinese characters.
For creating new index mappings customer has to clean search and reconfigure it.
We are enabling feature flags and then cleaning up the existing search. 
If customer hasn't installed search yet, then we would just enable the FF and exit from there. Customer can configure search
after that.
#>

[CmdletBinding()]
Param
(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,
   
    [Parameter(Mandatory=$True, Position=1, HelpMessage="Collection Database name.")]
    [string]$CollectionDatabaseName,
    
    [Parameter(Mandatory=$True, Position=2, HelpMessage="Configuration Database name.")]
    [string]$ConfigurationDatabaseName,
   
    [Parameter(Mandatory=$True, Position=3, HelpMessage="Collection name.")]
    [string]$CollectionName
)

Import-Module "$PSScriptRoot\Common.psm1" -Force

function IsCurrentUserAdmin
{
    [CmdletBinding()]
    param()

    If (([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
    {
	    return $true
    }
    return $false
}

function IsResetConfirm
{
    [OutputType([boolean])]
    Param
    (
    [string]$message
    )
    Write-Host $message  -NoNewline -ForegroundColor Magenta
    $confirm = Read-Host 
    if ($confirm.ToUpper().StartsWith("Y"))
    {
    return $true
    }
    return $false
}

function GetElasticsearchInstallPath
{
    param
    (
    [string] $serviceName
    )

    $output = Get-WmiObject win32_service | ?{$_.Name -like $serviceName} | select PathName

    if($output)
    {
        $pathTokens = $output.PathName -split '"'
        $servicePath = if ($pathTokens.Length -gt 1) { $pathTokens[1] } else { ($output.PathName -split ' ')[0] }
        $servicePath = Split-Path -Path $servicePath
    }

    return $servicePath
}

if(-not (IsCurrentUserAdmin))
{
    Write-Error "Run the script with Admin privileges"
    Exit
}

$message = "This can be fatal!!. It will delete current indexed data for all the collections. Do you want to continue - Yes(Y) or No(N)? "

ImportSQLModule

$CollectionID = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $CollectionName

if(IsResetConfirm($message))
{
    try
    {
        $SqlFullPath = Join-Path $PSScriptRoot -ChildPath 'SqlScripts\EnableSearchOnOriginalContent.sql'
    Invoke-Sqlcmd -InputFile $SqlFullPath -ServerInstance $SQLServerInstance -Database $ConfigurationDatabaseName  -Verbose -Variable $Params
    Write-Host "Successfully enabled Feature flags to support Chinese characters!!" -ForegroundColor Green
    # Getting the install path of the Team Foundation Server
    $serviceName = 'elasticsearch-service-x64'
    
    $servicePath = GetElasticsearchInstallPath($serviceName)

    if(-not $servicePath)
    {
            $ESIndexLocation = $env:SEARCH_ES_INDEX_PATH
            if(-not $ESIndexLocation)
            {
                Remove-Item -Recurse -Force -Path $ESIndexLocation
                Write-Host "Cleaned up the index folder $ESIndexLocation" -ForegroundColor Green
            }
            else
            {
                Write-Host "Could not find ElasticSearch service or data, may be Search hasn't configured yet. Exiting" -ForegroundColor Yellow
            }
    }
    else
    {
        [System.ENVIRONMENT]::CurrentDirectory = $pwd
        Write-Host "Found ElasticSearch at $servicePath" -ForegroundColor Green
        Push-Location

        cd $servicePath
        $outputService = .\elasticsearch-service.bat stop 
        Write-Host $outputService -ForegroundColor Yellow
        if($outputService -like '*failed*')
        {
            Write-Host "Failed to stop service, may be Search hasn't configured yet. Exiting" -ForegroundColor Yellow
        }
        else
        {
            $ESIndexLocation = $env:SEARCH_ES_INDEX_PATH
            Remove-Item -Recurse -Force -Path $ESIndexLocation

            Write-Host "Cleaned up the index folder $ESIndexLocation" -ForegroundColor Green

            $outputService = .\elasticsearch-service.bat remove
            Write-Host $outputService -ForegroundColor Yellow
        }

        Write-Host "Please remove search service from the AzureDevops admin console and reconfigure Search" -ForegroundColor Green
        Pop-Location 
    }
    }
    catch
    {
        Write-Warning " Something went wrong. Exiting! ElasticSearch was not reset. Please clean it up manually or reach out to support team."
    }
    
}
else
{
    Write-Warning "Exiting! ElasticSearch was not reset.Please clean it up manually or reach out to support team."
}