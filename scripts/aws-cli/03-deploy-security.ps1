<#
.SYNOPSIS
    Provisions KMS CMK, IAM Least-Privilege Execution Roles, and Secrets Manager via AWS CLI.
.DESCRIPTION
    Establishes the cryptographic backbone and identity security controls for EIRS services.
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
Write-Host " [03] Provisioning Security, KMS & IAM Infrastructure" -ForegroundColor Cyan
Write-Host " Environment: $Environment | Region: $Region" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

# 1. KMS Customer Managed Key
Write-Host "[1/3] Checking KMS Encryption Key..."
$keyAlias = "alias/eirs-$Environment-cmk"
$aliasCheck = aws kms list-aliases --region $Region --output json | ConvertFrom-Json
$existingAlias = $aliasCheck.Aliases | Where-Object { $_.AliasName -eq $keyAlias }

if ($null -eq $existingAlias) {
    Write-Host "      Creating Customer Managed KMS Key with automatic rotation..." -ForegroundColor Yellow
    $keyObj = aws kms create-key --description "EIRS Encryption Key for $Environment" --region $Region --output json | ConvertFrom-Json
    $keyId = $keyObj.KeyMetadata.KeyId
    aws kms create-alias --alias-name $keyAlias --target-key-id $keyId --region $Region
    aws kms enable-key-rotation --key-id $keyId --region $Region
    Write-Host "      Created KMS Key: $keyId ($keyAlias)" -ForegroundColor Green
} else {
    Write-Host "      KMS Key Alias already exists: $keyAlias" -ForegroundColor Green
}

# 2. IAM Role for Lambda Execution
Write-Host "`n[2/3] Configuring IAM Execution Role..."
$roleName = "eirs-$Environment-lambda-execution-role"
$roleCheck = aws iam get-role --role-name $roleName 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "      Creating IAM Role: $roleName..." -ForegroundColor Yellow
    $trustPolicyPath = "$env:TEMP\eirs-$Environment-trust-policy.json"
    @'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
'@ | Set-Content -Path $trustPolicyPath -Encoding UTF8

    aws iam create-role --role-name $roleName --assume-role-policy-document "file://$trustPolicyPath" | Out-Null
    
    # Attach standard AWS managed execution policy
    aws iam attach-role-policy --role-name $roleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
    aws iam attach-role-policy --role-name $roleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
    
    # Create and attach least-privilege DynamoDB and KMS inline policy
    $customPolicyPath = "$env:TEMP\eirs-$Environment-custom-policy.json"
    @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:${Region}:*:table/eirs-${Environment}-*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "kms:Decrypt",
        "kms:GenerateDataKey"
      ],
      "Resource": "*"
    }
  ]
}
"@ | Set-Content -Path $customPolicyPath -Encoding UTF8

    aws iam put-role-policy --role-name $roleName --policy-name "eirs-$Environment-dynamo-kms-access" --policy-document "file://$customPolicyPath"
    Write-Host "      IAM Role created and policies attached." -ForegroundColor Green
} else {
    Write-Host "      IAM Role already exists: $roleName" -ForegroundColor Green
}

# 3. Secrets Manager Secret Placeholder
Write-Host "`n[3/3] Checking Secrets Manager configuration..."
$secretName = "eirs/$Environment/api/keys"
$secretCheck = aws secretsmanager describe-secret --secret-id $secretName --region $Region 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "      Creating secret: $secretName..." -ForegroundColor Yellow
    aws secretsmanager create-secret `
        --name $secretName `
        --description "API authentication and partner gateway secret tokens" `
        --secret-string '{"JWT_SECRET":"super-secret-production-key-change-me","PARTNER_KEY":"carrier-key-dev"}' `
        --region $Region | Out-Null
    Write-Host "      Secret created." -ForegroundColor Green
} else {
    Write-Host "      Secret already exists: $secretName" -ForegroundColor Green
}

Write-Host "`n[+] Security and IAM infrastructure complete for [$Environment]." -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Cyan
