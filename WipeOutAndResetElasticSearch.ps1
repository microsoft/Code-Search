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
    if ($confirm.ToUpper().StartsWith(“Y”))
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

if(IsResetConfirm($message))
{
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
                Write-Host "Could not find ElasticSearch service or data. Exiting cleanup" -ForegroundColor Yellow
            }
    }
    else
    {
        [System.ENVIRONMENT]::CurrentDirectory = $pwd
        Write-Host "Found ElasticSearch at $servicePath" -ForegroundColor Green
        Push-Location

        cd $servicePath
        $outputService = .\Service.bat stop
        Write-Host $outputService -ForegroundColor Yellow
        if($outputService -like '*failed*')
        {
            Write-Host "Failed to stop service. Exiting cleanup" -ForegroundColor Yellow
        }
        else
        {
            $ESIndexLocation = $env:SEARCH_ES_INDEX_PATH
            Remove-Item -Recurse -Force -Path $ESIndexLocation

            Write-Host "Cleaned up the index folder $ESIndexLocation" -ForegroundColor Green

            $outputService = .\Service.bat start
            Write-Host $outputService -ForegroundColor Yellow
        }

        Pop-Location
    }
}
else
{
    Write-Warning "Exiting! ElasticSearch was not reset."
}
