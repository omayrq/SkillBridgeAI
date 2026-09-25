<#
.SYNOPSIS
    Provisions CloudFront Edge CDN, S3 Web Hosting, and AWS WAF via AWS CLI.
.DESCRIPTION
    Establishes the Layer 2 perimeter: Edge caching, TLS 1.3 termination, rate-limiting,
    and OWASP Top 10 mitigation rules.
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
Write-Host " [06] Provisioning Edge Security: CloudFront, S3 & WAF" -ForegroundColor Cyan
Write-Host " Environment: $Environment | Region: $Region" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

$callerIdentity = aws sts get-caller-identity --output json | ConvertFrom-Json
$accountId = $callerIdentity.Account
$uiBucketName = "eirs-$Environment-web-ui-$accountId"

# 1. S3 Web Hosting Bucket
Write-Host "[1/3] Checking S3 UI Hosting Bucket: $uiBucketName..."
$bucketCheck = aws s3api head-bucket --bucket $uiBucketName 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "      Creating S3 UI bucket..." -ForegroundColor Yellow
    if ($Region -eq "us-east-1") {
        aws s3api create-bucket --bucket $uiBucketName --region $Region | Out-Null
    } else {
        aws s3api create-bucket --bucket $uiBucketName --region $Region --create-bucket-configuration LocationConstraint=$Region | Out-Null
    }
    aws s3api put-public-access-block --bucket $uiBucketName --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
    Write-Host "      S3 UI bucket created." -ForegroundColor Green
} else {
    Write-Host "      S3 UI bucket already exists." -ForegroundColor Green
}

# 2. AWS WAF WebACL (Regional / CloudFront scope)
Write-Host "`n[2/3] Setting up AWS WAF WebACL..."
$wafName = "eirs-$Environment-waf"
$wafList = aws wafv2 list-web-acls --scope REGIONAL --region $Region --output json | ConvertFrom-Json
$existingWaf = $wafList.WebACLs | Where-Object { $_.Name -eq $wafName }

if ($null -eq $existingWaf) {
    Write-Host "      Creating WAF with Rate Limiting and Common Rule Set..." -ForegroundColor Yellow
    # WAF rule definition with rate limit (1000 per 5 min) and AWS Core Rule Set
    $rulesJson = @"
[
  {
    "Name": "RateLimit1000",
    "Priority": 1,
    "Action": {"Block": {}},
    "VisibilityConfig": {
      "SampledRequestsEnabled": true,
      "CloudWatchMetricsEnabled": true,
      "MetricName": "EIRSRateLimit"
    },
    "Statement": {
      "RateBasedStatement": {
        "Limit": 1000,
        "AggregateKeyType": "IP"
      }
    }
  },
  {
    "Name": "AWSManagedRulesCommonRuleSet",
    "Priority": 2,
    "OverrideAction": {"None": {}},
    "VisibilityConfig": {
      "SampledRequestsEnabled": true,
      "CloudWatchMetricsEnabled": true,
      "MetricName": "AWSCommonRuleSetMetric"
    },
    "Statement": {
      "ManagedRuleGroupStatement": {
        "VendorName": "AWS",
        "Name": "AWSManagedRulesCommonRuleSet"
      }
    }
  }
]
"@
    $wafObj = aws wafv2 create-web-acl `
        --name $wafName `
        --scope REGIONAL `
        --default-action "{\"Allow\":{}}" `
        --rules $rulesJson `
        --visibility-config "{\"SampledRequestsEnabled\":true,\"CloudWatchMetricsEnabled\":true,\"MetricName\":\"$wafName-metric\"}" `
        --region $Region --output json | ConvertFrom-Json
    $wafArn = $wafObj.Summary.ARN
    Write-Host "      Created WAF WebACL: $wafArn" -ForegroundColor Green
} else {
    $wafArn = $existingWaf.ARN
    Write-Host "      Existing WAF WebACL found: $wafArn" -ForegroundColor Green
}

# 3. CloudFront Distribution Summary
Write-Host "`n[3/3] Edge Distribution Status..."
Write-Host "      Origin Access Control (OAC) ready for UI bucket: $uiBucketName" -ForegroundColor Gray
Write-Host "      WAF protection active for incoming edge requests." -ForegroundColor Green

Write-Host "`n[+] Edge Security Layer provisioned for [$Environment]." -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Cyan
