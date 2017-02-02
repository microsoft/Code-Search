Write-Host "This can be fatal will delete all your current indexed data for all the collections. Do you want to continue - Yes or No? " -NoNewline -ForegroundColor Magenta
$userInput = Read-Host

if($userInput -like "Yes")
{
    # Getting the install path of the Team Foundation Server
    try
    {
        $tfsFolder = Get-ItemProperty -Path hklm:\Software\Microsoft\TeamFoundationServer\15.0\ -Name InstallPath
        $ESFolder = Join-Path -Path $tfsFolder.InstallPath -ChildPath Search\ES\elasticsearch-2.4.1\bin

    }
    catch [System.Management.Automation.PSArgumentException]
    {
    }
    catch [System.Management.Automation.ItemNotFoundException]
    {
    }
 
    if(!$ESFolder -or !(Test-Path -Path $ESFolder))
    {
        Write-Warning "Could not find the ElasticSearch Location"
        Write-Host "Enter the location to the ES BIN Folder, for e.g. C:\Program Files\Microsoft Team Foundation Server 15.0\Search\ES\elasticsearch-2.4.1\bin : " -ForegroundColor Yellow -NoNewline
        $ESFolder = Get-Item -Path(Read-Host)
    }
    
    [System.ENVIRONMENT]::CurrentDirectory = $ESFolder
    cd $ESFolder
    Push-Location

    $outputService = .\Service.bat stop 
    Write-Host $outputService -ForegroundColor Yellow

    $ESIndexLocation = $env:SEARCH_ES_INDEX_PATH
    Remove-Item -Path $ESIndexLocation -Recurse

    Write-Host "Cleaned up the index folder $ESIndexLocation" -ForegroundColor Green

    $outputService = .\Service.bat start
    Write-Host $outputService -ForegroundColor Yellow

    Pop-Location 
}
else
{
    Write-Warning "Exiting! ElasticSearch was not reset."
}