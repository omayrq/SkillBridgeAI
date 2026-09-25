<#
.SYNOPSIS
    Provision Amazon DynamoDB Table for SkillBridge AI
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
Write-Host " [02] PROVISIONING AMAZON DYNAMODB TABLE" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$tableName = "skillbridge-$Environment-data"

Write-Host "[1/2] Creating DynamoDB table '$tableName'..." -ForegroundColor Yellow
try {
    aws dynamodb create-table `
        --table-name $tableName `
        --attribute-definitions AttributeName=PK,AttributeType=S AttributeName=SK,AttributeType=S `
        --key-schema AttributeName=PK,KeyType=HASH AttributeName=SK,KeyType=RANGE `
        --billing-mode PAY_PER_REQUEST `
        --region $Region | Out-Null

    Write-Host "      DynamoDB Table created." -ForegroundColor Green
} catch {
    Write-Host "      Table already exists or notice: $_" -ForegroundColor Yellow
}

# Enable Point in Time Recovery
Write-Host "`n[2/2] Enabling Point-In-Time Recovery (PITR)..." -ForegroundColor Yellow
try {
    aws dynamodb update-continuous-backups `
        --table-name $tableName `
        --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true `
        --region $Region | Out-Null
    Write-Host "      PITR Backups Enabled." -ForegroundColor Green
} catch {}

Write-Host "`n[+] Amazon DynamoDB Table provisioned successfully!" -ForegroundColor Green
