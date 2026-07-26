Set-StrictMode -Version Latest

<#
Repair-Search executes a suite of analyzers. It makes sense that some analyzers be executed before other analyzers. For example,
Test-*Health analyzers should be executed before known issue analyzers because the later may fail if the system is unhealthy.
This is the precedence relation. Also, if an analyzer AN1 recommends one or more actions, executing another analyzer AN2 may 
not be required. This is the supersedence relation. For analyzers (unlike actions), both these relations are the same.

The hashtable below represents this relation as a directed acyclic graph defined using an adjacency list data structure.
Vertices of the graph are analyzers and a directed edge from V1 to V2 means V1 should be executed before V2 and if V1
recommends one more more actions, V2 should not be executed. Note that if edges V1->V2 and V2->V3 are present and
V1 recommends an action, both V2 and V3 will not be executed. Hence, do not add relations to this hashtable if there is none,
because that may result in not executing an analyzer. The ordering of analyzers is determined by topologically sorting this tree.

When you want to add a new analyzer to this hashtable, check which of the existing analyzers should it be executed
before and add them to its value array. Also check which of the existing analyzers should precede the new analyzer
and add it to their list.

NOTE: All analyzers must be defined as keys in this hashtable. This is asserted by a Pester test defined in
AnalyzerRelations.Tests.ps1.
#>
$AnalyzerPrecedesAndSupersedesRelation = 
@{ 
    "Test-SqlHealth" = @("Test-ElasticsearchHealth", "Test-IndexingUnitPointsToDeletedIndex", "Test-FaultInJobInInfiniteRetries", "Test-GeneralTfvcIssues")
    "Test-ElasticsearchHealth" = @("Test-IndicesHaveUnsupportedMappings", "Test-IndexingUnitPointsToDeletedIndex", "Test-FaultInJobInInfiniteRetries")
    "Test-IndicesHaveUnsupportedMappings" = @()
    "Test-IndexingUnitPointsToDeletedIndex" = @()
    "Test-FaultInJobInInfiniteRetries" = @()
    "Test-GeneralTfvcIssues" = @()
}

 "$PSScriptRoot\..\Utils\Algorithms.ps1"

function Optimize-Analyzers
{
    Param
    (
        [Parameter(Mandatory=$True)]
        [string[]] $Analyzers
    )

    Write-Verbose "Input analyzers = [$($Analyzers -join ', ')]."

    # Remove duplicates
    $optimizedAnalyzers = [System.Collections.Generic.List[string]]($Analyzers | select -Unique)

    Write-Verbose "Deduplicated analyzers = [$($optimizedAnalyzers -join ', ')]."

    # Order analyzers
    # Get topological sort for all analyzers in the repository
    $topologicallySortedAnalyzerRepository = Get-TopologicalSort -Graph $AnalyzerPrecedesAndSupersedesRelation
    Write-Verbose "Topologically sorted analyzer repository = [$topologicallySortedAnalyzerRepository]."

    # Given the ordering between all analyzers, select the recommended analyzers in the same order
    $sortedAnalyzers = @()
    foreach ($analyzer in $topologicallySortedAnalyzerRepository)
    {
        if ($optimizedAnalyzers.Contains($analyzer))
        {
            $sortedAnalyzers += $analyzer
        }
    }

    return $sortedAnalyzers
}

function Get-SupersededAnalyzers
{
    <#
    .SYNOPSIS
    Given an analyzer, get all analyzers preceded and superseded by it. 
    In terms of graph theory, this returns all vertices reachable from the given vertex through edge traversal.
    #>
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $Analyzer
    )

    $result = New-Object System.Collections.Generic.Stack[string]
    $visited = New-Object System.Collections.Generic.HashSet[string]
    Invoke-DfsWalk -Graph $AnalyzerPrecedesAndSupersedesRelation -Vertex $Analyzer -Visited $visited -Result $result
    
    # Remove the top analyzer in the result stack because it is the input analyzer itself.
    $top = $result.Pop()
    if ($top -ne $Analyzer)
    {
        throw "Expected top of stack to be [$Analyzer] but found [$top]."
    }

    # Rest of the analyzers in the result stack are present in the DFS path from the input analyzer and by definition, depend on the input analyzer
    $supersededAnalyzers = @()
    while ($result.Count -gt 0)
    {
        $supersededAnalyzers += $result.Pop()
    }
    
    return $supersededAnalyzers
}