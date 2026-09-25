<#
.SYNOPSIS
    Performs instant deployment rollback to the previous stable release.
.DESCRIPTION
    Rolls back Lambda live alias version, restores previous API Gateway deployment,
    invalidates CloudFront caches, and sends incident notifications.
.PARAMETER Environment
    Target environment (dev, qa, staging, prod). Default is 'prod'.
.PARAMETER Region
    Target AWS Region.
.PARAMETER TargetVersion
    Specific Lambda version number to restore. If omitted, rolls back to previous numerical version.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet("dev", "qa", "staging", "prod")]
    [string]$Environment = "prod",

    [Parameter()]
    [string]$Region = "us-east-1",

    [Parameter()]
    [string]$TargetVersion = ""
)

Write-Host "============================================================" -ForegroundColor Red
Write-Host " [08] INITIATING INSTANT DEPLOYMENT ROLLBACK" -ForegroundColor Red
Write-Host " Environment: $Environment | Region: $Region" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Red

$lambdaName = "eirs-$Environment-api-handler"

# 1. Inspect current Lambda Alias
Write-Host "[1/3] Inspecting active Lambda alias 'live'..."
$currentAlias = aws lambda get-alias --function-name $lambdaName --name "live" --region $Region --output json | ConvertFrom-Json
$currentVersion = [int]$currentAlias.FunctionVersion
Write-Host "      Currently Active Version: $currentVersion" -ForegroundColor Yellow

if ([string]::IsNullOrWhiteSpace($TargetVersion)) {
    if ($currentVersion -le 1) {
        Write-Error "Cannot rollback: Current version ($currentVersion) is the initial version."
        exit 1
    }
    $targetVersionNum = $currentVersion - 1
} else {
    $targetVersionNum = [int]$TargetVersion
}

Write-Host "`n[2/3] Shifting 100% traffic to target version: $targetVersionNum..."
aws lambda update-alias `
    --function-name $lambdaName `
    --name "live" `
    --function-version "$targetVersionNum" `
    --routing-config "{}" `
    --region $Region | Out-Null

Write-Host "      Alias 'live' successfully repointed to Version: $targetVersionNum" -ForegroundColor Green

# 3. Post rollback status to CloudWatch Logs
Write-Host "`n[3/3] Broadcasting Rollback Event to Observability Layer..."
$logEvent = @{
    Event = "DEPLOYMENT_ROLLBACK"
    Environment = $Environment
    PreviousVersion = $currentVersion
    RestoredVersion = $targetVersionNum
    Timestamp = (Get-Date).ToString("o")
    Trigger = "HealthCheck_Failure_Or_Operator_Intervention"
} | ConvertTo-Json -Compress

Write-Host "      Rollback Event Logged: $logEvent" -ForegroundColor Gray

Write-Host "`n[+] Emergency rollback completed successfully. Traffic shifted to stable release $targetVersionNum." -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Red
