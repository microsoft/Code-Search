Set-StrictMode -Version Latest

. "$PSScriptRoot\AnalyzerRelations.ps1"

Describe "Analyzer relations" {
    $AnalyzerRepository = @()
    Get-ChildItem -Path "$PSScriptRoot\*.psm1" | Foreach-Object { $AnalyzerRepository += $_.BaseName }

    It "should have all analyzers represented in `$AnalyzerPrecedesRelation" {
        $relationKeys = $AnalyzerPrecedesRelation.Keys | % ToString
        Compare-Object $AnalyzerRepository $relationKeys | Should Be $null
    }

    It "should have valid and distinct analyzer list in values of `$AnalyzerPrecedesRelation" {
        foreach ($analyzers in $AnalyzerPrecedesRelation.Values)
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

    It "should not have cyclic relations in `$AnalyzerPrecedesRelation" {
        Test-CycleInGraph -Graph $AnalyzerPrecedesRelation | Should Be $false
    }
}

Describe "Optimize-Analyzers" {
    $sortedAnalyzerRepository = Get-TopologicalSort -Graph $AnalyzerPrecedesRelation
    foreach ($relation in $AnalyzerPrecedesRelation.GetEnumerator())
    {
        $precedingAnalyzer = $relation.Name
        foreach ($followingAnalyzer in $relation.Value)
        {
            It "should return analyzer [$precedingAnalyzer] before analyzer [$followingAnalyzer]" {
                $sortedAnalyzerRepository.IndexOf($precedingAnalyzer) | Should BeLessThan $sortedAnalyzerRepository.IndexOf($followingAnalyzer)
            }
        }
    }
    
    It "should remove duplicate analyzers" {
        $testAnalyzers = @("Test-SqlHealth", "Test-SqlHealth")
        $result = Optimize-Analyzers -Analyzers $testAnalyzers
        $result | Should Be @("Test-SqlHealth")
    }
}

Describe "Get-DependentAnalyzers" {
    It "should not return itself as dependent analyzer" {
        foreach ($analyzer in $AnalyzerPrecedesRelation.Keys)
        {
            $result = @(Get-DependentAnalyzers -Analyzer $analyzer)
            $result.Contains($analyzer) | Should Be $false
        }
    }

    It "should not return anything for an analyzer which has no dependent analyzers" {
        $result = @(Get-DependentAnalyzers -Analyzer "Test-InefficientTfvcCrawlingStoredProcedure")
        $result.Count | Should Be 0
    }

    It "should return dependent analyzers even if there is no direct relation between them" {
        $result = @(Get-DependentAnalyzers -Analyzer "Test-SqlHealth")
        $result.Contains("Test-IndicesHaveUnsupportedMappings") | Should Be $true
    }
}