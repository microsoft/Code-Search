[CmdletBinding(SupportsShouldProcess=$True)]
Param
(
    [Parameter(Mandatory=$True, HelpMessage="The SQL server instance hosting the configuration and collection databases.")]
    [string] $SQLServerInstance,

    [Parameter(Mandatory=$True, HelpMessage="URL of Elasticsearch service. Example: http://es-server:9200.")]
    [uri] $ElasticsearchServiceUrl,

    [Parameter(Mandatory=$True, HelpMessage="Credential for connecting to the Elasticsearch service.")]
    [PSCredential] $ElasticsearchServiceCredential,

    [Parameter(Mandatory=$True, HelpMessage="Configuration Database name.")]
    [string] $ConfigurationDatabaseName,

    [Parameter(Mandatory=$True, HelpMessage="Collection Database name.")]
    [string] $CollectionDatabaseName,

    [Parameter(Mandatory=$True, HelpMessage="Name of the affected collection.")]
    [string] $CollectionName,

    [Parameter(Mandatory=$True, HelpMessage="Troubleshoot search for Code, WorkItem or Wiki entity type.")]
    [ValidateSet("Code", "WorkItem", "Wiki")]
    [string] $EntityType
)

$ErrorActionPreference="Stop" # We do not want to continue executing the script if we encounter a failure

$confirmationRequired = $ConfirmPreference -ne "None"

Import-Module "$PSScriptRoot\Utils\Common.psm1" -DisableNameChecking -Force -Verbose:$false

# Saving the value of log file path to a global variable so that it is not required to pass it along to every function invoked.
$logFilePath = "$PSScriptRoot\Repair-Search_$(((Get-Date).ToUniversalTime()).ToString(`"yyyy-MM-ddTHH-mm-ssZ`")).log"
Set-Variable LogFilePath -Option ReadOnly -Scope Global -Force -Value $logFilePath -Confirm:$false -WhatIf:$false

Write-Log "=== Start Repair-Search ===" -Verbose:$VerbosePreference

$analyzerRepository = @()
$actionRepository = @()

# Importing all analyzer modules
Get-ChildItem -Path "$PSScriptRoot\Analyzers\*.psm1" | Foreach-Object { Import-Module $_.FullName -Force -Verbose:$false; $analyzerRepository += $_.BaseName; }
. "$PSScriptRoot\Analyzers\AnalyzerRelations.ps1"

# Importing all action modules
Get-ChildItem -Path "$PSScriptRoot\Actions\*.psm1" | Foreach-Object { Import-Module $_.FullName -Force -Verbose:$false; $actionRepository += $_.BaseName; }
. "$PSScriptRoot\Actions\ActionRelations.ps1"

$totalActionsRecommended = @()

$analyzersRemainingToExecute = [System.Collections.Generic.List[string]](Optimize-Analyzers -Analyzers $analyzerRepository)
while ($analyzersRemainingToExecute.Count -gt 0)
{
    $analyzer = $analyzersRemainingToExecute[0]

    Write-Log "======================================================================================"
    Write-Log "Executing analyzer [$analyzer]...`r`n"
    $actionsRecommended = @(& $analyzer `
        -SQLServerInstance $SQLServerInstance `
        -ConfigurationDatabaseName $ConfigurationDatabaseName `
        -CollectionDatabaseName $CollectionDatabaseName `
        -CollectionName $CollectionName `
        -ElasticsearchServiceUrl $ElasticsearchServiceUrl `
        -ElasticsearchServiceCredential $ElasticsearchServiceCredential `
        -EntityType $EntityType `
        -Verbose:$VerbosePreference `
        -WhatIf:$WhatIfPreference `
        -Confirm:$confirmationRequired `
        -ErrorAction Stop)

    if ($actionsRecommended.Count -gt 0)
    {
        # Verify actions are supported
        foreach ($actionRecommended in $actionsRecommended)
        {
            $actionName = $actionRecommended.Split(@(" "), [System.StringSplitOptions]::RemoveEmptyEntries)[0]
            if (!$actionRepository.Contains($actionName))
            {
                throw "Action [$actionName] is not supported. Only the following actions are supported: [$actionRepository]. This is a bug in the script. Contact support."
            }
        }

        Write-Log "Actions recommended are [$($actionsRecommended -join ', ')]." -Level Warn
        $totalActionsRecommended += $actionsRecommended

        # Remove dependent analyzers from the execution list
        $dependentAnalyzers = Get-DependentAnalyzers -Analyzer $analyzer
        foreach ($dependentAnalyzer in $dependentAnalyzers)
        {
            $analyzersRemainingToExecute.Remove($dependentAnalyzer) | Out-Null
            Write-Verbose "Will not execute analyzer [$dependentAnalyzer] because analyzer [$analyzer] has reported problems."
        }
    }
    else
    {
        Write-Log "No issues found!"
    }

    $analyzersRemainingToExecute.Remove($analyzer) | Out-Null # Removing the analyzer just executed
}

if ($totalActionsRecommended.Count -eq 0)
{
    Write-Log "======================================================================================"
    Write-Log "No known issues found. System seems to be healthy. If not, please contact support."
    Write-Log "======================================================================================"
}
else
{
    $sanitizedActions = Optimize-Actions -Actions $totalActionsRecommended -ErrorAction Stop
    Write-Log "======================================================================================"
    Write-Log "Analysis is complete. Final list of recommended actions = [$($sanitizedActions -join ', ')]." -Level Warn

    foreach ($action in $sanitizedActions)
    {
        $tokens = $action.Split(@(" "), [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($tokens.Count -eq 1)
        {
            $actionCmdlet = $tokens[0]
            $additionalParam = $null
        }
        elseif ($tokens.Count -eq 2)
        {
            $actionCmdlet = $tokens[0]
            $additionalParam = $tokens[1]
        }

        Write-Log "======================================================================================"
        Write-Log "Executing action [$action]..."
        & $actionCmdlet `
            -SQLServerInstance $SQLServerInstance `
            -ConfigurationDatabaseName $ConfigurationDatabaseName `
            -CollectionDatabaseName $CollectionDatabaseName `
            -CollectionName $CollectionName `
            -ElasticsearchServiceUrl $ElasticsearchServiceUrl `
            -ElasticsearchServiceCredential $ElasticsearchServiceCredential `
            -EntityType $EntityType `
            -AdditionalParam $additionalParam `
            -Verbose:$VerbosePreference `
            -WhatIf:$WhatIfPreference `
            -Confirm:$confirmationRequired `
            -ErrorAction Stop
    }
}