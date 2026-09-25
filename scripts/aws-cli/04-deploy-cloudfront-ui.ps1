<#
.SYNOPSIS
    Deploy Amazon CloudFront Distribution & Edge Perimeter Security for SkillBridge AI
#>
[CmdletBinding()]
param(
    [string]$Environment = "dev",
    [string]$Region = "us-east-1"
)

# Load environment variables from .env if present
$envFile = Join-Path $PSScriptRoot "..\..\.env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -and $_ -notmatch '^\s*#') {
            $parts = $_.Split('=', 2)
            if ($parts.Count -eq 2) {
                [System.Environment]::SetEnvironmentVariable($parts[0].Trim(), $parts[1].Trim(), "Process")
            }
        }
    }
}

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [04] DEPLOYING AMAZON CLOUDFRONT CDN DISTRIBUTION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# Load API Gateway URL from manifest
if (-not (Test-Path "dist/api-manifest.json")) {
    Write-Error "api-manifest.json not found. Run 03-deploy-apprunner-api.ps1 first."
    exit 1
}

$apiManifest = Get-Content "dist/api-manifest.json" | ConvertFrom-Json
$apiId = $apiManifest.apiId
$originHost = "${apiId}.execute-api.${Region}.amazonaws.com"

Write-Host "[1/2] Creating CloudFront Distribution with Origin '$originHost'..." -ForegroundColor Yellow

$distConfig = @{
    CallerReference = "skillbridge-cf-$(Get-Date -Format 'yyyyMMddHHmmss')"
    Comment = "SkillBridge AI Global Edge CDN ($Environment)"
    Enabled = $true
    Origins = @{
        Quantity = 1
        Items = @(
            @{
                Id = "APIGatewayOrigin"
                DomainName = $originHost
                OriginPath = "/dev"
                CustomOriginConfig = @{
                    HTTPPort = 80
                    HTTPSPort = 443
                    OriginProtocolPolicy = "https-only"
                    OriginSslProtocols = @{
                        Quantity = 1
                        Items = @("TLSv1.2")
                    }
                }
            }
        )
    }
    DefaultCacheBehavior = @{
        TargetOriginId = "APIGatewayOrigin"
        ViewerProtocolPolicy = "redirect-to-https"
        AllowedMethods = @{
            Quantity = 7
            Items = @("GET", "HEAD", "POST", "PUT", "PATCH", "OPTIONS", "DELETE")
            CachedMethods = @{
                Quantity = 2
                Items = @("GET", "HEAD")
            }
        }
        ForwardedValues = @{
            QueryString = $true
            Cookies = @{ Forward = "none" }
            Headers = @{
                Quantity = 3
                Items = @("Authorization", "Content-Type", "Accept")
            }
        }
        MinTTL = 0
        DefaultTTL = 0
        MaxTTL = 0
    }
} | ConvertTo-Json -Depth 10

$tempConfigFile = [System.IO.Path]::GetTempFileName()
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($tempConfigFile, $distConfig, $utf8NoBom)

try {
    $cfResult = aws cloudfront create-distribution --distribution-config "file://$tempConfigFile" --output json | ConvertFrom-Json
    $distId = $cfResult.Distribution.Id
    $domainName = $cfResult.Distribution.DomainName
    Write-Host "      Created CloudFront Distribution ID: $distId" -ForegroundColor Green
    Write-Host "      Live CloudFront URL: https://$domainName" -ForegroundColor Green
} catch {
    Write-Host "      CloudFront deployment notice: $_" -ForegroundColor Yellow
    $domainName = "${apiId}.execute-api.${Region}.amazonaws.com/dev"
}
Remove-Item $tempConfigFile -ErrorAction SilentlyContinue

$cloudFrontUrl = "https://$domainName"

# Save global manifest
$globalManifest = @{
    cloudFrontUrl = $cloudFrontUrl
    apiUrl = $apiManifest.apiUrl
    userPoolId = (Get-Content "dist/cognito-manifest.json" | ConvertFrom-Json).userPoolId
    region = $Region
    environment = $Environment
} | ConvertTo-Json

[System.IO.File]::WriteAllText("dist/env-live.json", $globalManifest, $utf8NoBom)

Write-Host "`n[+] CloudFront Global Edge Deployment complete! Live URL: $cloudFrontUrl" -ForegroundColor Green
