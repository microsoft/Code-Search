Set-StrictMode -Version Latest

<#
Repair-Search executes a suite of analyzers. Each analyzer tries to detect a known issue and recommends one or more
actions. These actions on execution would try to fix the issue detected. In few cases, a single analyzer may return 
multiple actions or more commonly, multiple analyzers may return multiple actions. Not all actions are mutually
exclussive; some have overlaps. In such a case, executing an action, say Action1, may not be necessary because another 
action, say Action2, if executed would do the job for both the actions or reset the state so that Action1 is not 
even required anymore. In this case, we define Action2 to supersede Action1, that is, if both Action1 and Action2 
are recommended, only Action2 would be executed instead of executing both Action1 and Action2. 

The hashtable below represents this relation as a directed acyclic graph defined using an adjacency list data structure.
Vertices of the graph are actions and a directed edge from V1 to V2 means V1 supersedes V2.

When you want to add a new action to this hashtable, check which of the existing actions should it supersede 
(prevent execution) and add them to its value array. Also check which of the existing actions will supersede
the new action and add it to their list.

NOTE: All actions must be defined as keys in this hashtable. This is asserted by a Pester test defined in
ActionRelations.Tests.ps1.
#>
$ActionSupersedesRelation = @{
    "Remove-OrphanIndexedDocuments" = @()
    "Request-ConfigureSearch" = @("Request-InstallSearchExtension")
    "Request-FixElasticsearchClusterState" = @()
    "Request-InstallSearchExtension" = @()
    "Request-ReconfigureSearch" = @("Request-ConfigureSearch", "Request-InstallSearchExtension")
    "Reset-ExtensionInstallationRegKeys" = @()
    "Restart-Indexing" = @("Reset-ExtensionInstallationRegKeys", "Enable-IndexingFeatureFlags", "Remove-OrphanIndexedDocuments")
    "Enable-IndexingFeatureFlags" = @()
    "Remove-Index" = @()
    "Request-Upgrade" = @()
}

<#
With supersedence sorted out, we may still end up with multiple actions to execute. Now we have to decide the
order in which these actions must be executed. While some actions may not have an ordering requirement, some 
other actions may.

The hashtable below represents this relation as a directed acyclic graph defined using an adjacency list data structure.
Vertices of the graph are actions and a directed edge from V1 to V2 means V1 must be executed before V2.
We use topological sort algorithm to get the desired ordering of actions recommended.

When you want to add a new action to this hashtable, check which of the existing actions should it be executed
before and add them to its value array. Also check which of the existing actions should precede the new action
and add it to their list.

NOTE: All actions must be defined as keys in this hashtable. This is asserted by a Pester test defined in
ActionRelations.Tests.ps1.
#>
$ActionPrecedesRelation = @{
    "Remove-OrphanIndexedDocuments" = @("Request-InstallSearchExtension")
    "Request-ConfigureSearch" = @("Restart-Indexing")
    "Request-FixElasticsearchClusterState" = @("Remove-OrphanIndexedDocuments", "Request-ConfigureSearch", "Request-InstallSearchExtension", "Request-ReconfigureSearch", "Restart-Indexing", "Enable-IndexingFeatureFlags")
    "Request-InstallSearchExtension" = @("Restart-Indexing")
    "Request-ReconfigureSearch" = @("Restart-Indexing")
    "Reset-ExtensionInstallationRegKeys" = @()
    "Restart-Indexing" = @()
    "Enable-IndexingFeatureFlags" = @("Request-ConfigureSearch", "Request-InstallSearchExtension", "Request-ReconfigureSearch")
    "Remove-Index" = @("Remove-OrphanIndexedDocuments", "Request-ConfigureSearch", "Request-FixElasticsearchClusterState", "Request-InstallSearchExtension", "Request-ReconfigureSearch", "Restart-Indexing", "Enable-IndexingFeatureFlags")
    "Request-Upgrade" = @()
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

    Write-Verbose "Actions post additional param separation = [$optimizedActions]."

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