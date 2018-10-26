Import-Module $PSScriptRoot\Helper.psm1
Import-Module $PSScriptRoot\Logger.psm1
Import-Module $PSScriptRoot\FunctionHelper.psm1
Import-Module $PSScriptRoot\Constants.psm1 -Force
Import-Module $PSScriptRoot\WindowsServiceHelper.psm1

function InstallElasticsearchPlugin
{
    <#
        .DESCRIPTION
        Installs the elasticsearch plugin

        .PARAMETER pluginBatPath
        path of the elasticsearch-plugin.bat file used to install the elasticsearch plugin        

        .PARAMETER pluginName
        name of the plugin

        .PARAMETER pluginZipPath
        full path of the plugin zip
    #>
    [CmdletBinding()]
    [OutputType([boolean])]
    Param
    (
        [string] $pluginBatPath,
        [string] $pluginName,
        [string] $pluginZipPath
    )
    
    if (-Not (Test-Path -Path $pluginBatPath))
    {
        LogError "Elasticsearch elasticsearch-plugin.bat not found at: $pluginBatPath"
        return $false
    }

    if (-Not (Test-Path -Path $pluginZipPath))
    {
        LogError "Zip of plugin to be installed not found at: $pluginZipPath"
        return $false
    }

    
    $pluginInstallPath = "file:///" + "$($pluginZipPath)"
    LogVerbose "$pluginZipPath" 
    LogVerbose "$pluginInstallPath" 
    LogVerbose "$pluginBatPath"

    $output = & "$($pluginBatPath)" install "$($pluginInstallPath)" 2>&1 | Out-String
    LogVerbose "Elasticsearch output: $output" 
    
    $successCondition = { IsElasticsearchPluginInstalled $pluginBatPath $pluginName }

    $retryCount = $ElasticsearchServiceRetryConstants.RetryCount
    Do
    {
        LogVerbose "Waiting for the elasticsearch plugin: $($pluginName) to be installed ..."
        Start-Sleep -Seconds 5
        $retryCount = $retryCount - 1
    }
    while(-not (& $successCondition) -and $retryCount -gt 0)
    
    if (& $successCondition)
    {
        LogVerbose "Elasticsearch plugin $pluginName has been installed."
    }    
    else
    {
        LogError "Error installing the elasticsearch plugin $pluginName"
        return $false
    }

    return $true
}

function RemoveElasticsearchPlugin
{
    <#
        .DESCRIPTION
        Removes the elasticsearch windows service from the system

        .PARAMETER pluginBatPath
        path of the elasticsearch-plugin.bat file used to remove the elasticsearch plugin

        .PARAMETER pluginName
        name of the plugin

        .PARAMETER pluginInstallPath
        path under elasticsearch install folder where plugins are installed
    #>
    [CmdletBinding()]
    param
    (
        [string] $pluginBatPath,
        [string] $pluginName,
        [string] $pluginInstallPath
    )

    if (-Not (Test-Path -Path $pluginBatPath))
    {
        LogError "File not found: $pluginBatPath"
        return;
    }

    $pluginInstallFullPath = Join-Path $pluginInstallPath $pluginName

    $output = & $pluginBatPath remove $pluginName 2>&1 | Out-String
    LogVerbose "Elasticsearch output: $output"

    $successCondition = { -not (IsElasticsearchPluginInstalled $pluginBatPath $pluginName) }
    $retryCount = $ElasticsearchServiceRetryConstants.RetryCount
    Do
    {
        LogVerbose "Waiting for the elasticsearch plugin: $($pluginName) to be removed ..."
        Start-Sleep -Seconds 5
        $retryCount = $retryCount - 1
        # Try deleting the plugin folder
        Remove-Item -Path $pluginInstallFullPath -Force -Recurse -ErrorAction SilentlyContinue
    }
    while(-not (& $successCondition) -and $retryCount -gt 0)

    if (& $successCondition)
    {
        LogVerbose "Elasticsearch plugin $pluginName has been removed"
        return $true
    }
    else
    {
        LogError "Error removing Elasticsearch plugin $pluginName"
        return $false  
    }

    return $true
}

function IsElasticsearchPluginInstalled
{
    <#
        .DESCRIPTION
        Removes the elasticsearch windows service from the system

        .PARAMETER pluginBatPath
        path of the elasticsearch-plugin.bat file used to remove the elasticsearch plugin

        .PARAMETER pluginName
        name of the plugin
    #>
    [CmdletBinding()]
    param
    (
        [string] $pluginBatPath,
        [string] $pluginName
    )

    if (-Not (Test-Path -Path $pluginBatPath))
    {
        LogError "File not found: $pluginBatPath"
        return;
    }
    $output = & "$($pluginBatPath)" list 2>&1 | Out-String
    LogVerbose "Elasticsearch output: $output"

    if ($output -Match $pluginName )
    {
        return $true
    }
    else
    {
        return $false
    }
}

Export-ModuleMember -Function InstallElasticsearchPlugin, RemoveElasticsearchPlugin
# SIG # Begin signature block
# MIIkSgYJKoZIhvcNAQcCoIIkOzCCJDcCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAiYxUmy45jFxOk
# SZ+PpG/FnarLqN9T4s0YKnuCP+B866CCDYEwggX/MIID56ADAgECAhMzAAABA14l
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
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgS8sxZert
# ijqiRhVePenTLJpH+rkU6uZLD7nmPYeDupgwQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBufsuBzSPBB/c6IcPvpBKjhM+7t3SDdjySNkSLofgX
# UqpFgSi71y0VKvCMklDOFQJtu+MHEMgNi+EUTYL/At1z+vj1TN8xdBpQVN5nt2nZ
# i0cWERuqDa7XECaIImLIFrPzHguyARdHIwk5lFp8WfxR7KO3DIEIlaSAhGS8jaVS
# M6tA4jskEEl2g0nVmP8fQLQnyCUAyF/MlrwH5iVnnqhyAio41n86Q4jsshlBUF72
# rp+jxXVnD3AOb3iL6lqgVNvVZLl3j395UGpJF1tvRSVBCeb9JqxmAQPsQLsmyP4q
# oQ0Sjya2pPQ1Yn/Mof38DqbTqo90vIQmp+6hb6Teg/o2oYITqTCCE6UGCisGAQQB
# gjcDAwExghOVMIITkQYJKoZIhvcNAQcCoIITgjCCE34CAQMxDzANBglghkgBZQME
# AgEFADCCAVQGCyqGSIb3DQEJEAEEoIIBQwSCAT8wggE7AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEIHpTAMcxJvApST4ClzgPfb+JvWC6OUGfh5iLKXtx
# yLbrAgZbzfco44QYEzIwMTgxMDI0MjMzNDE3LjcyNVowBwIBAYACAfSggdCkgc0w
# gcoxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsT
# HE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBU
# U1MgRVNOOjBERTgtMkRDNS0zQ0E5MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
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
# AQICEzMAAADk2h823vdwLdgAAAAAAOQwDQYJKoZIhvcNAQELBQAwfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMTgwODIzMjAyNzA4WhcNMTkxMTIzMjAy
# NzA4WjCByjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMG
# A1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046MERFOC0yREM1LTNDQTkxJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQDDrSTUR4dTS2WA3Xyjddtksp7hJuLH3e61RDZ8VWtG/8UDii5LlEVMX9Fc2S4F
# ORiL+RV9BPttYhuihHfbOXA7Ad2Xtgyyea+tXMCio75DERfxyWO22BZ6yJUErwvD
# u0C5HrTa+Y8D55yIy6kJ/Q0RfvYgLwk/1Pp60ub5O/RBfS6jSY2AA2Umymv6AFZ1
# dw7H+MW4Z8NY2V85EpcbLE8fgYJF1Bx9BQO6tb1NmodsuXcT6qXcmB7bH9s3mz89
# d8mtf9s0+s+QBfoJCuUiCw+oiuHCeeWowLXYDcvQal+D8eRtfTjWxqrzicSpcB58
# 8+CVeH5G28fFoNBixF9/nJKZAgMBAAGjggEbMIIBFzAdBgNVHQ4EFgQU8U1nNiyO
# HTrkVGOLb1pu9w64zngwHwYDVR0jBBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUw
# VgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9j
# cmwvcHJvZHVjdHMvTWljVGltU3RhUENBXzIwMTAtMDctMDEuY3JsMFoGCCsGAQUF
# BwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aS9jZXJ0cy9NaWNUaW1TdGFQQ0FfMjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIw
# ADATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0BAQsFAAOCAQEAFFlqNTfb
# 9At7GMWIHilelhciSLgtwsEY0LRzFcknVBjPJcY0fmyQMg1EQ2ZcYxN/QKte6ua+
# oulln05t4GueuzmSyItIrjgUglm/jGLu6dmkNWmGzt22SlEmvgrTOTs0ZGmS/5he
# bgF6dR0p6bnsI+F4qpNlIz0RnVB/HUNFbT07AVvFsH0zDgwPUS0C+ZvFB+lM3+kH
# FvHW4Uy4/JZWedxdg2B2An5+GM8M4KlWWaKZ2o+d96INFvXdur9VqWd/Zs4ix9Nk
# 2qdGTmc2aa9gv/HH90LCnbt44vivwlg2vaLPfCaA9naicD+cspjtV5XdO2dsnMjA
# 7ATLhAEsuIgbeaGCA6cwggKPAgEBMIH6oYHQpIHNMIHKMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjowREU4LTJEQzUt
# M0NBOTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIlCgEB
# MAkGBSsOAwIaBQADFQC/wA7TpeIhRJeKw0MFfcr2itZKOqCB2jCB16SB1DCB0TEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMebkNpcGhlciBOVFMg
# RVNOOjI2NjUtNEMzRi1DNURFMSswKQYDVQQDEyJNaWNyb3NvZnQgVGltZSBTb3Vy
# Y2UgTWFzdGVyIENsb2NrMA0GCSqGSIb3DQEBBQUAAgUA33q9QTAiGA8yMDE4MTAy
# NDA5NDMyOVoYDzIwMTgxMDI1MDk0MzI5WjB2MDwGCisGAQQBhFkKBAExLjAsMAoC
# BQDfer1BAgEAMAkCAQACASsCAf8wBwIBAAICGMwwCgIFAN98DsECAQAwNgYKKwYB
# BAGEWQoEAjEoMCYwDAYKKwYBBAGEWQoDAaAKMAgCAQACAxbjYKEKMAgCAQACAweh
# IDANBgkqhkiG9w0BAQUFAAOCAQEAaalHAkb6bS6AVqLQ2zP1QSy782xUJ7YacMEM
# zjXSZGnmurwo5f2OmjZjhsuB19IBF20uDCzh65JX8Nv0zi1b7XCaEtpshBsce9B9
# 7HPBy3BZoBZDPETJDuX5oJWudEICTicZFkfhXurBAQJ/m/ZfOQ7c/x0aV6oKq+Ny
# ZxfbsWZiK8UvTtfS8tnXtw8lK6H/D5QlOtEwbeTVoT/8PHu6jMRcSB1MRbhwXtX6
# X+1mnKtnMLZ2ojC0D6UlIge1yjv+qKWunUAN4fVCyFBOZJqo77NKQDok7ODAsNBA
# 6zu9Z5JfBm8CjTlL9axCip/gT5WpsdmnJife1m6VzawODx1PXjGCAvUwggLxAgEB
# MIGTMHwxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQH
# EwdSZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJjAkBgNV
# BAMTHU1pY3Jvc29mdCBUaW1lLVN0YW1wIFBDQSAyMDEwAhMzAAAA5NofNt73cC3Y
# AAAAAADkMA0GCWCGSAFlAwQCAQUAoIIBMjAaBgkqhkiG9w0BCQMxDQYLKoZIhvcN
# AQkQAQQwLwYJKoZIhvcNAQkEMSIEIIunvqnImHkaturYlXFhneRUyCu1KKQnQEhd
# 19iB0QJ2MIHiBgsqhkiG9w0BCRACDDGB0jCBzzCBzDCBsQQUv8AO06XiIUSXisND
# BX3K9orWSjowgZgwgYCkfjB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGlu
# Z3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBv
# cmF0aW9uMSYwJAYDVQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAIT
# MwAAAOTaHzbe93At2AAAAAAA5DAWBBRkYGsZhuFbu+5DvrRM45wckkfpmzANBgkq
# hkiG9w0BAQsFAASCAQAEOHFyD9lgmutnEUo2ytRcCp4o7YIzUFutp08UtZwIbZj+
# 8C3dOYe5nKe0mc6RcukFS1DBEcG8vG9v82PXSK5Z0SAZE4E17+S8zOc0EPtzgHDS
# hxgIqkTkg7rIUKms+BKUd5RbvnK1Ebi4W50AKkRLgR1VrRR4D+Xo/1AYeVAvo7XT
# xfJVLeKz1Z3JfxIA5raw/8A3N5VLEJtCu3DvIlsyT9AYcYZSvunovfbfH2uomw4F
# g9/yjbv8Bj4ZQaRX6KOBS39X5GhdgCoZrg/+zrGQocQQ1CftByMPB5uIqW8KyPCy
# U23X7gTVFp5LtG8uhId118mrrHS14Wx+1FMeXP6N
# SIG # End signature block
