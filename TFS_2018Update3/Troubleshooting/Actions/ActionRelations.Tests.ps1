Set-StrictMode -Version Latest

. "$PSScriptRoot\ActionRelations.ps1"

Describe "Action relations" {
    $ActionRepository = @()
    Get-ChildItem -Path "$PSScriptRoot\*.psm1" | Foreach-Object { $ActionRepository += $_.BaseName }

    It "should have all actions represented in `$ActionSupersedesRelation" {
        $relationKeys = $ActionSupersedesRelation.Keys | % ToString
        Compare-Object $ActionRepository $relationKeys | Should Be $null
    }

    It "should have all actions represented in `$ActionPrecedesRelation" {
        $relationKeys = $ActionPrecedesRelation.Keys | % ToString
        Compare-Object $ActionRepository $relationKeys | Should Be $null
    }

    It "should have valid and distinct action list in values of `$ActionSupersedesRelation" {
        foreach ($actions in $ActionSupersedesRelation.Values)
        {
            $uniqueActionCount = @($actions | select -Unique).Count
            $actualActionCount = $actions.Count
            $actualActionCount | Should Be $uniqueActionCount

            foreach ($action in $actions)
            {
                $ActionRepository.Contains($action) | Should Be $true
            }
        }
    }

    It "should have valid and distinct action list in values of `$ActionPrecedesRelation" {
        foreach ($actions in $ActionPrecedesRelation.Values)
        {
            $uniqueActionCount = @($actions | select -Unique).Count
            $actualActionCount = $actions.Count
            $actualActionCount | Should Be $uniqueActionCount

            foreach ($action in $actions)
            {
                $ActionRepository.Contains($action) | Should Be $true
            }
        }
    }

    It "should not have cyclic relations in `$ActionSupersedesRelation" {
        Test-CycleInGraph -Graph $ActionSupersedesRelation | Should Be $false
    }

    It "should not have cyclic relations in `$ActionPrecedesRelation" {
        Test-CycleInGraph -Graph $ActionPrecedesRelation | Should Be $false
    }

    It "should not have order relation between two actions if one supersedes the other" {
        foreach ($relation in $ActionSupersedesRelation.GetEnumerator())
        {
            $keyAction = $relation.Name
            foreach ($relationAction in $relation.Value)
            {
                $ActionPrecedesRelation[$keyAction].Contains($relationAction) | Should Be $false
                $ActionPrecedesRelation[$relationAction].Contains($keyAction) | Should Be $false
            }
        }
    }
}

Describe "Optimize-Actions" {
    foreach ($relation in $ActionSupersedesRelation.GetEnumerator())
    {
        $supersederAction = $relation.Name
        foreach ($supersededAction in $relation.Value)
        {
            It "should not return superseded action [$supersededAction] if action [$supersederAction] is also recommended" {
                $result = Optimize-Actions -Actions @($supersededAction, $supersederAction)
                $result | Should Be @($supersederAction)
            }
        }
    }

    $sortedActionRepository = Get-TopologicalSort -Graph $ActionPrecedesRelation
    foreach ($relation in $ActionPrecedesRelation.GetEnumerator())
    {
        $precedingAction = $relation.Name
        foreach ($followingAction in $relation.Value)
        {
            It "should return action [$precedingAction] before action [$followingAction]" {
                $sortedActionRepository.IndexOf($precedingAction) | Should BeLessThan $sortedActionRepository.IndexOf($followingAction)
            }
        }
    }
    
    It "should remove duplicate actions" {
        $testActions = @("Request-ConfigureSearch", "Request-ConfigureSearch")
        $result = Optimize-Actions -Actions $testActions
        $result | Should Be @("Request-ConfigureSearch")
    }

    It "should remove higher degree superseded actions" {
        $testActions = @("Request-ReconfigureSearch", "Request-ConfigureSearch", "Request-InstallSearchExtension")
        $result = Optimize-Actions -Actions $testActions
        $result | Should Be @("Request-ReconfigureSearch")
    }
}
