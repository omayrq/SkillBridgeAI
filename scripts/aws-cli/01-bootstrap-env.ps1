<#
.SYNOPSIS
    Bootstraps S3 artifact/state storage and state-locking infrastructure.
.DESCRIPTION
    Creates an encrypted, versioned S3 bucket for build artifacts and deployment state,
    along with a DynamoDB lock table to prevent concurrent deployments.
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
Write-Host " [01] Bootstrapping Deployment State & Artifact Storage" -ForegroundColor Cyan
Write-Host " Environment: $Environment | Region: $Region" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

# Get Account ID
$callerIdentity = aws sts get-caller-identity --output json | ConvertFrom-Json
$accountId = $callerIdentity.Account
$bucketName = "eirs-$Environment-artifacts-$accountId-$Region"
$lockTableName = "eirs-$Environment-deploy-lock"

Write-Host "[1/2] Checking S3 Artifact Bucket: $bucketName..."
$bucketExists = aws s3api head-bucket --bucket $bucketName 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "      Creating bucket in $Region..." -ForegroundColor Yellow
    if ($Region -eq "us-east-1") {
        aws s3api create-bucket --bucket $bucketName --region $Region
    } else {
        aws s3api create-bucket --bucket $bucketName --region $Region --create-bucket-configuration LocationConstraint=$Region
    }
    
    # Enable versioning
    aws s3api put-bucket-versioning --bucket $bucketName --versioning-configuration Status=Enabled
    # Block public access
    aws s3api put-public-access-block --bucket $bucketName --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    # Enable server-side encryption (AES256 default / KMS)
    aws s3api put-bucket-encryption --bucket $bucketName --server-side-encryption-configuration '{\"Rules\": [{\"ApplyServerSideEncryptionByDefault\": {\"SSEAlgorithm\": \"AES256\"}}]}'
    Write-Host "      Bucket created and hardened." -ForegroundColor Green
} else {
    Write-Host "      Bucket already exists and is ready." -ForegroundColor Green
}

Write-Host "`n[2/2] Checking DynamoDB Deployment Lock Table: $lockTableName..."
$tableExists = aws dynamodb describe-table --table-name $lockTableName --region $Region 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "      Creating lock table..." -ForegroundColor Yellow
    aws dynamodb create-table `
        --table-name $lockTableName `
        --attribute-definitions AttributeName=LockID,AttributeType=S `
        --key-schema AttributeName=LockID,KeyType=HASH `
        --billing-mode PAY_PER_REQUEST `
        --region $Region
    Write-Host "      Waiting for table creation..." -ForegroundColor Gray
    aws dynamodb wait table-exists --table-name $lockTableName --region $Region
    Write-Host "      Lock table created." -ForegroundColor Green
} else {
    Write-Host "      Lock table already exists." -ForegroundColor Green
}

Write-Host "`n[+] Environment [$Environment] bootstrapping complete." -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Cyan
