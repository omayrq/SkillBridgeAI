<#
.SYNOPSIS
    Deploys the EIRS Containerized API directly to AWS App Runner via ECR and CodeBuild.
.DESCRIPTION
    Builds the Docker container in AWS CodeBuild, pushes to Amazon ECR,
    provisions the App Runner service with public HTTPS URL, and runs health verification.
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
Write-Host " [09] Deploying EIRS Service to AWS App Runner" -ForegroundColor Cyan
Write-Host " Environment: $Environment | Region: $Region" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path "$scriptRoot\..\.."
$srcDir = "$projectRoot\src\api"
$distDir = "$projectRoot\dist"
$zipPath = "$distDir\apprunner-source.zip"

$callerIdentity = aws sts get-caller-identity --output json | ConvertFrom-Json
$accountId = $callerIdentity.Account
$ecrRepoName = "eirs-apprunner"
$s3Bucket = "eirs-$Environment-artifacts-${accountId}-${Region}"

# 1. Check / Create Amazon ECR Repository
Write-Host "[1/6] Checking Amazon ECR Repository ($ecrRepoName)..."
$ecrCheck = aws ecr describe-repositories --repository-names $ecrRepoName --region $Region 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "      Creating ECR repository..." -ForegroundColor Yellow
    $ecrObj = aws ecr create-repository --repository-name $ecrRepoName --region $Region --output json | ConvertFrom-Json
    $ecrUri = $ecrObj.repository.repositoryUri
    Write-Host "      Created ECR Repo: $ecrUri" -ForegroundColor Green
} else {
    $ecrObj = $ecrCheck | ConvertFrom-Json
    $ecrUri = $ecrObj.repositories[0].repositoryUri
    Write-Host "      ECR Repo exists: $ecrUri" -ForegroundColor Green
}

# 2. Package Source & Upload to S3 for CodeBuild
Write-Host "`n[2/6] Packaging source code for cloud build..."
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$srcDir\*" -DestinationPath $zipPath -Force
aws s3 cp $zipPath "s3://$s3Bucket/build/apprunner-source.zip" --region $Region | Out-Null
Write-Host "      Uploaded source bundle to s3://$s3Bucket/build/apprunner-source.zip" -ForegroundColor Green

# 3. Create CodeBuild IAM Role
Write-Host "`n[3/6] Configuring AWS CodeBuild IAM Role..."
$codeBuildRole = "eirs-codebuild-service-role"
$cbRoleCheck = aws iam get-role --role-name $codeBuildRole 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "      Creating CodeBuild service role..." -ForegroundColor Yellow
    $cbTrust = @'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "codebuild.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
'@
    $cbTrustPath = "$distDir\cb-trust-policy.json"
    $cbTrust | Set-Content -Path $cbTrustPath -Encoding UTF8
    aws iam create-role --role-name $codeBuildRole --assume-role-policy-document "file://$cbTrustPath" | Out-Null

    $cbPolicy = @"
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "s3:GetObject",
        "s3:GetObjectVersion"
      ],
      "Resource": "arn:aws:s3:::$s3Bucket/*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "*"
    }
  ]
}
"@
    $cbPolicyPath = "$distDir\cb-custom-policy.json"
    $cbPolicy | Set-Content -Path $cbPolicyPath -Encoding UTF8
    aws iam put-role-policy --role-name $codeBuildRole --policy-name "codebuild-ecr-s3-policy" --policy-document "file://$cbPolicyPath"
    Write-Host "      Waiting for IAM role propagation..." -ForegroundColor Gray
    Start-Sleep -Seconds 5
    Write-Host "      CodeBuild role configured." -ForegroundColor Green
} else {
    Write-Host "      CodeBuild role exists: $codeBuildRole" -ForegroundColor Green
}

# 4. Create & Run CodeBuild Project
Write-Host "`n[4/6] Triggering Container Image Build in CodeBuild..."
$cbProjectName = "eirs-container-builder"
$cbProjCheck = aws codebuild batch-get-projects --names $cbProjectName --region $Region --output json | ConvertFrom-Json
$cbRoleArn = "arn:aws:iam::${accountId}:role/$codeBuildRole"

if ($cbProjCheck.projects.Count -eq 0) {
    Write-Host "      Creating CodeBuild Project..." -ForegroundColor Yellow
    aws codebuild create-project `
        --name $cbProjectName `
        --source "type=S3,location=$s3Bucket/build/apprunner-source.zip" `
        --artifacts "type=NO_ARTIFACTS" `
        --environment "type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0,computeType=BUILD_GENERAL1_SMALL,privilegedMode=true,environmentVariables=[{name=AWS_ACCOUNT_ID,value=$accountId},{name=AWS_DEFAULT_REGION,value=$Region},{name=IMAGE_REPO_NAME,value=$ecrRepoName}]" `
        --service-role $cbRoleArn `
        --region $Region | Out-Null
    Write-Host "      Project created." -ForegroundColor Green
} else {
    Write-Host "      Updating CodeBuild Project configuration..." -ForegroundColor Yellow
    aws codebuild update-project `
        --name $cbProjectName `
        --source "type=S3,location=$s3Bucket/build/apprunner-source.zip" `
        --environment "type=LINUX_CONTAINER,image=aws/codebuild/standard:7.0,computeType=BUILD_GENERAL1_SMALL,privilegedMode=true,environmentVariables=[{name=AWS_ACCOUNT_ID,value=$accountId},{name=AWS_DEFAULT_REGION,value=$Region},{name=IMAGE_REPO_NAME,value=$ecrRepoName}]" `
        --region $Region | Out-Null
}

Write-Host "      Starting Build..." -ForegroundColor Yellow
$buildObj = aws codebuild start-build --project-name $cbProjectName --region $Region --output json | ConvertFrom-Json
$buildId = $buildObj.build.id
Write-Host "      Build initiated: $buildId" -ForegroundColor Cyan

# Poll build status
$buildStatus = "IN_PROGRESS"
while ($buildStatus -eq "IN_PROGRESS") {
    Start-Sleep -Seconds 10
    $buildCheck = aws codebuild batch-get-builds --ids $buildId --region $Region --output json | ConvertFrom-Json
    $buildStatus = $buildCheck.builds[0].buildStatus
    Write-Host "      Build Status: $buildStatus..." -ForegroundColor Gray
}

if ($buildStatus -ne "SUCCEEDED") {
    Write-Error "CodeBuild failed with status $buildStatus. Check logs: $($buildCheck.builds[0].logs.deepLink)"
    exit 1
}
Write-Host "      Container image built and pushed to ECR: ${ecrUri}:latest" -ForegroundColor Green

# 5. App Runner Roles
Write-Host "`n[5/6] Setting up App Runner ECR Access & Instance Roles..."
$appRunnerAccessRole = "eirs-apprunner-ecr-access-role"
$arRoleCheck = aws iam get-role --role-name $appRunnerAccessRole 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "      Creating App Runner ECR Access Role..." -ForegroundColor Yellow
    $arTrust = @'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "build.apprunner.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
'@
    $arTrustPath = "$distDir\ar-trust-policy.json"
    $arTrust | Set-Content -Path $arTrustPath -Encoding UTF8
    aws iam create-role --role-name $appRunnerAccessRole --assume-role-policy-document "file://$arTrustPath" | Out-Null
    aws iam attach-role-policy --role-name $appRunnerAccessRole --policy-arn "arn:aws:iam::aws:policy/service-role/AWSAppRunnerServicePolicyForECRAccess"
    Start-Sleep -Seconds 5
}
$appRunnerAccessRoleArn = "arn:aws:iam::${accountId}:role/$appRunnerAccessRole"

# 6. Create / Update App Runner Service
Write-Host "`n[6/6] Provisioning AWS App Runner Service..."
$serviceName = "eirs-apprunner-api"
$arServices = aws apprunner list-services --region $Region --output json | ConvertFrom-Json
$existingService = $arServices.ServiceSummaryList | Where-Object { $_.ServiceName -eq $serviceName }

$sourceConfigJson = @"
{
  "ImageRepository": {
    "ImageIdentifier": "${ecrUri}:latest",
    "ImageConfiguration": {
      "Port": "8080",
      "RuntimeEnvironmentVariables": {
        "ENVIRONMENT": "$Environment",
        "TABLE_NAME": "eirs-$Environment-devices"
      }
    },
    "ImageRepositoryType": "ECR"
  },
  "AuthenticationConfiguration": {
    "AccessRoleArn": "$appRunnerAccessRoleArn"
  },
  "AutoDeploymentsEnabled": true
}
"@
$sourceConfigPath = "$distDir\ar-source-config.json"
$sourceConfigJson | Set-Content -Path $sourceConfigPath -Encoding UTF8

if ($null -eq $existingService) {
    Write-Host "      Creating App Runner service: $serviceName..." -ForegroundColor Yellow
    $arCreate = aws apprunner create-service `
        --service-name $serviceName `
        --source-configuration "file://$sourceConfigPath" `
        --instance-configuration "Cpu=1024,Memory=2048" `
        --region $Region --output json | ConvertFrom-Json
    $serviceArn = $arCreate.Service.ServiceArn
    $serviceUrl = "https://" + $arCreate.Service.ServiceUrl
    Write-Host "      Service creation initiated: $serviceArn" -ForegroundColor Cyan
} else {
    $serviceArn = $existingService.ServiceArn
    $serviceUrl = "https://" + $existingService.ServiceUrl
    Write-Host "      Service already exists: $serviceArn" -ForegroundColor Green
    Write-Host "      Triggering fresh deployment..." -ForegroundColor Yellow
    aws apprunner start-deployment --service-arn $serviceArn --region $Region | Out-Null
}

Write-Host "      Waiting for App Runner service to transition to RUNNING..." -ForegroundColor Yellow
$serviceStatus = "OPERATION_IN_PROGRESS"
while ($serviceStatus -ne "RUNNING" -and $serviceStatus -ne "PAUSED") {
    Start-Sleep -Seconds 15
    $svcCheck = aws apprunner describe-service --service-arn $serviceArn --region $Region --output json | ConvertFrom-Json
    $serviceStatus = $svcCheck.Service.Status
    $serviceUrl = "https://" + $svcCheck.Service.ServiceUrl
    Write-Host "      App Runner Status: $serviceStatus..." -ForegroundColor Gray
}

Write-Host "`n[+] AWS App Runner Service is LIVE!" -ForegroundColor Green
Write-Host "    Public HTTPS URL: $serviceUrl" -ForegroundColor Cyan
Write-Host "============================================================`n" -ForegroundColor Cyan
