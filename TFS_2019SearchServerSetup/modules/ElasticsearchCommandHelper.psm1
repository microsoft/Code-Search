Import-Module $PSScriptRoot\Helper.psm1
Import-Module $PSScriptRoot\Logger.psm1
Import-Module $PSScriptRoot\FunctionHelper.psm1
Import-Module $PSScriptRoot\Constants.psm1 -Force
Import-Module $PSScriptRoot\WindowsServiceHelper.psm1

function UpdateElasticsearchIndexSettings
{
    <#
        .DESCRIPTION
        Updates the elasticsearch index settings

        .PARAMETER elasticsearchUrl
        path of the service.bat file used to start the elasticsearch        
    #>
    [CmdletBinding()]
    [OutputType([boolean])]
    Param
    (
        $elasticsearchUrl
    )
    
    $indexSettings = '{
    "template": "*",
    "settings": {
        "number_of_replicas": 0,
        "index.mapper.dynamic": false
        }
    }'

    $indexSettingsUrl = $elasticsearchUrl + "/_template/templates_all"
    LogVerbose 'Updating elasticsearch index settings'

    $responseContent = Invoke-ElasticsearchCommand -RequestMethod "PUT" -RequestUri $indexSettingsUrl -RequestBody $indexSettings
    $responseJson = ConvertFrom-Json $responseContent    
    LogVerbose "Updated elasticsearch index settings"
    
    return $responseJson.acknowledged    
}

function GetElasticsearchVersion
{
    <#
        .DESCRIPTION
        Gets the elasticsearch version

        .PARAMETER elasticsearchUrl
        path of the service.bat file used to start the elasticsearch
        
        .PARAMETER user
        user
        
        .PARAMETER password
        password      
    #>
    [CmdletBinding()]
    [OutputType([boolean])]
    Param
    (
        [string] $elasticsearchUrl,
        [string] $user,
        [string] $password
    )
    
    try
    {
        $indexSettingsUrl = $elasticsearchUrl + "/?filter_path=version.number&pretty=false"
        LogVerbose 'Getting elasticsearch version'

        $responseContent = Invoke-ElasticsearchCommand -RequestMethod "GET" -RequestUri "$($indexSettingsUrl)" -User "$($user)" -Password "$($password)"
    
        $responseJson = ConvertFrom-Json $responseContent    
        LogVerbose "Fetched elasticsearch index version"
    
        return $responseJson.version.number
    }
    catch
    {
        return $null
    }
}

function GetElasticsearchPluginVersion
{
    <#
        .DESCRIPTION
        Gets the elasticsearch plugin version

        .PARAMETER elasticsearchUrl
        path of the service.bat file used to start the elasticsearch
        
        .PARAMETER user
        user
        
        .PARAMETER password
        password              
    #>
    [CmdletBinding()]
    [OutputType([boolean])]
    Param
    (
        [string] $elasticsearchUrl,
        [string] $pluginName,
        [string] $user,
        [string] $password
    )

    try
    {
        $uri = $elasticsearchUrl + "/_cat/plugins?h=component,version"

        $responseContent = Invoke-ElasticsearchCommand -RequestMethod "GET" -RequestUri "$($uri)" -User "$($user)" -Password "$($password)"
        $lines = $responseContent.Split("`n`r")

        foreach($line in $lines)
        {
            $plugin, $version = $line.Split(" ", [System.StringSplitOptions]::RemoveEmptyEntries)
            if ($pluginName -eq $plugin )
            {
                return [version]$version
            }
        }
    }
    catch
    {
        return $null
    }
}

function Invoke-ElasticsearchCommand
{
    [CmdletBinding(SupportsShouldProcess=$True)]
    Param 
    (
        [Parameter(Mandatory=$True)]
        [ValidateSet("GET", "POST", "PUT", "DELETE")]
        [string]
        $RequestMethod,

        [Parameter(Mandatory=$True)]
        [string]
        $RequestUri,

        [Parameter(Mandatory=$False)]
        [string]
        $User,

        [Parameter(Mandatory=$False)]
        [string]
        $Password,

        [Parameter(Mandatory=$False)]
        [string]
        $RequestBody,

        [Parameter(Mandatory=$False)]
        [ValidateRange(10, 1800)]
        [int]
        $TimeoutSec = 300
    )
    
    LogVerbose "Request = $($RequestMethod) [$RequestUri]"

    $success = $False
    $retryCount = $ElasticsearchServiceRetryConstants.RetryCount
    
    Do
    {        
        try
        {
            $headers = GetAuthorizationHeader -User "$($user)" -Password "$($password)"

            if ($RequestMethod -eq "GET")
            {
                $response = Invoke-WebRequest -Uri $RequestUri -Method $RequestMethod -Headers $headers -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop            
            }
            else
            {
                $response = Invoke-WebRequest -Uri $RequestUri -Method $RequestMethod -Headers $headers -Body $requestBody -TimeoutSec $TimeoutSec -UseBasicParsing -ErrorAction Stop            
            }

            Write-Host "Response = [$($response.Content)]" 
            $success = $True           
            return $response.Content
        }
        catch
        {
            $errorMsg = $_ | Out-String
            LogWarning $errorMsg -TextColor Yellow
            $retryCount = $retryCount - 1
            Start-Sleep -s 5
        }
    } while(-not ($success) -and $retryCount -gt 0)

    if (-not ($success))
    {
        LogError 'Elasticsearch web request failed'
        throw [Net.WebException]
    }
}

function GetAuthorizationHeader
{
    Param
    (        
        [string] $user,
        [string] $password
    )
    $headers = @{}
    
    if (-not([string]::IsNullOrEmpty($user)) -and (-not([string]::IsNullOrEmpty($password))))
    {
        $authCredentials = "$($user)" +":" + "$($password)"
        $authCredentialsBytes = [System.Text.Encoding]::UTF8.GetBytes($authCredentials)
        $encodedCredentials =  [System.Convert]::ToBase64String($authCredentialsBytes);

        $headers.Add("Authorization", "basic "+"$($encodedCredentials)");
    }
    
    return $headers   
}


Export-ModuleMember -Function Invoke-ElasticsearchCommand, GetElasticsearchVersion, GetElasticsearchPluginVersion
# SIG # Begin signature block
# MIIkSwYJKoZIhvcNAQcCoIIkPDCCJDgCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDTSw0Y3cizfZiB
# 9tJRTmwae5bt91oxRK8rxR3yvR10RKCCDYEwggX/MIID56ADAgECAhMzAAABA14l
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
# RcBCyZt2WwqASGv9eZ/BvW1taslScxMNelDNMYIWIDCCFhwCAQEwgZUwfjELMAkG
# A1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQx
# HjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEoMCYGA1UEAxMfTWljcm9z
# b2Z0IENvZGUgU2lnbmluZyBQQ0EgMjAxMQITMwAAAQNeJRyZH6MeuAAAAAABAzAN
# BglghkgBZQMEAgEFAKCBrjAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIBBDAcBgor
# BgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQgUjZQaBID
# KBYLuRKtJmaXdTs0dgac5YMwlEwTa9VH5I4wQgYKKwYBBAGCNwIBDDE0MDKgFIAS
# AE0AaQBjAHIAbwBzAG8AZgB0oRqAGGh0dHA6Ly93d3cubWljcm9zb2Z0LmNvbTAN
# BgkqhkiG9w0BAQEFAASCAQBgQWmbofIdxTj2AD4VwN0lopWVLmaMK/mqX3HZT/dc
# 66KG5geEfHcr+BupFvYKoyR1dO+RghrBu8Jw/IruKIm0LA6NB6MmH+8LeQDJGHHY
# cOcNCk7f3avUG07IqSk7RQ2GXhiOwZ/CGA8b9Zj9Ph85En18UX+M89aLhUiRLPA2
# bmT0GtOzEtOLJlkFlGeTUH7lHrY8pcEKtuQt7wlHCxZCq5OwpU0p1hskSRF1Okgp
# ssct9DHZ57xa5kmohPNK/C8eXS5Oi14zUeg1RmMM3fP5N9SSSjR4wwU6RE4mGMHm
# 3jol1xnQ4GOmjbUkpUXSrTGTvBhrGVU/exjeTqhYfURjoYITqjCCE6YGCisGAQQB
# gjcDAwExghOWMIITkgYJKoZIhvcNAQcCoIITgzCCE38CAQMxDzANBglghkgBZQME
# AgEFADCCAVQGCyqGSIb3DQEJEAEEoIIBQwSCAT8wggE7AgEBBgorBgEEAYRZCgMB
# MDEwDQYJYIZIAWUDBAIBBQAEILkK4tvf8E9XmpIeQj6FHwV0QRo56V85qmWew0UK
# 5K/sAgZbzfPI3YoYEzIwMTgxMDI0MjMzNDE3LjQzNlowBwIBAYACAfSggdCkgc0w
# gcoxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdS
# ZWRtb25kMR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xJTAjBgNVBAsT
# HE1pY3Jvc29mdCBBbWVyaWNhIE9wZXJhdGlvbnMxJjAkBgNVBAsTHVRoYWxlcyBU
# U1MgRVNOOjIxMzctMzdBMC00QUFBMSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1T
# dGFtcCBTZXJ2aWNloIIPFjCCBnEwggRZoAMCAQICCmEJgSoAAAAAAAIwDQYJKoZI
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
# AQICEzMAAADKCsYkwjkTpv8AAAAAAMowDQYJKoZIhvcNAQELBQAwfDELMAkGA1UE
# BhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAc
# BgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0
# IFRpbWUtU3RhbXAgUENBIDIwMTAwHhcNMTgwODIzMjAyNjE5WhcNMTkxMTIzMjAy
# NjE5WjCByjELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNV
# BAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMG
# A1UECxMcTWljcm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEmMCQGA1UECxMdVGhh
# bGVzIFRTUyBFU046MjEzNy0zN0EwLTRBQUExJTAjBgNVBAMTHE1pY3Jvc29mdCBU
# aW1lLVN0YW1wIFNlcnZpY2UwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIB
# AQCSuAkY8/XpD+g5nTH4DeAiYqAHeZBta9YN63SN+rgmOUi6DyLeAaiWRDoWuyyx
# /UmH1Mk70pRsmvertXmYSZNp7f8RgQGWwD1BHaONJVAVK5l23f4Q6o1Kyr6IfxdM
# lV38ECTjRUwTIlTkb5AILv0VlDZhMG19GDlJicAQDjYrnYF6BZkGGyhHYtIWERyg
# Z0ZmmhRKyWoTJhrMBAfYbmKR27ATFChOP1COebz98u1kqg1JDxlCqUSq8No9UHkB
# 5RC/fyLNH+71RJaO8JgTuXYFmiSXDp2Oz5FaVBI+ebDMrAR82X9YleaqP8iwbGym
# QPf577TCC6WLPsHgFAYTbN8VAgMBAAGjggEbMIIBFzAdBgNVHQ4EFgQUKOkNoaSp
# cMadIyV2e/vNkvWwsvQwHwYDVR0jBBgwFoAU1WM6XIoxkPNDe3xGG8UzaFqFbVUw
# VgYDVR0fBE8wTTBLoEmgR4ZFaHR0cDovL2NybC5taWNyb3NvZnQuY29tL3BraS9j
# cmwvcHJvZHVjdHMvTWljVGltU3RhUENBXzIwMTAtMDctMDEuY3JsMFoGCCsGAQUF
# BwEBBE4wTDBKBggrBgEFBQcwAoY+aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3Br
# aS9jZXJ0cy9NaWNUaW1TdGFQQ0FfMjAxMC0wNy0wMS5jcnQwDAYDVR0TAQH/BAIw
# ADATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0BAQsFAAOCAQEARf15Dk/7
# pDRCruTFsMV02+rA4RQDtNLJTYmPTkr/n2wS+ygOywjz6a8Zq8aK+H5YgigwMYBG
# JOp+w/XhTYvhvBa1xAmtAbbYUZEzs9mvtF57d6k4/MQ7sO8xYXFA2NFT0xkI06/W
# DEvP8gCu60DE/gmRRC9bidasRPE7Fa988/4W+5d8r8QvgRQ20NAuj5bjchHNtqiB
# t9QoL2mgKxTWuhKTdfft8SsB1tP010FiAUKDUMqyXACCkMxXWi1fJGAb/nRosKoY
# AqqRRd7A0A3dksnbTjacn8BKc2CABZicSfLy+qcoKHzoIPuGJay5sFOteb3ChHJn
# +pIhZ0lmpRzshqGCA6gwggKQAgEBMIH6oYHQpIHNMIHKMQswCQYDVQQGEwJVUzET
# MBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMV
# TWljcm9zb2Z0IENvcnBvcmF0aW9uMSUwIwYDVQQLExxNaWNyb3NvZnQgQW1lcmlj
# YSBPcGVyYXRpb25zMSYwJAYDVQQLEx1UaGFsZXMgVFNTIEVTTjoyMTM3LTM3QTAt
# NEFBQTElMCMGA1UEAxMcTWljcm9zb2Z0IFRpbWUtU3RhbXAgU2VydmljZaIlCgEB
# MAkGBSsOAwIaBQADFQBbDTPvmGoKSV8bhE4v5n1EbgzsrqCB2jCB16SB1DCB0TEL
# MAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1v
# bmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjElMCMGA1UECxMcTWlj
# cm9zb2Z0IEFtZXJpY2EgT3BlcmF0aW9uczEnMCUGA1UECxMebkNpcGhlciBOVFMg
# RVNOOjI2NjUtNEMzRi1DNURFMSswKQYDVQQDEyJNaWNyb3NvZnQgVGltZSBTb3Vy
# Y2UgTWFzdGVyIENsb2NrMA0GCSqGSIb3DQEBBQUAAgUA33tfxDAiGA8yMDE4MTAy
# NDIxMTY1MloYDzIwMTgxMDI1MjExNjUyWjB3MD0GCisGAQQBhFkKBAExLzAtMAoC
# BQDfe1/EAgEAMAoCAQACAgxjAgH/MAcCAQACAhj3MAoCBQDffLFEAgEAMDYGCisG
# AQQBhFkKBAIxKDAmMAwGCisGAQQBhFkKAwGgCjAIAgEAAgMW42ChCjAIAgEAAgMe
# hIAwDQYJKoZIhvcNAQEFBQADggEBAJlXCqKJ28kzpxj5J2N+DIkSf3DxIgUPRTe3
# kQzyFnBPifH+Ic5UyWYThKLLpFTiTIyLonWgDQaR/dzJ1nmTPJj8njJY5fl0kf73
# AgwevXCTl4p9nBk/0etHAaKdLZTE1Ep9EYkGjwKli07ueyG1bUKxlP/dQTnK2YFt
# JXcHLsK+UTaJCiqMVUVf4296KC6u2WtgwuZKYn2pBXfWqZ4uP/6YEGWbUG79UO18
# F0EZZvWir42VzaQ2VN8u0QioICxm6CIoVpBRqBwp8dqPV94rxbJJ+oH0fuKFRXev
# gw+entVciw+qhuqaSSW43iMAAg+GFqvWzuqC/Kz7LECuZV8w5IkxggL1MIIC8QIB
# ATCBkzB8MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4GA1UE
# BxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSYwJAYD
# VQQDEx1NaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EgMjAxMAITMwAAAMoKxiTCOROm
# /wAAAAAAyjANBglghkgBZQMEAgEFAKCCATIwGgYJKoZIhvcNAQkDMQ0GCyqGSIb3
# DQEJEAEEMC8GCSqGSIb3DQEJBDEiBCBEywAjooYHETwUElMUd/jA8m56vp50FEKO
# 6i2ULERaHzCB4gYLKoZIhvcNAQkQAgwxgdIwgc8wgcwwgbEEFFsNM++YagpJXxuE
# Ti/mfURuDOyuMIGYMIGApH4wfDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjEmMCQGA1UEAxMdTWljcm9zb2Z0IFRpbWUtU3RhbXAgUENBIDIwMTAC
# EzMAAADKCsYkwjkTpv8AAAAAAMowFgQU8GhUbnYmR9/IpJpeNdUFjXXkMi0wDQYJ
# KoZIhvcNAQELBQAEggEAD2HfMPDOtrueWrOERRzJfvTyxGUJCXvShZ3Gil54SRDk
# BeFaCHBYUE6yH19cVkuoJrn/p8FvhIC5ZfFvnhQdv4M9BPz39umhRE5arhRdAPtz
# mkU1QIBez4In5Hf21s5zfSWFUbxxdIGQGXgEwKzE2HzFtI6OIW3Dw4gnsYlB9Qa/
# olBQ79RRboP0CPTzFENvJjsfj1+Wm5wqkArNnXACKuqOEZDAv38DyJbVh2wzoptz
# YitiFbptEDJhe2AwbBpreKkxUEJasSRwO2bWayEkSHVAgUQcKjugLjlFTSUpuBuG
# T0x3SLhXd7YQFSosoohZdEC/1WGbnAYxAXClFmLFDA==
# SIG # End signature block
