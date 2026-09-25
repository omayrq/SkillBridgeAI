<#
.SYNOPSIS
    Deploy SkillBridge AI Backend Service to AWS Lambda & API Gateway
#>
[CmdletBinding()]
param(
    [string]$Environment = "dev",
    [string]$Region = "us-east-1",
    [string]$AccountId = "528582359305"
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
Write-Host " [03] DEPLOYING SKILLBRIDGE AI TO AWS LAMBDA & API GATEWAY" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Create IAM execution role for Lambda
$roleName = "skillbridge-lambda-execution-role"
$assumeRolePolicy = @{
    Version = "2012-10-17"
    Statement = @(
        @{
            Effect = "Allow"
            Principal = @{ Service = "lambda.amazonaws.com" }
            Action = "sts:AssumeRole"
        }
    )
} | ConvertTo-Json -Depth 5

$tempRoleFile = [System.IO.Path]::GetTempFileName()
$utf8NoBom = New-Object System.Text.UTF8Encoding $false
[System.IO.File]::WriteAllText($tempRoleFile, $assumeRolePolicy, $utf8NoBom)

try {
    aws iam create-role --role-name $roleName --assume-role-policy-document "file://$tempRoleFile" | Out-Null
    aws iam attach-role-policy --role-name $roleName --policy-arn "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole" | Out-Null
    aws iam attach-role-policy --role-name $roleName --policy-arn "arn:aws:iam::aws:policy/AmazonBedrockFullAccess" | Out-Null
    aws iam attach-role-policy --role-name $roleName --policy-arn "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess" | Out-Null
    Write-Host "      Created IAM Role $roleName. Waiting for IAM propagation..." -ForegroundColor Yellow
    Start-Sleep -Seconds 10
} catch {
    Write-Host "      Role $roleName already exists." -ForegroundColor Yellow
}
Remove-Item $tempRoleFile -ErrorAction SilentlyContinue

$roleArn = "arn:aws:iam::${AccountId}:role/$roleName"

# Zip lambda bundle with src/ directory structure preserved
$zipPath = "$env:TEMP\skillbridge-lambda.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }
Compress-Archive -Path "src", "package.json" -DestinationPath $zipPath -Force

$lambdaName = "skillbridge-dev-api-handler"
Write-Host "`n[2/4] Deploying AWS Lambda Function '$lambdaName'..." -ForegroundColor Yellow

aws lambda update-function-configuration `
    --function-name $lambdaName `
    --handler "src/api/index.handler" `
    --timeout 30 `
    --memory-size 512 `
    --region $Region 2>$null | Out-Null

aws lambda update-function-code `
    --function-name $lambdaName `
    --zip-file "fileb://$zipPath" `
    --region $Region | Out-Null
Write-Host "      Updated Lambda function code & configuration $lambdaName." -ForegroundColor Green

# 3. Create REST API Gateway
Write-Host "`n[3/4] Provisioning Amazon API Gateway REST API..." -ForegroundColor Yellow
$apiName = "skillbridge-dev-api"
$existingApis = aws apigateway get-rest-apis --region $Region --query "items[?name=='$apiName'].id" --output text
if (-not $existingApis -or $existingApis -eq "None") {
    $apiJson = aws apigateway create-rest-api --name $apiName --endpoint-configuration "types=REGIONAL" --region $Region --output json | ConvertFrom-Json
    $apiId = $apiJson.id
} else {
    $apiId = $existingApis
}

$rootResId = aws apigateway get-resources --rest-api-id $apiId --region $Region --query "items[?path=='/'].id" --output text

aws apigateway put-method --rest-api-id $apiId --resource-id $rootResId --http-method ANY --authorization-type NONE --region $Region 2>$null | Out-Null

$uri = "arn:aws:apigateway:${Region}:lambda:path/2015-03-31/functions/arn:aws:lambda:${Region}:${AccountId}:function:${lambdaName}/invocations"

aws apigateway put-integration `
    --rest-api-id $apiId `
    --resource-id $rootResId `
    --http-method ANY `
    --type AWS_PROXY `
    --integration-http-method POST `
    --uri $uri `
    --region $Region 2>$null | Out-Null

aws lambda add-permission `
    --function-name $lambdaName `
    --statement-id "apigateway-any-$apiId" `
    --action "lambda:InvokeFunction" `
    --principal "apigateway.amazonaws.com" `
    --source-arn "arn:aws:execute-api:${Region}:${AccountId}:${apiId}/*/*" `
    --region $Region 2>$null | Out-Null

$proxyResId = aws apigateway get-resources --rest-api-id $apiId --region $Region --query "items[?path=='/{proxy+}'].id" --output text
if (-not $proxyResId -or $proxyResId -eq "None") {
    $proxyRes = aws apigateway create-resource --rest-api-id $apiId --parent-id $rootResId --path-part "{proxy+}" --region $Region --output json | ConvertFrom-Json
    $proxyResId = $proxyRes.id
}

aws apigateway put-method --rest-api-id $apiId --resource-id $proxyResId --http-method ANY --authorization-type NONE --region $Region 2>$null | Out-Null
aws apigateway put-integration `
    --rest-api-id $apiId `
    --resource-id $proxyResId `
    --http-method ANY `
    --type AWS_PROXY `
    --integration-http-method POST `
    --uri $uri `
    --region $Region 2>$null | Out-Null

aws apigateway create-deployment --rest-api-id $apiId --stage-name "dev" --region $Region | Out-Null
$apiUrl = "https://${apiId}.execute-api.${Region}.amazonaws.com/dev"
Write-Host "      API Gateway deployed: $apiUrl" -ForegroundColor Green

# 4. Save API Manifest
$manifest = @{
    apiId = $apiId
    apiUrl = $apiUrl
    lambdaName = $lambdaName
    region = $Region
    environment = $Environment
} | ConvertTo-Json

New-Item -ItemType Directory -Force -Path "dist" | Out-Null
[System.IO.File]::WriteAllText("dist/api-manifest.json", $manifest, $utf8NoBom)

Write-Host "`n[+] API Gateway & Lambda deployment complete!" -ForegroundColor Green
