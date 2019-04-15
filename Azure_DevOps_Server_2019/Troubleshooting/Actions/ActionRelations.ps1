Set-StrictMode -Version Latest

$ActionSupersedesRelation = @{ # If key and one of the values are both recommended actions, then only executing key is enough
    "Remove-OrphanIndexedDocuments" = @()
    "Request-ConfigureSearch" = @("Request-InstallSearchExtension")
    "Request-FixElasticsearchClusterState" = @()
    "Request-InstallSearchExtension" = @()
    "Request-ReconfigureSearch" = @("Request-ConfigureSearch", "Request-InstallSearchExtension")
    "Request-TfvcSProcHotfix" = @()
    "Reset-ExtensionInstallationRegKeys" = @()
    "Restart-Indexing" = @("Reset-ExtensionInstallationRegKeys")
    "Remove-Index" = @()
}

$ActionPrecedesRelation = @{ # If key and one of the values are both recommended actions, then key must be executed before that one value
    "Remove-OrphanIndexedDocuments" = @("Request-InstallSearchExtension", "Restart-Indexing")
    "Request-ConfigureSearch" = @("Restart-Indexing")
    "Request-FixElasticsearchClusterState" = @("Remove-OrphanIndexedDocuments", "Request-ConfigureSearch", "Request-InstallSearchExtension", "Request-ReconfigureSearch", "Restart-Indexing")
    "Request-InstallSearchExtension" = @("Restart-Indexing")
    "Request-ReconfigureSearch" = @("Restart-Indexing")
    "Request-TfvcSProcHotfix" = @()
    "Reset-ExtensionInstallationRegKeys" = @()
    "Restart-Indexing" = @()
    "Remove-Index" = @("Remove-OrphanIndexedDocuments", "Request-ConfigureSearch", "Request-FixElasticsearchClusterState", "Request-InstallSearchExtension", "Request-ReconfigureSearch", "Restart-Indexing")
}

. "$PSScriptRoot\..\Utils\Algorithms.ps1"

function Optimize-Actions
{
    Param
    (
        [Parameter(Mandatory=$True)]
        [string[]] $Actions
    )

    Write-Verbose "Input actions = [$($Actions -join ', ')]."

    # Remove duplicates
    $optimizedActions = [System.Collections.Generic.List[string]]($Actions | select -Unique)

    Write-Verbose "Deduplicated actions = [$($optimizedActions -join ', ')]."

    $actionParamsMap = @{}
    foreach ($action in $Actions)
    {
        $tokens = $action.Split(@(" "), [System.StringSplitOptions]::RemoveEmptyEntries)
        if ($tokens.Count -eq 1)
        {
            $actionName = $tokens[0]
            $actionParam = $null
        }
        elseif ($tokens.Count -eq 2)
        {
            $actionName = $tokens[0]
            $actionParam = $tokens[1]
        }
        else
        {
            throw "Action [$action] has unsupported format. It can only be the name of the action cmdlet conditionally followed by a space followed by the value of `$AdditionalParam to pass along with the action."
        }

        if ($actionParamsMap.ContainsKey($actionName))
        {
            $actionParamsMap[$actionName] += @($actionParam)
        }
        else
        {
            $actionParamsMap[$actionName] = @($actionParam)
        }
    }

    # Separate additional param from the action name for sanitization. It is assumed that all actions with the same name enjoy the same supersedence and precedence rules.
    $optimizedActions = [System.Collections.Generic.List[string]]($actionParamsMap.Keys | select)

    Write-Verbose "Actions post additional param separation= [$optimizedActions]."

    # Remove actions superseded by optimized actions
    $supersededActions = New-Object System.Collections.Generic.HashSet[string]
    foreach ($action in $optimizedActions)
    {
        foreach ($supersededAction in $ActionSupersedesRelation[$action])
        {
            $supersededActions.Add($supersededAction) | Out-Null
        }
    }

    Write-Verbose "Superseded actions = [$supersededActions]."

    foreach ($supersededAction in $supersededActions)
    {
        $optimizedActions.Remove($supersededAction) | Out-Null
    }

    Write-Verbose "After removing superseded actions = [$optimizedActions]."

    # Order actions
    # Get topological sort for all actions in the repository
    $topologicallySortedActionRepository = Get-TopologicalSort -Graph $ActionPrecedesRelation
    Write-Verbose "Topologically sorted action repository = [$topologicallySortedActionRepository]."

    # Given the ordering between all actions, select the recommended actions in the same order
    $sortedActions = @()
    foreach ($action in $topologicallySortedActionRepository)
    {
        if ($optimizedActions.Contains($action))
        {
            $sortedActions += $action
        }
    }

    # Plugin additional params back with the action names
    $sortedActionsWithParams = @()
    foreach ($action in $sortedActions)
    {
        $additionalParams = $actionParamsMap[$action]
        foreach ($param in $additionalParams)
        {
            if ($param)
            {
                $sortedActionsWithParams += "$action $param"
            }
            else
            {
                $sortedActionsWithParams += $action
            }
        }
    }

    return $sortedActionsWithParams
}