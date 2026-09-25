# Comprehensive Teardown Script for EIRS AWS Resources
param(
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

Write-Host "============================================================" -ForegroundColor Red
Write-Host " STARTING TEARDOWN OF ALL EIRS AWS RESOURCES" -ForegroundColor Red
Write-Host "============================================================" -ForegroundColor Red

# 1. Delete App Runner Service
Write-Host "[1/12] Deleting App Runner Service 'eirs-apprunner-api'..."
try {
    $appRunnerArn = aws apprunner list-services --region $Region --query "ServiceSummaryList[?ServiceName=='eirs-apprunner-api'].ServiceArn" --output text
    if ($appRunnerArn -and $appRunnerArn -ne "None") {
        aws apprunner delete-service --service-arn $appRunnerArn --region $Region | Out-Null
        Write-Host "      Initiated deletion of App Runner service." -ForegroundColor Green
    } else {
        Write-Host "      App Runner service not found." -ForegroundColor Yellow
    }
} catch {
    Write-Host "      App Runner teardown note: $_" -ForegroundColor Yellow
}

# 2. Disable CloudFront Distribution
Write-Host "[2/12] Disabling CloudFront distribution 'E2KZUIN7IIV2JT'..."
try {
    $cfConfigJson = aws cloudfront get-distribution-config --id "E2KZUIN7IIV2JT" --output json | ConvertFrom-Json
    $etag = aws cloudfront get-distribution-config --id "E2KZUIN7IIV2JT" --query "ETag" --output text
    if ($cfConfigJson.DistributionConfig.Enabled -eq $true) {
        $cfConfigJson.DistributionConfig.Enabled = $false
        $tempConfigFile = [System.IO.Path]::GetTempFileName()
        $cfConfigJson.DistributionConfig | ConvertTo-Json -Depth 10 | Set-Content -Path $tempConfigFile -Encoding UTF8
        $bytes = [System.IO.File]::ReadAllBytes($tempConfigFile)
        if ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF) {
            [System.IO.File]::WriteAllBytes($tempConfigFile, $bytes[3..($bytes.Length-1)])
        }
        aws cloudfront update-distribution --id "E2KZUIN7IIV2JT" --if-match $etag --distribution-config "file://$tempConfigFile" | Out-Null
        Remove-Item $tempConfigFile -ErrorAction SilentlyContinue
        Write-Host "      Disabled CloudFront distribution E2KZUIN7IIV2JT." -ForegroundColor Green
    } else {
        Write-Host "      CloudFront distribution is already disabled." -ForegroundColor Yellow
    }
} catch {
    Write-Host "      CloudFront note: $_" -ForegroundColor Yellow
}

# 3. Delete AWS WAF WebACL
Write-Host "[3/12] Deleting WAF WebACL 'eirs-dev-waf'..."
try {
    $webAcl = aws wafv2 list-web-acls --scope REGIONAL --region $Region --query "WebACLs[?Name=='eirs-dev-waf']" --output json | ConvertFrom-Json
    if ($webAcl -and $webAcl.Count -gt 0) {
        $wafId = $webAcl[0].Id
        $wafLockToken = $webAcl[0].LockToken
        aws wafv2 delete-web-acl --name "eirs-dev-waf" --scope REGIONAL --id $wafId --lock-token $wafLockToken --region $Region | Out-Null
        Write-Host "      Deleted WAF WebACL eirs-dev-waf." -ForegroundColor Green
    } else {
        Write-Host "      WAF WebACL not found." -ForegroundColor Yellow
    }
} catch {
    Write-Host "      WAF WebACL note: $_" -ForegroundColor Yellow
}

# 4. Delete API Gateway REST API
Write-Host "[4/12] Deleting API Gateway '30yy54ukk5'..."
try {
    aws apigateway delete-rest-api --rest-api-id "30yy54ukk5" --region $Region | Out-Null
    Write-Host "      Deleted API Gateway REST API 30yy54ukk5." -ForegroundColor Green
} catch {
    Write-Host "      API Gateway rest api note: $_" -ForegroundColor Yellow
}

# 5. Delete Lambda Function
Write-Host "[5/12] Deleting Lambda Function 'eirs-dev-api-handler'..."
try {
    aws lambda delete-function --function-name "eirs-dev-api-handler" --region $Region | Out-Null
    Write-Host "      Deleted Lambda function eirs-dev-api-handler." -ForegroundColor Green
} catch {
    Write-Host "      Lambda function note: $_" -ForegroundColor Yellow
}

# 6. Delete DynamoDB Tables
Write-Host "[6/12] Deleting DynamoDB tables..."
@("eirs-dev-devices", "eirs-dev-deploy-lock") | ForEach-Object {
    try {
        aws dynamodb delete-table --table-name $_ --region $Region | Out-Null
        Write-Host "      Deleted DynamoDB table $_." -ForegroundColor Green
    } catch {
        Write-Host "      DynamoDB table $_ note: $_" -ForegroundColor Yellow
    }
}

# 7. Delete CodeBuild Project
Write-Host "[7/12] Deleting CodeBuild project 'eirs-container-builder'..."
try {
    aws codebuild delete-project --name "eirs-container-builder" --region $Region | Out-Null
    Write-Host "      Deleted CodeBuild project eirs-container-builder." -ForegroundColor Green
} catch {
    Write-Host "      CodeBuild project note: $_" -ForegroundColor Yellow
}

# 8. Delete ECR Repository
Write-Host "[8/12] Deleting ECR Repository 'eirs-apprunner'..."
try {
    aws ecr delete-repository --repository-name "eirs-apprunner" --force --region $Region | Out-Null
    Write-Host "      Force deleted ECR repository eirs-apprunner." -ForegroundColor Green
} catch {
    Write-Host "      ECR repository note: $_" -ForegroundColor Yellow
}

# 9. Empty and Delete S3 Buckets
Write-Host "[9/12] Emptying and deleting S3 buckets..."
@("eirs-dev-artifacts-$AccountId-$Region", "eirs-dev-web-ui-$AccountId") | ForEach-Object {
    $b = $_
    try {
        aws s3 rm "s3://$b" --recursive --region $Region | Out-Null
        aws s3api delete-bucket --bucket $b --region $Region | Out-Null
        Write-Host "      Deleted S3 bucket $b." -ForegroundColor Green
    } catch {
        Write-Host "      S3 bucket $b note: $_" -ForegroundColor Yellow
    }
}

# 10. Schedule KMS Key Deletion & Delete Alias
Write-Host "[10/12] Deleting KMS Alias and scheduling Key Deletion..."
try {
    $kmsKeyId = "fe2c95bb-bd89-40f4-aa21-208e823e960e"
    aws kms delete-alias --alias-name "alias/eirs-dev-cmk" --region $Region | Out-Null
    Write-Host "      Deleted KMS alias/eirs-dev-cmk." -ForegroundColor Green
    aws kms schedule-key-deletion --key-id $kmsKeyId --pending-window-in-days 7 --region $Region | Out-Null
    Write-Host "      Scheduled key deletion for $kmsKeyId." -ForegroundColor Green
} catch {
    Write-Host "      KMS note: $_" -ForegroundColor Yellow
}

# 11. Delete IAM Roles and Attached Policies
Write-Host "[11/12] Deleting IAM Roles and Policies..."
$roles = @("eirs-dev-lambda-execution-role", "eirs-codebuild-service-role", "eirs-apprunner-ecr-access-role", "eirs-apprunner-instance-role")
foreach ($roleName in $roles) {
    try {
        $attached = aws iam list-attached-role-policies --role-name $roleName --output json | ConvertFrom-Json
        foreach ($pol in $attached.AttachedPolicies) {
            aws iam detach-role-policy --role-name $roleName --policy-arn $pol.PolicyArn | Out-Null
        }
        $inline = aws iam list-role-policies --role-name $roleName --output json | ConvertFrom-Json
        foreach ($pName in $inline.PolicyNames) {
            aws iam delete-role-policy --role-name $roleName --policy-name $pName | Out-Null
        }
        aws iam delete-role --role-name $roleName | Out-Null
        Write-Host "      Deleted IAM Role $roleName." -ForegroundColor Green
    } catch {
        Write-Host "      Role $roleName note: $_" -ForegroundColor Yellow
    }
}

# 12. Delete VPC & Networking Infrastructure
Write-Host "[12/12] Deleting VPC and networking infrastructure..."
try {
    aws ec2 delete-security-group --group-id "sg-02f81f1232d4c0b03" --region $Region | Out-Null
    Write-Host "      Deleted security group sg-02f81f1232d4c0b03." -ForegroundColor Green
} catch {}

try {
    aws ec2 detach-internet-gateway --internet-gateway-id "igw-0df631ea085361d26" --vpc-id "vpc-01b814de33f75dc87" --region $Region | Out-Null
    aws ec2 delete-internet-gateway --internet-gateway-id "igw-0df631ea085361d26" --region $Region | Out-Null
    Write-Host "      Deleted Internet Gateway igw-0df631ea085361d26." -ForegroundColor Green
} catch {}

try {
    aws ec2 delete-subnet --subnet-id "subnet-0ce50654507199a37" --region $Region | Out-Null
    aws ec2 delete-subnet --subnet-id "subnet-0782ba5e2124baa11" --region $Region | Out-Null
    Write-Host "      Deleted subnets." -ForegroundColor Green
} catch {}

try {
    aws ec2 delete-vpc --vpc-id "vpc-01b814de33f75dc87" --region $Region | Out-Null
    Write-Host "      Deleted VPC vpc-01b814de33f75dc87." -ForegroundColor Green
} catch {}

Write-Host "============================================================" -ForegroundColor Red
Write-Host " TEARDOWN COMPLETED SUCCESSFULLY!" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Red
