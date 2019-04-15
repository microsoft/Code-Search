## Algorithm for detecting cycle in directed graph

# Code inspired from https://www.youtube.com/watch?v=rKQaZuoUR4M
function Test-CycleInGraph
{
    Param
    (
        [Parameter(Mandatory=$True)]
        [hashtable] $Graph
    )

    $unvistedVertices = [System.Collections.Generic.HashSet[string]]($Graph.Keys | select )
    $vistedVerticesInCurrentDfsWalk = New-Object System.Collections.Generic.HashSet[string]
    $completelyExploredVertices = New-Object System.Collections.Generic.HashSet[string]

    while ($unvistedVertices.Count -gt 0)
    {
        $vertex = $unvistedVertices | select -First 1
        if (Test-DfsPathContainsLoop -Graph $Graph -Vertex $vertex -UnvistedVertices $unvistedVertices -VistedVerticesInCurrentDfsWalk $vistedVerticesInCurrentDfsWalk -CompletelyExploredVertices $completelyExploredVertices)
        {
            return $true
        }
    }

    return $false
}

function Test-DfsPathContainsLoop
{
    Param
    (
        [Parameter(Mandatory=$True)]
        [hashtable] $Graph,

        [Parameter(Mandatory=$True)]
        [string] $Vertex,

        [Parameter(Mandatory=$False)]
        [System.Collections.Generic.HashSet[string]] $UnvistedVertices,

        [Parameter(Mandatory=$False)]
        [System.Collections.Generic.HashSet[string]] $VistedVerticesInCurrentDfsWalk,

        [Parameter(Mandatory=$False)]
        [System.Collections.Generic.HashSet[string]] $CompletelyExploredVertices
    )

    if (!$UnvistedVertices.Remove($Vertex))
    {
        throw "Vertex [$Vertex] was expected to be in `$UnvistedVertices but it was not present. Contents of `$UnvistedVertices are [$UnvistedVertices]."
    }

    if (!$VistedVerticesInCurrentDfsWalk.Add($Vertex))
    {
        throw "Vertex [$Vertex] was not expected to be in `$VistedVerticesInCurrentDfsWalk but it was present. Contents of `$VistedVerticesInCurrentDfsWalk are [$VistedVerticesInCurrentDfsWalk]."
    }

    foreach ($neighbour in $Graph[$Vertex])
    {
        if ($VistedVerticesInCurrentDfsWalk.Contains($neighbour))
        {
            Write-Verbose "Found neighbour [$neighbour] of vertex [$Vertex] in the DFS path. Found a loop."
            return $true
        }

        if ($CompletelyExploredVertices.Contains($neighbour))
        {
            continue
        }

        if (Test-DfsPathContainsLoop -Graph $Graph -Vertex $neighbour -UnvistedVertices $UnvistedVertices -VistedVerticesInCurrentDfsWalk $VistedVerticesInCurrentDfsWalk -CompletelyExploredVertices $CompletelyExploredVertices)
        {
            return $true
        }
    }

    if (!$VistedVerticesInCurrentDfsWalk.Remove($Vertex))
    {
        throw "Vertex [$Vertex] was expected to be in `$VistedVerticesInCurrentDfsWalk but it was not present. Contents of `$VistedVerticesInCurrentDfsWalk are [$VistedVerticesInCurrentDfsWalk]."
    }

    if (!$CompletelyExploredVertices.Add($Vertex))
    {
        throw "Vertex [$Vertex] was not expected to be in `$CompletelyExploredVertices but it was present. Contents of `$CompletelyExploredVertices are [$CompletelyExploredVertices]."
    }

    return $false
}

## Topological sort algorithm

function Get-TopologicalSort
{
    Param
    (
        [Parameter(Mandatory=$True)]
        [hashtable] $Graph
    )

    $result = New-Object System.Collections.Generic.Stack[string]
    $visited = New-Object System.Collections.Generic.HashSet[string]

    foreach ($vertex in $Graph.Keys)
    {
        if (!$visited.Contains($vertex))
        {
            Invoke-DfsWalk -Graph $Graph -Vertex $vertex -Visited $visited -Result $result
        }
    }

    $sortedResult = @()
    while ($result.Count -gt 0)
    {
        $sortedResult += $result.Pop()
    }
    
    return $sortedResult
}

function Invoke-DfsWalk
{
    Param
    (
        [Parameter(Mandatory=$True)]
        [hashtable] $Graph,

        [Parameter(Mandatory=$True)]
        [string] $Vertex,

        [Parameter(Mandatory=$False)]
        [System.Collections.Generic.HashSet[string]] $Visited,

        [Parameter(Mandatory=$False)]
        [System.Collections.Generic.Stack[string]] $Result
    )

    if (!$Visited.Add($Vertex))
    {
        throw "Vertex [$vertex] was not expected to be in `$Visited set already. Contents of `$Visited set = [$Visited]."
    }

    foreach ($neighbour in $Graph[$Vertex])
    {
        if (!$Visited.Contains($neighbour))
        {
            Invoke-DfsWalk -Graph $Graph -Vertex $neighbour -Visited $Visited -Result $Result
        }
    }

    $Result.Push($Vertex)
}