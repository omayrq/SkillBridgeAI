<#
.SYNOPSIS
    Packages and deploys Lambda functions and configures Amazon API Gateway via AWS CLI.
.DESCRIPTION
    Builds the Lambda deployment zip bundle, creates or updates Lambda functions,
    provisions API Gateway resources and methods, and deploys to the target stage.
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
Write-Host " [05] Packaging & Deploying Compute & API Gateway" -ForegroundColor Cyan
Write-Host " Environment: $Environment | Region: $Region" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$projectRoot = Resolve-Path "$scriptRoot\..\.."
$srcDir = "$projectRoot\src\api"
$distDir = "$projectRoot\dist"
$zipPath = "$distDir\eirs-api-$Environment.zip"

# Ensure dist dir exists
if (-not (Test-Path $distDir)) {
    New-Item -ItemType Directory -Path $distDir | Out-Null
}

# 1. Package Lambda Code
Write-Host "[1/4] Packaging Lambda deployment bundle..."
if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
Compress-Archive -Path "$srcDir\*" -DestinationPath $zipPath -Force
$zipPathSlash = $zipPath.Replace('\', '/')
Write-Host "      Created deployment archive: $zipPath" -ForegroundColor Green

# 2. Get Account ID and Execution Role ARN
$callerIdentity = aws sts get-caller-identity --output json | ConvertFrom-Json
$accountId = $callerIdentity.Account
$roleArn = "arn:aws:iam::${accountId}:role/eirs-${Environment}-lambda-execution-role"
$lambdaName = "eirs-$Environment-api-handler"

# 3. Create or Update Lambda Function
Write-Host "`n[2/4] Deploying AWS Lambda function ($lambdaName)..."
$lambdaCheck = aws lambda get-function --function-name $lambdaName --region $Region 2>$null

if ($LASTEXITCODE -ne 0) {
    Write-Host "      Creating new Lambda function..." -ForegroundColor Yellow
    aws lambda create-function `
        --function-name $lambdaName `
        --runtime "nodejs20.x" `
        --role $roleArn `
        --handler "index.handler" `
        --zip-file "fileb://$zipPathSlash" `
        --timeout 15 `
        --memory-size 512 `
        --environment "Variables={ENVIRONMENT=$Environment,TABLE_NAME=eirs-$Environment-devices,LOG_LEVEL=info}" `
        --region $Region | Out-Null
    Write-Host "      Lambda function created." -ForegroundColor Green
} else {
    Write-Host "      Updating Lambda function code..." -ForegroundColor Yellow
    aws lambda update-function-code `
        --function-name $lambdaName `
        --zip-file "fileb://$zipPathSlash" `
        --region $Region | Out-Null
    
    # Wait for update
    aws lambda wait function-updated --function-name $lambdaName --region $Region
    Write-Host "      Lambda function code updated." -ForegroundColor Green
}

# Publish new version and point alias
Write-Host "      Publishing version and updating alias 'live'..."
$published = aws lambda publish-version --function-name $lambdaName --region $Region --output json | ConvertFrom-Json
$version = $published.Version

$aliasCheck = aws lambda get-alias --function-name $lambdaName --name "live" --region $Region 2>$null
if ($LASTEXITCODE -ne 0) {
    aws lambda create-alias --function-name $lambdaName --name "live" --function-version $version --region $Region | Out-Null
} else {
    aws lambda update-alias --function-name $lambdaName --name "live" --function-version $version --region $Region | Out-Null
}
Write-Host "      Alias 'live' pointing to version $version" -ForegroundColor Green

# 4. Create/Configure API Gateway REST API
Write-Host "`n[3/4] Configuring Amazon API Gateway..."
$apiName = "eirs-$Environment-api"
$apiList = aws apigateway get-rest-apis --region $Region --output json | ConvertFrom-Json
$existingApi = $apiList.items | Where-Object { $_.name -eq $apiName }

if ($null -eq $existingApi) {
    Write-Host "      Creating REST API: $apiName..." -ForegroundColor Yellow
    $apiObj = aws apigateway create-rest-api --name $apiName --description "EIRS REST API for $Environment" --region $Region --output json | ConvertFrom-Json
    $apiId = $apiObj.id
} else {
    $apiId = $existingApi.id
    Write-Host "      Existing REST API found: $apiId" -ForegroundColor Green
}

# Retrieve Root Resource
$resources = aws apigateway get-resources --rest-api-id $apiId --region $Region --output json | ConvertFrom-Json
$rootId = ($resources.items | Where-Object { $_.path -eq "/" }).id

# Create Proxy Resource /{proxy+} if it doesn't exist
$proxyResource = $resources.items | Where-Object { $_.path -eq "/{proxy+}" }
if ($null -eq $proxyResource) {
    Write-Host "      Creating proxy resource /{proxy+}..." -ForegroundColor Yellow
    $proxyObj = aws apigateway create-resource --rest-api-id $apiId --parent-id $rootId --path-part "{proxy+}" --region $Region --output json | ConvertFrom-Json
    $proxyId = $proxyObj.id
} else {
    $proxyId = $proxyResource.id
}

# Create ANY Method and Lambda Integration on /{proxy+}
Write-Host "      Configuring ANY method integration with Lambda..."
$lambdaTargetArn = "arn:aws:lambda:${Region}:${accountId}:function:${lambdaName}:live"

aws apigateway put-method `
    --rest-api-id $apiId `
    --resource-id $proxyId `
    --http-method ANY `
    --authorization-type NONE `
    --region $Region 2>$null | Out-Null

$uri = "arn:aws:apigateway:${Region}:lambda:path/2015-03-31/functions/$lambdaTargetArn/invocations"

aws apigateway put-integration `
    --rest-api-id $apiId `
    --resource-id $proxyId `
    --http-method ANY `
    --type AWS_PROXY `
    --integration-http-method POST `
    --uri $uri `
    --region $Region 2>$null | Out-Null

# Grant API Gateway permission to invoke Lambda alias
aws lambda add-permission `
    --function-name "$lambdaName:live" `
    --statement-id "apigateway-invoke-$apiId" `
    --action "lambda:InvokeFunction" `
    --principal "apigateway.amazonaws.com" `
    --source-arn "arn:aws:execute-api:${Region}:${accountId}:${apiId}/*/*/*" `
    --region $Region 2>$null | Out-Null

# 5. Deploy Stage
Write-Host "`n[4/4] Deploying API Gateway Stage: $Environment..."
$deployment = aws apigateway create-deployment --rest-api-id $apiId --stage-name $Environment --region $Region --output json | ConvertFrom-Json

$invokeUrl = "https://${apiId}.execute-api.${Region}.amazonaws.com/$Environment"
Write-Host "      API deployed successfully!" -ForegroundColor Green
Write-Host "      Base Invoke URL: $invokeUrl" -ForegroundColor Cyan

# Save endpoint to environment configuration
$envFile = "$projectRoot\dist\env-$Environment.json"
@{
    environment = $Environment
    region = $Region
    apiId = $apiId
    apiUrl = $invokeUrl
    lambdaName = $lambdaName
    version = $version
} | ConvertTo-Json | Set-Content -Path $envFile

Write-Host "`n[+] Compute & API Gateway provisioning complete." -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Cyan
