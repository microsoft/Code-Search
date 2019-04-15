Set-StrictMode -Version Latest

# Key analyzer must be executed before any of the value analyzers.
# If key analyzer detects a problem, all of its dependent analyzers will not execute.
$AnalyzerPrecedesRelation = 
@{ 
    "Test-SqlHealth" = @("Test-ElasticsearchHealth", "Test-IndexingUnitPointsToDeletedIndex", "Test-FaultInJobInInfiniteRetries", "Test-InefficientTfvcCrawlingStoredProcedure")
    "Test-ElasticsearchHealth" = @("Test-IndicesHaveUnsupportedMappings", "Test-IndexingUnitPointsToDeletedIndex")
    "Test-IndicesHaveUnsupportedMappings" = @()
    "Test-IndexingUnitPointsToDeletedIndex" = @()
    "Test-FaultInJobInInfiniteRetries" = @()
    "Test-InefficientTfvcCrawlingStoredProcedure" = @()
}

. "$PSScriptRoot\..\Utils\Algorithms.ps1"

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
    $topologicallySortedAnalyzerRepository = Get-TopologicalSort -Graph $AnalyzerPrecedesRelation
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

function Get-DependentAnalyzers
{
    Param
    (
        [Parameter(Mandatory=$True)]
        [string] $Analyzer
    )

    $result = New-Object System.Collections.Generic.Stack[string]
    $visited = New-Object System.Collections.Generic.HashSet[string]
    Invoke-DfsWalk -Graph $AnalyzerPrecedesRelation -Vertex $Analyzer -Visited $visited -Result $result
    
    # Remove the top analyzer in the result stack because it is the input analyzer itself.
    $top = $result.Pop()
    if ($top -ne $Analyzer)
    {
        throw "Expected top of stack to be [$Analyzer] but found [$top]."
    }

    # Rest of the analyzers in the result stack are present in the DFS path from the input analyzer and by definition, depend on the input analyzer
    $dependentAnalyzers = @()
    while ($result.Count -gt 0)
    {
        $dependentAnalyzers += $result.Pop()
    }
    
    return $dependentAnalyzers
}