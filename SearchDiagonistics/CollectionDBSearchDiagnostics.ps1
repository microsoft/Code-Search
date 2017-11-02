[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True, Position=0, HelpMessage="The SQL Server Instance against which the script is to run.")]
    [string]$SQLServerInstance,
      
    [Parameter(Mandatory=$True, Position=1, HelpMessage="Collection Database name.")]
    [string]$CollectionDatabaseName,
    
    [Parameter(Mandatory=$True, Position=2, HelpMessage="Configuration Database name")]
    [string]$ConfigurationDatabaseName,
   
    [Parameter(Mandatory=$True, Position=3, HelpMessage="Collection Name")]
    [string]$CollectionName
)

function CollectionDBSearchStatus
{
	Write-Host "CollectionId = $CollectionID" -ForegroundColor Green
	
	$collectionLogDir = Join-Path $PWD -ChildPath "CollectionDBDiagnosticScripts\$CollectionName"
	
	New-Item -ItemType Directory -Force -Path $collectionLogDir
	
	## Query IndexingUnit Data
	
	$IndexingUnitLogPath = Join-Path $collectionLogDir -ChildPath 'IndexingUnit.csv'
	Write-Host "Fetching IndexingUnit data into $IndexingUnitLogPath ..." -ForegroundColor Green
	Set-Content -Path $IndexingUnitLogPath ([Environment]::NewLine)

	$SqlFullPath = Join-Path $PWD -ChildPath 'CollectionDBDiagnosticScripts\IndexingUnitData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName
	
	foreach($row in $queryResults)
	{
		$indexingUnitEntry =  "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),$row.Item(3),$row.Item(4),$row.Item(5),$row.Item(6),$row.Item(7),$row.Item(8),$row.Item(9),([Environment]::NewLine)
		Add-Content -Path $IndexingUnitLogPath $indexingUnitEntry
	}
	
	## Query IndexingUnitChangeEvent Data
	
	$IndexingUnitChangeEventLogPath = Join-Path $collectionLogDir -ChildPath 'IndexingUnitChangeEvent.csv'
	Write-Host "Fetching IndexingUnitChangeEvent data into $IndexingUnitChangeEventLogPath ..." -ForegroundColor Green
	Set-Content -Path $IndexingUnitChangeEventLogPath ([Environment]::NewLine)

	$SqlFullPath = Join-Path $PWD -ChildPath 'CollectionDBDiagnosticScripts\IndexingUnitChangeEventData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName
	
	foreach($row in $queryResults)
	{
		$indexingUnitChangeEventEntry =  "{0},{1},{2},{3},{4},{5},{6},{7},{8},{9}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),$row.Item(3),$row.Item(4),$row.Item(5),$row.Item(6),$row.Item(7),$row.Item(8),$row.Item(9),([Environment]::NewLine)
		Add-Content -Path $IndexingUnitChangeEventLogPath $indexingUnitChangeEventEntry
	}
	
	## Query ItemLevelFailures Data
	
	$ItemLevelFailuresLogPath = Join-Path $collectionLogDir -ChildPath 'ItemLevelFailures.csv'
	Write-Host "Fetching ItemLevelFailures data into $ItemLevelFailuresLogPath ..." -ForegroundColor Green
	Set-Content -Path $ItemLevelFailuresLogPath ([Environment]::NewLine)

	$SqlFullPath = Join-Path $PWD -ChildPath 'CollectionDBDiagnosticScripts\ItemLevelFailuresData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName
	
	foreach($row in $queryResults)
	{
		$itemLevelFailureEntry =  "{0},{1},{2},{3},{4},{5},{6}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),$row.Item(3),$row.Item(4),$row.Item(5),$row.Item(6),([Environment]::NewLine)
		Add-Content -Path $ItemLevelFailuresLogPath $itemLevelFailureEntry
	}
	
	## Query JobYield Data
	
	$JobYieldLogPath = Join-Path $collectionLogDir -ChildPath 'JobYield.csv'
	Write-Host "Fetching JobYield data into $JobYieldLogPath ..." -ForegroundColor Green
	Set-Content -Path $JobYieldLogPath ([Environment]::NewLine)

	$SqlFullPath = Join-Path $PWD -ChildPath 'CollectionDBDiagnosticScripts\JobYieldData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName
	
	foreach($row in $queryResults)
	{
		$jobYieldEntry =  "{0},{1},{2}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),([Environment]::NewLine)
		Add-Content -Path $JobYieldLogPath $jobYieldEntry
	}
	
	## Query ResourceLock Data
	
	$ResourceLockLogPath = Join-Path $collectionLogDir -ChildPath 'ResourceLock.csv'
	Write-Host "Fetching ResourceLock data into $ResourceLockLogPath ..." -ForegroundColor Green
	Set-Content -Path $ResourceLockLogPath ([Environment]::NewLine)

	$SqlFullPath = Join-Path $PWD -ChildPath 'CollectionDBDiagnosticScripts\ResourceLockData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName
	
	foreach($row in $queryResults)
	{
		$resourceLockEntry =  "{0},{1},{2},{3}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),$row.Item(3),([Environment]::NewLine)
		Add-Content -Path $ResourceLockLogPath $resourceLockEntry
	}
	
	## Query DisabledFiles Data
	
	$DisabledFilesLogPath = Join-Path $collectionLogDir -ChildPath 'DisabledFiles.csv'
	Write-Host "Fetching DisabledFiles data into $DisabledFilesLogPath ..." -ForegroundColor Green
	Set-Content -Path $DisabledFilesLogPath ([Environment]::NewLine)

	$SqlFullPath = Join-Path $PWD -ChildPath 'CollectionDBDiagnosticScripts\DisabledFilesData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName
	
	foreach($row in $queryResults)
	{
		$disabledFileEntry =  "{0},{1},{2},{3},{4},{5}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),$row.Item(3),$row.Item(4),$row.Item(5),([Environment]::NewLine)
		Add-Content -Path $DisabledFilesLogPath $disabledFileEntry
	}
	
	## Query ClassificationNode Data
	
	$ClassificationNodeLogPath = Join-Path $collectionLogDir -ChildPath 'ClassificationNode.csv'
	Write-Host "Fetching ClassificationNode data into $ClassificationNodeLogPath ..." -ForegroundColor Green
	Set-Content -Path $ClassificationNodeLogPath ([Environment]::NewLine)

	$SqlFullPath = Join-Path $PWD -ChildPath 'CollectionDBDiagnosticScripts\ClassificationNodeData.sql'
	$queryResults = Invoke-Sqlcmd -InputFile $SqlFullPath -serverInstance $SQLServerInstance -database $CollectionDatabaseName
	
	foreach($row in $queryResults)
	{
		$classificationNodeEntry =  "{0},{1},{2},{3},{4},{5},{6},{7},{8}" -f `
               $row.Item(0),$row.Item(1),$row.Item(2),$row.Item(3),$row.Item(4),$row.Item(5),$row.Item(6),$row.Item(7),$row.Item(8),([Environment]::NewLine)
		Add-Content -Path $ClassificationNodeLogPath $classificationNodeEntry
	}
	
	$collectionDBDiagnosticZip = [string]::Format("{0}_Diagnostic.zip", $CollectionDatabaseName)
	Write-Host "Compressing data to $collectionDBDiagnosticZip ..." -ForegroundColor Green
	Compress-Archive -Force -Path $collectionLogDir -DestinationPath $collectionDBDiagnosticZip
	
	Remove-Item $collectionLogDir -Recurse -ErrorAction Ignore
}

Import-Module .\Common.psm1 -Force
Write-Host "Extracting Search diagnostics data from '$CollectionDatabaseName' database" -ForegroundColor Green

[System.ENVIRONMENT]::CurrentDirectory = $PWD
Push-Location
ImportSQLModule

$CollectionID = ValidateCollectionName $SQLServerInstance $ConfigurationDatabaseName $CollectionName

CollectionDBSearchStatus

Pop-Location