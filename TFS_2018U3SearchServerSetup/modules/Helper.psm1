Import-Module $PSScriptRoot\Logger.psm1
Import-Module $PSScriptRoot\FunctionHelper.psm1

function GetScriptDirectory
{
    <#
        .DESCRIPTION
        Returns the invocation path of the script.
    #>
    [CmdletBinding()]
    Param()
    return Split-Path $script:MyInvocation.MyCommand.Path
}

function GetPhysicalMemoryInGB
{
    <#
        .DESCRIPTION
        Calculates the RAM of the machine in MBs
    #>
    [CmdletBinding()]
    Param()
    
    $memory = Get-WMIObject Win32_PhysicalMemory
    $totalCap = 0
    Foreach ($stick in $memory)
    {
        $cap=$stick.capacity/1mb
        $totalCap += $cap        
    }
    return ($totalCap/1024)
}

function GetBasePath
{
    <#
        .DESCRIPTION
        This function returns a top level directory path of input path.

        .PARAMETER fullPath
        Full path which needs to be converted to a subpath

        .PARAMETER numChildsToSkip
        integer representing the number of folders(levels) which should be skipped from the input path
    #>
    [CmdletBinding()]
    param
    (
        [string] $fullPath,
        [int] $numChildsToSkip
    )

    $path = $fullPath
    for($i=1; $i -le $numChildsToSkip; $i++)
    {
        $path = Split-Path -Path $path
    }
    return $path
}

function ConvertToJson
{
    <#
        .DESCRIPTION
        Converts the object to JSON notation. It uses the inbuilt 'ConvertTo-Json' to do the serialization.
        If this command is not available (for older version of powershell) then .Net serializer is used.

        .PARAMETER item
        Object which needs to be serialzed to JSON
    #>
    [CmdletBinding()]
    param
    (
        [object] $item
    )

    if ($item -eq $null)
    {
        LogError "Input to ConvertToJson is null."
        return $null
    }

    if (Get-Command ConvertTo-Json -ErrorAction SilentlyContinue)
    {
        return ConvertTo-Json $item
    }
    else 
    {
        <#
        requires .Net 3.5
        #>
        add-type -assembly system.web.extensions
        $ps_js=new-object system.web.script.serialization.javascriptSerializer
        return $ps_js.Serialize($item)
    }
}

function ConvertFromJson
{
    <#
        .DESCRIPTION
        Converts the JSON notation to object. It uses the inbuilt 'ConvertFrom-Json' to do the serialization.
        If this command is not available (for older version of powershell) then .Net serializer is used.

        .PARAMETER jsonString
        string which needs to be de-serialzed to object from JSON
    #>
    [CmdletBinding()]
    param
    (
        [string] $jsonString
    )

    if ($jsonString -eq $null)
    {
        LogError "Input to ConvertFromoJson is null."
        return $null
    }

    if (Get-Command ConvertFrom-Json -ErrorAction SilentlyContinue)
    {
        return $jsonString | ConvertFrom-Json
    }
    else 
    {
        <#
        requires .Net 3.5
        #>
        add-type -assembly system.web.extensions
        $ps_js=new-object system.web.script.serialization.javascriptSerializer
        return $ps_js.DeserializeObject($jsonString)
    }
}

function ExtractFiles
{
    <#
        .DESCRIPTION
        Extracts the zip file to the location provided.
        It uses the latest command 'Expand-Archive' if available otherwise it fallsback to shell for extraction

        .PARAMETER ZipPath
        Path of the zip file to extract.
        
        .PARAMETER DestinationPath
        Directory where the zip file needs to be extracted        
    #>
    [CmdletBinding()]
    Param
    (
        [string]$ZipPath,
        [string]$DestinationPath
    )

    try
    {
        if (-not (Test-Path $ZipPath))
        {
            LogError "$ZipPath does not exist."
            return
        }

        if (-not (Test-Path $DestinationPath))
        {
            New-Item -Type Directory $DestinationPath
        }

        $zipFullPath = [System.IO.Path]::GetFullPath($ZipPath)

        #Checking whether the target directory already contains extracted version of zip file, and if so, deleting it.
        $zipFileName = [System.IO.Path]::GetFileNameWithoutExtension($zipFullPath)
        $targetDirectory = Join-Path $DestinationPath $zipFileName

        if (Test-Path $targetDirectory)
        {
            LogVerbose "Removing Folder $targetDirectory" 
            $removeElasticsearchScriptBlock = { Remove-Item -Recurse $targetDirectory -ErrorAction Stop }
            RetryInvoke $removeElasticsearchScriptBlock -RetryCount 5 -RetryDelay 10 
        }

        LogVerbose "Extracting $zipFullPath to path: $DestinationPath"
        if (Get-Command Expand-Archive -ErrorAction SilentlyContinue)
        {
            Expand-Archive $zipFullPath $DestinationPath -Force
        }
        else 
        {
            LogVerbose 'Unable to find Expand-Archive cmdlet, defaulting to shell extraction.'
            
            LogVerbose  "Unzipping $ZipPath in folder $DestinationPath..."
            [System.Reflection.Assembly]::LoadWithPartialName("System.IO.Compression.FileSystem") | Out-Null
            [System.IO.Compression.ZipFile]::ExtractToDirectory( $zipFullPath , $DestinationPath)       
        }
    }
    catch
    {
        LogError $_.Exception.Message
        exit
    }
}

Export-ModuleMember -Function GetScriptDirectory, GetPhysicalMemoryInGB, IsCurrentUserAdmin, GetBasePath, ConvertToJson, ConvertFromJson, ExtractFiles
# SIG # Begin signature block
# MIIkSgYJKoZIhvcNAQcCoIIkOzCCJDcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCpaH6HyKV2WCyr
# mbBjaCmCM37Yy7/hS22yZ+6M2vtJ+KCCDYEwggX/MIID56ADAgECAhMzAAABA14l
# HJkfox64AAAAAAEDMA0GCSqGSIb3DQEBCwUAMH4xCzAJBgNVBAYTAlVTMRMwEQYD
# VQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMTH01pY3Jvc29mdCBDb2RlIFNpZ25p
# bmcgUENBIDIwMTEwHhcNMTgwNzEyMjAwODQ4WhcNMTkwNzI2MjAwODQ4WjB0MQsw
# CQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9u
# ZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMR4wHAYDVQQDExVNaWNy
# b3NvZnQgQ29ycG9yYXRpb24wggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDRlHY25oarNv5p+UZ8i4hQy5Bwf7BVqSQdfjnnBZ8PrHuXss5zCvvUmyRcFrU5
# 3Rt+M2wR/Dsm85iqXVNrqsPsE7jS789Xf8xly69NLjKxVitONAeJ/mkhvT5E+94S
# nYW/fHaGfXKxdpth5opkTEbOttU6jHeTd2chnLZaBl5HhvU80QnKDT3NsumhUHjR
# hIjiATwi/K+WCMxdmcDt66VamJL1yEBOanOv3uN0etNfRpe84mcod5mswQ4xFo8A
# DwH+S15UD8rEZT8K46NG2/YsAzoZvmgFFpzmfzS/p4eNZTkmyWPU78XdvSX+/Sj0
# NIZ5rCrVXzCRO+QUauuxygQjAgMBAAGjggF+MIIBejAfBgNVHSUEGDAWBgorBgEE
# AYI3TAgBBggrBgEFBQcDAzAdBgNVHQ4EFgQUR77Ay+GmP/1l1jjyA123r3f3QP8w
# UAYDVR0RBEkwR6RFMEMxKTAnBgNVBAsTIE1pY3Jvc29mdCBPcGVyYXRpb25zIFB1
# ZXJ0byBSaWNvMRYwFAYDVQQFEw0yMzAwMTIrNDM3OTY1MB8GA1UdIwQYMBaAFEhu
# ZOVQBdOCqhc3NyK1bajKdQKVMFQGA1UdHwRNMEswSaBHoEWGQ2h0dHA6Ly93d3cu
# bWljcm9zb2Z0LmNvbS9wa2lvcHMvY3JsL01pY0NvZFNpZ1BDQTIwMTFfMjAxMS0w
# Ny0wOC5jcmwwYQYIKwYBBQUHAQEEVTBTMFEGCCsGAQUFBzAChkVodHRwOi8vd3d3
# Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2NlcnRzL01pY0NvZFNpZ1BDQTIwMTFfMjAx
# MS0wNy0wOC5jcnQwDAYDVR0TAQH/BAIwADANBgkqhkiG9w0BAQsFAAOCAgEAn/XJ
# Uw0/DSbsokTYDdGfY5YGSz8eXMUzo6TDbK8fwAG662XsnjMQD6esW9S9kGEX5zHn
# wya0rPUn00iThoj+EjWRZCLRay07qCwVlCnSN5bmNf8MzsgGFhaeJLHiOfluDnjY
# DBu2KWAndjQkm925l3XLATutghIWIoCJFYS7mFAgsBcmhkmvzn1FFUM0ls+BXBgs
# 1JPyZ6vic8g9o838Mh5gHOmwGzD7LLsHLpaEk0UoVFzNlv2g24HYtjDKQ7HzSMCy
# RhxdXnYqWJ/U7vL0+khMtWGLsIxB6aq4nZD0/2pCD7k+6Q7slPyNgLt44yOneFuy
# bR/5WcF9ttE5yXnggxxgCto9sNHtNr9FB+kbNm7lPTsFA6fUpyUSj+Z2oxOzRVpD
# MYLa2ISuubAfdfX2HX1RETcn6LU1hHH3V6qu+olxyZjSnlpkdr6Mw30VapHxFPTy
# 2TUxuNty+rR1yIibar+YRcdmstf/zpKQdeTr5obSyBvbJ8BblW9Jb1hdaSreU0v4
# 6Mp79mwV+QMZDxGFqk+av6pX3WDG9XEg9FGomsrp0es0Rz11+iLsVT9qGTlrEOla
# P470I3gwsvKmOMs1jaqYWSRAuDpnpAdfoP7YO0kT+wzh7Qttg1DO8H8+4NkI6Iwh
# SkHC3uuOW+4Dwx1ubuZUNWZncnwa6lL2IsRyP64wggd6MIIFYqADAgECAgphDpDS
# AAAAAAADMA0GCSqGSIb3DQEBCwUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# V2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0
# IENvcnBvcmF0aW9uMTIwMAYDVQQDEylNaWNyb3NvZnQgUm9vdCBDZXJ0aWZpY2F0
# ZSBBdXRob3JpdHkgMjAxMTAeFw0xMTA3MDgyMDU5MDlaFw0yNjA3MDgyMTA5MDla
# MH4xCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xKDAmBgNVBAMT
# H01pY3Jvc29mdCBDb2RlIFNpZ25pbmcgUENBIDIwMTEwggIiMA0GCSqGSIb3DQEB
# AQUAA4ICDwAwggIKAoICAQCr8PpyEBwurdhuqoIQTTS68rZYIZ9CGypr6VpQqrgG
# OBoESbp/wwwe3TdrxhLYC/A4wpkGsMg51QEUMULTiQ15ZId+lGAkbK+eSZzpaF7S
# 35tTsgosw6/ZqSuuegmv15ZZymAaBelmdugyUiYSL+erCFDPs0S3XdjELgN1q2jz
# y23zOlyhFvRGuuA4ZKxuZDV4pqBjDy3TQJP4494HDdVceaVJKecNvqATd76UPe/7
# 4ytaEB9NViiienLgEjq3SV7Y7e1DkYPZe7J7hhvZPrGMXeiJT4Qa8qEvWeSQOy2u
# M1jFtz7+MtOzAz2xsq+SOH7SnYAs9U5WkSE1JcM5bmR/U7qcD60ZI4TL9LoDho33
# X/DQUr+MlIe8wCF0JV8YKLbMJyg4JZg5SjbPfLGSrhwjp6lm7GEfauEoSZ1fiOIl
# XdMhSz5SxLVXPyQD8NF6Wy/VI+NwXQ9RRnez+ADhvKwCgl/bwBWzvRvUVUvnOaEP
# 6SNJvBi4RHxF5MHDcnrgcuck379GmcXvwhxX24ON7E1JMKerjt/sW5+v/N2wZuLB
# l4F77dbtS+dJKacTKKanfWeA5opieF+yL4TXV5xcv3coKPHtbcMojyyPQDdPweGF
# RInECUzF1KVDL3SV9274eCBYLBNdYJWaPk8zhNqwiBfenk70lrC8RqBsmNLg1oiM
# CwIDAQABo4IB7TCCAekwEAYJKwYBBAGCNxUBBAMCAQAwHQYDVR0OBBYEFEhuZOVQ
# BdOCqhc3NyK1bajKdQKVMBkGCSsGAQQBgjcUAgQMHgoAUwB1AGIAQwBBMAsGA1Ud
# DwQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MB8GA1UdIwQYMBaAFHItOgIxkEO5FAVO
# 4eqnxzHRI4k0MFoGA1UdHwRTMFEwT6BNoEuGSWh0dHA6Ly9jcmwubWljcm9zb2Z0
# LmNvbS9wa2kvY3JsL3Byb2R1Y3RzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcmwwXgYIKwYBBQUHAQEEUjBQME4GCCsGAQUFBzAChkJodHRwOi8vd3d3Lm1p
# Y3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY1Jvb0NlckF1dDIwMTFfMjAxMV8wM18y
# Mi5jcnQwgZ8GA1UdIASBlzCBlDCBkQYJKwYBBAGCNy4DMIGDMD8GCCsGAQUFBwIB
# FjNodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpb3BzL2RvY3MvcHJpbWFyeWNw
# cy5odG0wQAYIKwYBBQUHAgIwNB4yIB0ATABlAGcAYQBsAF8AcABvAGwAaQBjAHkA
# XwBzAHQAYQB0AGUAbQBlAG4AdAAuIB0wDQYJKoZIhvcNAQELBQADggIBAGfyhqWY
# 4FR5Gi7T2HRnIpsLlhHhY5KZQpZ90nkMkMFlXy4sPvjDctFtg/6+P+gKyju/R6mj
# 82nbY78iNaWXXWWEkH2LRlBV2AySfNIaSxzzPEKLUtCw/WvjPgcuKZvmPRul1LUd
# d5Q54ulkyUQ9eHoj8xN9ppB0g430yyYCRirCihC7pKkFDJvtaPpoLpWgKj8qa1hJ
# Yx8JaW5amJbkg/TAj/NGK978O9C9Ne9uJa7lryft0N3zDq+ZKJeYTQ49C/IIidYf
# wzIY4vDFLc5bnrRJOQrGCsLGra7lstnbFYhRRVg4MnEnGn+x9Cf43iw6IGmYslmJ
# aG5vp7d0w0AFBqYBKig+gj8TTWYLwLNN9eGPfxxvFX1Fp3blQCplo8NdUmKGwx1j
# NpeG39rz+PIWoZon4c2ll9DuXWNB41sHnIc+BncG0QaxdR8UvmFhtfDcxhsEvt9B
# xw4o7t5lL+yX9qFcltgA1qFGvVnzl6UJS0gQmYAf0AApxbGbpT9Fdx41xtKiop96
# eiL6SJUfq/tHI4D1nvi/a7dLl+LrdXga7Oo3mXkYS//WsyNodeav+vyL6wuA6mk7
# r/ww7QRMjt/fdW1jkT3RnVZOT7+AVyKheBEyIXrvQQqxP/uozKRdwaGIm1dxVk5I
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIWHzCCFhsCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAQNeJRyZH6MeuAAAAAABAzAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgKc3SR753
# n0qxir1zHrupBL40gWjoIPR/+F569izlbzkwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQA6k4Fb0B7kHscbYLN1MyQDzgUbjc1J/QHOcvnqhLWJ
# xNNQ0rnhsa3SmM4m/GIYs908tEdlsDZ4u6pjr0W10WvGMAnSUw6YhFnGbrIWNufM
# D9/NUQAEaO9E1l57+B6QYX+t5iI6FHcwSx7cBppcXHwXIs58HyGd4kuDMI+r8E91
# ACQ92Kh3E7ZCDricH114/va49ES56dsqanIgZnnSGQvrM0MPLyhQN8Y3WsiG5g9C
# tunjEzJRJDu6KNTXSB5nKe0NLsamdSv21d8B/zqVZf45hO7nxLrcfTg3GvfLnNzd
# KzeOD3x74D6wLZOjfCrCmPd/1k6eYMibnMaTpJ6ZS7zroYITqTCCE6UGCisGAQQB
# gjcDAwExghOVMIITkQYJKoZIhvcNAQcCoIITgjCCE34CAQMxDzANBglghkgBZQME
# AgEFADCCAVQGCyqGSIb3DQEJEAEEoIIBQwSCAT8wggE7AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEILQY/sT+rnwNobExIPuF1Ul8zu0hmXy4ZFQn8gtU
# kZf9AgZbzfQA8T0YEzIwMTgxMDI0MjMzNDE1LjUwM1owBwIBAYACAfSggdCkgc0w
# gcoxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsT
# HE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBU
# U1MgRVNOOkQyMzYtMzdEQS05NzYxMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
# dGFtcCBTZXJ2aWNloIIPFTCCBnEwggRZoAMCAQICCmEJgSoAAAAAAAIwDQYJKoZI
# hvcNAQELBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAw
# DgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24x
# MjAwBgNVBAMTKU1pY3Jvc29mdCBSb290IENlcnRpZmljYXRlIEF1dGhvcml0eSAy
# MDEwMB4XDTEwMDcwMTIxMzY1NVoXDTI1MDcwMTIxNDY1NVowfDELMAkGA1UEBhMC
# VVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNV
# BAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRp
# bWUtU3RhbXAgUENBIDIwMTAwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCpHQ28dxGKOiDs/BOX9fp/aZRrdFQQ1aUKAIKF++18aEssX8XD5WHCdrc+Zitb
# 8BVTJwQxH0EbGpUdzgkTjnxhMFmxMEQP8WCIhFRDDNdNuDgIs0Ldk6zWczBXJoKj
# RQ3Q6vVHgc2/JGAyWGBG8lhHhjKEHnRhZ5FfgVSxz5NMksHEpl3RYRNuKMYa+YaA
# u99h/EbBJx0kZxJyGiGKr0tkiVBisV39dx898Fd1rL2KQk1AUdEPnAY+Z3/1ZsAD
# lkR+79BL/W7lmsqxqPJ6Kgox8NpOBpG2iAg16HgcsOmZzTznL0S6p/TcZL2kAcEg
# CZN4zfy8wMlEXV4WnAEFTyJNAgMBAAGjggHmMIIB4jAQBgkrBgEEAYI3FQEEAwIB
# ADAdBgNVHQ4EFgQU1WM6XIoxkPNDe3xGG8UzaFqFbVUwGQYJKwYBBAGCNxQCBAwe
# CgBTAHUAYgBDAEEwCwYDVR0PBAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wHwYDVR0j
# BBgwFoAU1fZWy4/oolxiaNE9lJBb186aGMQwVgYDVR0fBE8wTTBLoEmgR4ZFaHR0
# cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9jcmwvcHJvZHVjdHMvTWljUm9vQ2Vy
# QXV0XzIwMTAtMDYtMjMuY3JsMFoGCCsGAQUFBwEBBE4wTDBKBggrBgEFBQcwAoY+
# aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9jZXJ0cy9NaWNSb29DZXJBdXRf
# MjAxMC0wNi0yMy5jcnQwgaAGA1UdIAEB/wSBlTCBkjCBjwYJKwYBBAGCNy4DMIGB
# MD0GCCsGAQUFBwIBFjFodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vUEtJL2RvY3Mv
# Q1BTL2RlZmF1bHQuaHRtMEAGCCsGAQUFBwICMDQeMiAdAEwAZQBnAGEAbABfAFAA
# bwBsAGkAYwB5AF8AUwB0AGEAdABlAG0AZQBuAHQALiAdMA0GCSqGSIb3DQEBCwUA
# A4ICAQAH5ohRDeLG4Jg/gXEDPZ2joSFvs+umzPUxvs8F4qn++ldtGTCzwsVmyWrf
# 9efweL3HqJ4l4/m87WtUVwgrUYJEEvu5U4zM9GASinbMQEBBm9xcF/9c+V4XNZgk
# Vkt070IQyK+/f8Z/8jd9Wj8c8pl5SpFSAK84Dxf1L3mBZdmptWvkx872ynoAb0sw
# RCQiPM/tA6WWj1kpvLb9BOFwnzJKJ/1Vry/+tuWOM7tiX5rbV0Dp8c6ZZpCM/2pi
# f93FSguRJuI57BlKcWOdeyFtw5yjojz6f32WapB4pm3S4Zz5Hfw42JT0xqUKloak
# vZ4argRCg7i1gJsiOCC1JeVk7Pf0v35jWSUPei45V3aicaoGig+JFrphpxHLmtgO
# R5qAxdDNp9DvfYPw4TtxCd9ddJgiCGHasFAeb73x4QDf5zEHpJM692VHeOj4qEir
# 995yfmFrb3epgcunCaw5u+zGy9iCtHLNHfS4hQEegPsbiSpUObJb2sgNVZl6h3M7
# COaYLeqN4DMuEin1wC9UJyH3yKxO2ii4sanblrKnQqLJzxlBTeCG+SqaoxFmMNO7
# dDJL32N79ZmKLxvHIa9Zta7cRDyXUHHXodLFVeNp3lfB0d4wwP3M5k37Db9dT+md
# Hhk4L7zPWAUu7w2gUDXa7wknHNWzfjUeCLraNtvTX4/edIhJEjCCBPEwggPZoAMC
# AQICEzMAAADJStZ+mE4U1HsAAAAAAMkwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMTgwODIzMjAyNjEzWhcNMTkxMTIzMjAy
# NjEzWjCByjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMG
# A1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046RDIzNi0zN0RBLTk3NjExJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDWI2qENlBDwVDU0uFD6S9dT2hDv1BTS7qIFwUSIRATD9GbnVx0dPD0MlpWcGUq
# 3YIHAeP4BKacxFAmccgDlKWS0qo++a8QlYkgAbdJXroTgB3l/DBw7+hqGyS+fRjR
# 52Y9km8l2RMmCvvsNaBCiSlb9hdm5qbi0sl9EomD9+rq1LT8EHZt667WdmhmvWpU
# yv05fqRIig1XFdnSm1U9wiZUr5QYc46dteCBwc8CV+2AAhSHV5UL7iPaQlGhi63v
# em/JNShVb3jFgMdeh5H2Lfl7wkKVhl+rZER8JrqW1uen+FzmnpbwoCeS51KRl0/D
# rJ711PBAuaPc6dbC44HY55gZAgMBAAGjggEbMIIBFzAdBgNVHQ4EFgQUK4bjCQDz
# JRPHNW9lcLh+IA6aeycwHwYDVR0jBBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUw
# VgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9j
# cmwvcHJvZHVjdHMvTWljVGltU3RhUENBXzIwMTAtMDctMDEuY3JsMFoGCCsGAQUF
# BwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aS9jZXJ0cy9NaWNUaW1TdGFQQ0FfMjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIw
# ADATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0BAQsFAAOCAQEAA9bwE59X
# 8uQdpR6ynaYyuZpgs+IrUAk3QiQv26VvLxJuI3Z1vNfB9PLEMLdhjJ2CMat0/7rK
# y6w1u7mmK8depfQ8l3hIrONZnxLBKVaQo6qmk9LIceIZnQ+SUYBgphty2vx6pSrY
# KFfnercD4AVedjYLqUiubyh+p4ujOa1aYcmG2kkdWvw8QJ+UshNk6UoNV4JcgQVT
# 7kHoAMu3SP9Wiz2eJvdoUto/B2xDM45SA6Wj1YMZeF5cX3OXLEeApK+rotwd+Xwz
# a5cgMvLkoZsJBb3rvoPP7nOoRtlGcve4wHXBT6qH21shQ4Y44kkjFBoNfxJFAaTP
# 2NfIr7gwdlFvbKGCA6cwggKPAgEBMIH6oYHQpIHNMIHKMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjpEMjM2LTM3REEt
# OTc2MTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIlCgEB
# MAkGBSsOAwIaBQADFQBkguCqF2x4isPdPUrBkq8v6DxIF6CB2jCB16SB1DCB0TEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMebkNpcGhlciBOVFMg
# RVNOOjI2NjUtNEMzRi1DNURFMSswKQYDVQQDEyJNaWNyb3NvZnQgVGltZSBTb3Vy
# Y2UgTWFzdGVyIENsb2NrMA0GCSqGSIb3DQEBBQUAAgUA33q8HTAiGA8yMDE4MTAy
# NDA5MzgzN1oYDzIwMTgxMDI1MDkzODM3WjB2MDwGCisGAQQBhFkKBAExLjAsMAoC
# BQDferwdAgEAMAkCAQACASsCAf8wBwIBAAICGRQwCgIFAN98DZ0CAQAwNgYKKwYB
# BAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAaAKMAgCAQACAxbjYKEKMAgCAQACAx6E
# gDANBgkqhkiG9w0BAQUFAAOCAQEADaBx1cyTW0daZFkyt1/UWLLpFsj69PU2IA1k
# jim4WQ7/dcXA8XUIvthDFxNkGEPJJoy0ileRS3/9yIcRwzWu+yO1gp/bh+2vYdkR
# SSMR/PItPu3LLbvLYpxvdTdU5sNkHlb7cDantn6Hs+EroJjqu5cRH5z/Er0o524Z
# aasI35XdpCOmEB33SUmfFaXxYHm3zjzmK7NS4C4mRcLvPEdu+/c2eM4zvtLGd4oj
# QYtjpA4S5Z67xQHoK2slr3zh388/JjxhENM/kjuOBjwxivM/o/lI2K1PeivsZGpV
# t/U8Ht1zLcns8plO5AsT/D3o2ySXSvrV1Vin4wszCIGOR93CJDGCAvUwggLxAgEB
# MIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNV
# BAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAAyUrWfphOFNR7
# AAAAAADJMA0GCWCGSAFlAwQCAQUAoIIBMjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcN
# AQkQAQQwLwYJKoZIhvcNAQkEMSIEIOR3lg/1A4rspXw4eX5+Hpd5yDRKV6mxa8yO
# gUNMsrGcMIHiBgsqhkiG9w0BCRACDDGB0jCBzzCBzDCBsQQUZILgqhdseIrD3T1K
# wZKvL+g8SBcwgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAIT
# MwAAAMlK1n6YThTUewAAAAAAyTAWBBSFhxHcw1OJOTCMvCs4oOAosWAF8TANBgkq
# hkiG9w0BAQsFAASCAQDJihmM3kZUWyv9ST0gyLBs2SGwLlcqp4v4bWIeHB60Hf5O
# DTOMP8XGQ7fwdXIY5ES6Iq6K9koYhbhk1R+2622iQGSXqEL4ce7Z7l71mwaGYs9f
# ixJwrsxjUMaJC5RB2gD9i07eAYW+4/BTW4FWCZoXUVtvGLJoJ8/RzQgrehNfHKTA
# kuJN/9BuT156uSyGD5ulN/QzOCjatjoHdEjMQLUXyyTSN4kl04dmrTxIS9931VAp
# smNfsLXFfXl9y4uZalx3Mf9byKHdAjojPCRwLpFgcYVLg8mJ3+U2H1dxK/78UiLE
# 92JRHheX3UxD2oaKVO3V64c+QXHTF8X6KQgWd4Nv
# SIG # End signature block
