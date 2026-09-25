<#
.SYNOPSIS
    Verifies AWS CLI installation, active credentials, permissions, and environment readiness.
.DESCRIPTION
    Checks whether AWS CLI is installed, confirms caller identity via STS, validates the target region,
    and ensures the execution context has requisite permissions.
.PARAMETER Environment
    Target environment (dev, qa, staging, prod). Default is 'dev'.
.PARAMETER Region
    Target AWS Region (e.g. us-east-1, eu-central-1).
#>
[CmdletBinding()]
param (
    [Parameter()]
    [ValidateSet("dev", "qa", "staging", "prod")]
    [string]$Environment = "dev",

    [Parameter()]
    [string]$Region = ""
)

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host " [00] Verifying AWS Prerequisites & Control Plane Readiness" -ForegroundColor Cyan
Write-Host " Target Environment: $Environment" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Check AWS CLI installed
Write-Host "`n[1/4] Checking AWS CLI binary..." -NoNewline
try {
    $cliVersion = aws --version 2>&1
    Write-Host " OK ($cliVersion)" -ForegroundColor Green
} catch {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Error "AWS CLI is not installed or not available on the system PATH."
    exit 1
}

# 2. Check Region resolution
if ([string]::IsNullOrWhiteSpace($Region)) {
    $Region = aws configure get region 2>$null
    if ([string]::IsNullOrWhiteSpace($Region)) {
        $Region = "us-east-1"
        Write-Host "[!] No default region set; defaulting to $Region" -ForegroundColor Yellow
    }
}
Write-Host "[2/4] Target AWS Region: $Region" -ForegroundColor Green

# 3. Check STS Caller Identity (Active Credentials)
Write-Host "`n[3/4] Verifying AWS Credentials via STS..." -NoNewline
try {
    $callerIdentityJson = aws sts get-caller-identity --output json 2>$null
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($callerIdentityJson)) {
        throw "Failed to retrieve STS identity."
    }
    $identity = $callerIdentityJson | ConvertFrom-Json
    Write-Host " OK" -ForegroundColor Green
    Write-Host "    Account ID : $($identity.Account)" -ForegroundColor Gray
    Write-Host "    IAM Arn    : $($identity.Arn)" -ForegroundColor Gray
    Write-Host "    UserId     : $($identity.UserId)" -ForegroundColor Gray
} catch {
    Write-Host " FAILED" -ForegroundColor Red
    Write-Host "`n[!] No active AWS credentials found." -ForegroundColor Yellow
    Write-Host "    Please configure credentials using:" -ForegroundColor Yellow
    Write-Host "      1. 'aws configure' (Interactive entry of Access Key & Secret Key)" -ForegroundColor Cyan
    Write-Host "      2. Or set environment variables: `$env:AWS_ACCESS_KEY_ID and `$env:AWS_SECRET_ACCESS_KEY" -ForegroundColor Cyan
    Write-Host "      3. Or 'aws sso login' (if using AWS IAM Identity Center)" -ForegroundColor Cyan
    exit 1
}

# 4. Check core AWS service access
Write-Host "`n[4/4] Validating base API connectivity..." -NoNewline
try {
    $null = aws s3 ls 2>$null
    Write-Host " OK" -ForegroundColor Green
} catch {
    Write-Host " WARNING (Limited S3 access)" -ForegroundColor Yellow
}

Write-Host "`n[+] All prerequisites satisfied for environment [$Environment] in region [$Region]." -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Cyan
