Set-StrictMode -Version Latest

. "$PSScriptRoot\AnalyzerRelations.ps1"

Describe "Analyzer relations" {
    $AnalyzerRepository = @()
    Get-ChildItem -Path "$PSScriptRoot\*.psm1" | Foreach-Object { $AnalyzerRepository += $_.BaseName }

    It "should have all analyzers represented in `$AnalyzerPrecedesAndSupersedesRelation" {
        $relationKeys = $AnalyzerPrecedesAndSupersedesRelation.Keys | % ToString
        Compare-Object $AnalyzerRepository $relationKeys | Should Be $null
    }

    It "should have valid and distinct analyzer list in values of `$AnalyzerPrecedesAndSupersedesRelation" {
        foreach ($analyzers in $AnalyzerPrecedesAndSupersedesRelation.Values)
        {
            $uniqueAnalyzerCount = @($analyzers | select -Unique).Count
            $actualAnalyzerCount = $analyzers.Count
            $actualAnalyzerCount | Should Be $uniqueAnalyzerCount

            foreach ($analyzer in $analyzers)
            {
                $AnalyzerRepository.Contains($analyzer) | Should Be $true
            }
        }
    }

    It "should not have cyclic relations in `$AnalyzerPrecedesAndSupersedesRelation" {
        Test-CycleInGraph -Graph $AnalyzerPrecedesAndSupersedesRelation | Should Be $false
    }
}

Describe "Optimize-Analyzers" {
    $sortedAnalyzerRepository = Get-TopologicalSort -Graph $AnalyzerPrecedesAndSupersedesRelation
    foreach ($relation in $AnalyzerPrecedesAndSupersedesRelation.GetEnumerator())
    {
        $precedingAnalyzer = $relation.Name
        foreach ($followingAnalyzer in $relation.Value)
        {
            It "should return analyzer [$precedingAnalyzer] before analyzer [$followingAnalyzer]" {
                $sortedAnalyzerRepository.IndexOf($precedingAnalyzer) | Should BeLessThan $sortedAnalyzerRepository.IndexOf($followingAnalyzer)
            }
        }
    }
    
    $optmizedAnalyzers = Optimize-Analyzers -Analyzers $sortedAnalyzerRepository
    It "should return analyzer Test-ElasticsearchHealth before Test-FaultInJobInInfiniteRetries" {
        $optmizedAnalyzers.IndexOf("Test-ElasticsearchHealth") | Should BeLessThan $optmizedAnalyzers.IndexOf("Test-FaultInJobInInfiniteRetries")
    }

    It "should remove duplicate analyzers" {
        $testAnalyzers = @("Test-SqlHealth", "Test-SqlHealth")
        $result = Optimize-Analyzers -Analyzers $testAnalyzers
        $result | Should Be @("Test-SqlHealth")
    }
}

Describe "Get-SupersededAnalyzers" {
    It "should not return itself as superseded analyzer" {
        foreach ($analyzer in $AnalyzerPrecedesAndSupersedesRelation.Keys)
        {
            $result = @(Get-SupersededAnalyzers -Analyzer $analyzer)
            $result.Contains($analyzer) | Should Be $false
        }
    }

    It "should not return anything for an analyzer which has no superseded analyzers" {
        $result = @(Get-SupersededAnalyzers -Analyzer "Test-GeneralTfvcIssues")
        $result.Count | Should Be 0
    }

    It "should return superseded analyzers even if there is no direct relation between them" {
        $result = @(Get-SupersededAnalyzers -Analyzer "Test-SqlHealth")
        $result.Contains("Test-IndicesHaveUnsupportedMappings") | Should Be $true
    }
}