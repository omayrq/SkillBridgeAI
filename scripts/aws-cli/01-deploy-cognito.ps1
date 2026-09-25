<#
.SYNOPSIS
    Provision Amazon Cognito User Pool & App Client for SkillBridge AI
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
Write-Host " [01] PROVISIONING AMAZON COGNITO AUTHENTICATION" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

$poolName = "skillbridge-$Environment-user-pool"

# 1. Create User Pool
Write-Host "[1/2] Creating Cognito User Pool '$poolName'..." -ForegroundColor Yellow

$policyObj = @{
    PasswordPolicy = @{
        MinimumLength = 8
        RequireUppercase = $true
        RequireLowercase = $true
        RequireNumbers = $true
        RequireSymbols = $false
    }
} | ConvertTo-Json -Depth 5

$tempPolicyFile = [System.IO.Path]::GetTempFileName()
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($tempPolicyFile, $policyObj, $utf8NoBom)

$userPoolId = aws cognito-idp create-user-pool `
    --pool-name $poolName `
    --auto-verified-attributes email `
    --policies "file://$tempPolicyFile" `
    --region $Region `
    --query "UserPool.Id" `
    --output text

Remove-Item $tempPolicyFile -ErrorAction SilentlyContinue

Write-Host "      UserPool Created ID: $userPoolId" -ForegroundColor Green

# 2. Create User Pool Client
Write-Host "`n[2/2] Creating User Pool App Client..." -ForegroundColor Yellow
$clientId = aws cognito-idp create-user-pool-client `
    --user-pool-id $userPoolId `
    --client-name "skillbridge-$Environment-web-client" `
    --no-generate-secret `
    --explicit-auth-flows ALLOW_USER_SRP_AUTH ALLOW_REFRESH_TOKEN_AUTH ALLOW_USER_PASSWORD_AUTH `
    --region $Region `
    --query "UserPoolClient.ClientId" `
    --output text

Write-Host "      App Client Created ID: $clientId" -ForegroundColor Green

# Save manifest
$manifest = @{
    userPoolId = $userPoolId
    clientId = $clientId
    region = $Region
    environment = $Environment
} | ConvertTo-Json

New-Item -ItemType Directory -Force -Path "dist" | Out-Null
[System.IO.File]::WriteAllText("dist/cognito-manifest.json", $manifest, $utf8NoBom)

Write-Host "`n[+] Amazon Cognito Auth provisioned successfully!" -ForegroundColor Green
