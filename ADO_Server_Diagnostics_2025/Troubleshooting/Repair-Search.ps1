# Azure DevOps Server 2025 - Elasticsearch 8.14
<#
    .SYNOPSIS
    For a given collection and entity type, detect and mitigate known issues in Azure DevOps Server 2025.

    .DESCRIPTION
    Repair-Search works with two main concepts - Analyzers and Actions.
        
    Analyzers are cmdlets defined inside .\Analyzers directory. They are executed by Repair-Search in a well-defined order.
    These analyzers try to detect any known issues or incorrect configuration in the system. After all analyzers are executed, 
    they return one or more recommended actions.
    
    Actions are cmdlets defined inside .\Actions directory. Actions fix the problem detected earlier by the analyzers.
    By default, actions that have high impact on the system are not executed without user confirmation. So, it is safe to execute this script.
    If you feel the recommended action should not be executed, you can choose to do so when prompted by this script.
    If you want to just check what actions would be executed without actually executing them, pass -WhatIf switch with this script.
    If you want to execute all recommended actions without user confirmation, set $ConfirmPreference to 'None'.

    Execute Repair-Search. Execute the recommended actions (manual or automated). Repeat this till no more action is recommended.

    .PARAMETER SQLServerInstance
    The SQL server instance hosting the configuration and collection databases.
    Examples: "ServerName", "ServerName\InstanceName", "localhost", ".", "ServerName,1433"

    .PARAMETER ElasticsearchServiceUrl
    URL of Elasticsearch service. Must include protocol (http/https) and port.
    Examples: "http://localhost:9200", "https://elastic-server:9200"

    .PARAMETER ElasticsearchServiceCredential
    Credential for connecting to the Elasticsearch service. Use Get-Credential to create.
    For local Elasticsearch without authentication, you can use empty credentials.

    .PARAMETER ConfigurationDatabaseName
    Configuration database name for Azure DevOps Server.
    Default name is usually "AzureDevOps_Configuration" or "TFS_Configuration"

    .PARAMETER CollectionDatabaseName
    Collection database name for the impacted collection.
    Example: "AzureDevOps_DefaultCollection", "AzureDevOps_MyCollection"

    .PARAMETER CollectionName
    Name of the impacted collection (as shown in Azure DevOps Server Administration Console).
    Example: "DefaultCollection", "MyCollection"

    .PARAMETER EntityType
    Entity type to repair: Code (source code), WorkItem (work items), or Wiki (wiki pages).
    Valid values: "Code", "WorkItem", "Wiki"

    .INPUTS
    None. You cannot pipe objects to Repair-Search.

    .OUTPUTS
    None. Repair-Search does not return any object.

    .EXAMPLE
    PS>.\Repair-Search -SQLServerInstance "." -ConfigurationDatabaseName "AzureDevOps_Configuration" -CollectionDatabaseName "AzureDevOps_DefaultCollection" -CollectionName "DefaultCollection" -ElasticsearchServiceUrl "http://localhost:9200" -ElasticsearchServiceCredential $(Get-Credential) -EntityType "Code"
    
    Repairs code search issues for the DefaultCollection.
    - SQL Server is on the local machine (represented by ".")
    - Standard database names for Azure DevOps Server 2025
    - Elasticsearch is running locally on default port 9200
    - Prompts for Elasticsearch credentials via dialog
    - Repairs code search functionality
    
    .EXAMPLE
    PS># Store credentials once to avoid repeated prompts
    PS>$cred = Get-Credential -UserName "elastic" -Message "Enter Elasticsearch password"
    PS>.\Repair-Search -SQLServerInstance "MYSERVER\SQLEXPRESS" -ConfigurationDatabaseName "AzureDevOps_Configuration" -CollectionDatabaseName "AzureDevOps_MyProject" -CollectionName "MyProject" -ElasticsearchServiceUrl "http://elastic-server:9200" -ElasticsearchServiceCredential $cred -EntityType "Code"
    
    Repairs code search for a custom collection on a named SQL Server instance.
    - SQL Server instance name is "MYSERVER\SQLEXPRESS"
    - Custom collection database "AzureDevOps_MyProject"
    - Remote Elasticsearch server
    - Pre-stored credentials to avoid prompts
    
    .EXAMPLE
    PS>.\Repair-Search -SQLServerInstance "." -ConfigurationDatabaseName "AzureDevOps_Configuration" -CollectionDatabaseName "AzureDevOps_DefaultCollection" -CollectionName "DefaultCollection" -ElasticsearchServiceUrl "http://localhost:9200" -ElasticsearchServiceCredential $(Get-Credential) -EntityType "WorkItem" -WhatIf
    
    Simulates repair of work item search issues without making any changes.
    Use -WhatIf to see what actions would be performed before actually running them.
    
    .EXAMPLE
    PS># Run without confirmation prompts for automated scenarios
    PS>$ConfirmPreference = 'None'
    PS>$cred = New-Object PSCredential("elastic", (ConvertTo-SecureString "password" -AsPlainText -Force))
    PS>.\Repair-Search -SQLServerInstance "." -ConfigurationDatabaseName "AzureDevOps_Configuration" -CollectionDatabaseName "AzureDevOps_DefaultCollection" -CollectionName "DefaultCollection" -ElasticsearchServiceUrl "http://localhost:9200" -ElasticsearchServiceCredential $cred -EntityType "Wiki"
    
    Repairs wiki search issues without user confirmation prompts.
    Useful for automated scripts or when you're confident about the actions to be taken.
#>
[CmdletBinding(SupportsShouldProcess=$True)]
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
    [uri] $ElasticsearchServiceUrl,

    [Parameter(Mandatory=$True)]
    [PSCredential] $ElasticsearchServiceCredential,

    [Parameter(Mandatory=$True)]
    [ValidateSet("Code", "WorkItem", "Wiki")]
    [string] $EntityType
)

$ErrorActionPreference = "Stop" # We do not want to continue executing the script if we encounter a failure

$confirmationRequired = $ConfirmPreference -gt "None"

Import-Module "$PSScriptRoot\Utils\Common.psm1" -DisableNameChecking -Force -Verbose:$false

# Saving the value of log file path to a global variable so that it is not required to pass it along to every function invoked.
$logFilePath = "$PSScriptRoot\Repair-Search_$(((Get-Date).ToUniversalTime()).ToString(`"yyyy-MM-ddTHH-mm-ssZ`")).log"
Set-Variable LogFilePath -Option AllScope -Scope Global -Force -Value $logFilePath -Confirm:$false -WhatIf:$false

# $VerbosePreference does not get passed to all cmdlets by default for some reason. To avoid having to pass it explicitly to all cmdlets
# which is prone to manual error, we will save its value in a global variable which will be accessible everywhere.
Set-Variable RepairSearchVerbosePreference -Option ReadOnly -Scope Global -Force -Value $VerbosePreference -Confirm:$false -WhatIf:$false

try
{
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
        Write-Log "Executing analyzer [$analyzer]..."
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
                    throw "Action [$actionName] is not supported. Only the following actions are supported: [$actionRepository]. This is a code bug."
                }
            }

            Write-Log "Actions recommended are [$($actionsRecommended -join ', ')]." -Level Warn
            $totalActionsRecommended += $actionsRecommended

            # Remove superseded analyzers from the execution list
            $supersededAnalyzers = Get-SupersededAnalyzers -Analyzer $analyzer
            foreach ($supersededAnalyzer in $supersededAnalyzers)
            {
                $analyzersRemainingToExecute.Remove($supersededAnalyzer) | Out-Null
                Write-Log "Will not execute analyzer [$supersededAnalyzer] because analyzer [$analyzer] has reported problems." -Level Verbose
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
        Write-Log "No known issues found. System seems to be healthy. If not, please collect diagnostic data by following steps in https://github.com/Microsoft/Code-Search/blob/master/Azure_DevOps_Server_2019/SearchDiagonistics/README.txt, and file an issue at https://developercommunity.visualstudio.com/content/problem/post.html?space=22." -Level Attention
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
            Write-Log "Executing action [$action]..." -Level Warn
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
}
catch [ArgumentException]
{
    Write-Log "Inputs provided to Repair-Search may be incorrect. See the error message below for more details:`r`n$_" -Level Attention
}
catch
{
    $message = ("Message:`r`n" + ($_ | Out-String) + "`r`nStack Trace:`r`n" + ($_.ScriptStackTrace))
    Write-Log "Repair-Search failed with following exception:`r`n$message" -Level Error
}
finally
{
    Write-Log "Log file saved at $LogFilePath" -Level Info
}