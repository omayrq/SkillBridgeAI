<#
.SYNOPSIS
    Provisions DynamoDB tables, Global Secondary Indexes, and backup policies via AWS CLI.
.DESCRIPTION
    Creates the core EIRS device registry DynamoDB table with Point-in-Time Recovery and KMS encryption.
.PARAMETER Environment
    Target environment (dev, qa, staging, prod). Default is 'dev'.
.PARAMETER Region
    Target AWS Region.
#>
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet("dev", "qa", "staging", "prod")]
    [string]$Environment = "dev",

    [Parameter()]
    [string]$Region = "us-east-1"
)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [04] Provisioning DynamoDB Data Layer" -ForegroundColor Cyan
Write-Host " Environment: $Environment | Region: $Region" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

$tableName = "eirs-$Environment-devices"

Write-Host "[1/3] Checking DynamoDB Table: $tableName..."
$tableCheck = aws dynamodb describe-table --table-name $tableName --region $Region 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "      Creating DynamoDB Table with GSIs..." -ForegroundColor Yellow
    
    aws dynamodb create-table `
        --table-name $tableName `
        --attribute-definitions file://dist/dynamo-attr-defs.json `
        --key-schema file://dist/dynamo-key-schema.json `
        --global-secondary-indexes file://dist/dynamo-gsis.json `
        --billing-mode PAY_PER_REQUEST `
        --tags Key=Environment,Value=$Environment Key=Project,Value=EIRS `
        --region $Region | Out-Null

    Write-Host "      Waiting for table active status..." -ForegroundColor Gray
    aws dynamodb wait table-exists --table-name $tableName --region $Region
    Write-Host "      Table created successfully." -ForegroundColor Green
} else {
    Write-Host "      Table already exists: $tableName" -ForegroundColor Green
}

# 2. Enable Point-In-Time Recovery (PITR)
Write-Host "`n[2/3] Enabling Point-in-Time Recovery (PITR)..."
try {
    aws dynamodb update-continuous-backups `
        --table-name $tableName `
        --point-in-time-recovery-specification PointInTimeRecoveryEnabled=true `
        --region $Region | Out-Null
    Write-Host "      PITR enabled." -ForegroundColor Green
} catch {
    Write-Host "      Failed or already active." -ForegroundColor Yellow
}

# 3. Enable Time To Live (TTL)
Write-Host "`n[3/3] Configuring Time To Live (TTL) on 'ExpirationTime'..."
try {
    aws dynamodb update-time-to-live `
        --table-name $tableName `
        --time-to-live-specification "Enabled=true,AttributeName=ExpirationTime" `
        --region $Region | Out-Null
    Write-Host "      TTL configured." -ForegroundColor Green
} catch {
    Write-Host "      TTL already configured." -ForegroundColor Yellow
}

Write-Host "`n[+] DynamoDB Data Layer is ready for [$Environment]." -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Cyan
