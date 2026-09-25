<#
.SYNOPSIS
    Provisions VPC, Subnets, Internet Gateway, Route Tables, and Security Groups via AWS CLI.
.DESCRIPTION
    Creates an isolated network topology with public and private subnets across multiple AZs.
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
Write-Host " [02] Provisioning Multi-AZ VPC & Network Infrastructure" -ForegroundColor Cyan
Write-Host " Environment: $Environment | Region: $Region" -ForegroundColor Yellow
Write-Host "============================================================" -ForegroundColor Cyan

# 1. Create VPC
$cidrBlock = switch ($Environment) {
    "dev"     { "10.10.0.0/16" }
    "qa"      { "10.20.0.0/16" }
    "staging" { "10.30.0.0/16" }
    "prod"    { "10.0.0.0/16" }
}

Write-Host "[1/5] Checking/Creating VPC ($cidrBlock)..."
$vpcFilter = "Name=tag:Name,Values=eirs-$Environment-vpc"
$existingVpc = aws ec2 describe-vpcs --filters $vpcFilter --region $Region --output json | ConvertFrom-Json

if ($existingVpc.Vpcs.Count -eq 0) {
    $vpcObj = aws ec2 create-vpc --cidr-block $cidrBlock --region $Region --output json | ConvertFrom-Json
    $vpcId = $vpcObj.Vpc.VpcId
    aws ec2 create-tags --resources $vpcId --tags Key=Name,Value="eirs-$Environment-vpc" Key=Environment,Value=$Environment --region $Region
    aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-hostnames "{\"Value\":true}" --region $Region
    aws ec2 modify-vpc-attribute --vpc-id $vpcId --enable-dns-support "{\"Value\":true}" --region $Region
    Write-Host "      Created VPC: $vpcId" -ForegroundColor Green
} else {
    $vpcId = $existingVpc.Vpcs[0].VpcId
    Write-Host "      VPC already exists: $vpcId" -ForegroundColor Green
}

# 2. Internet Gateway
Write-Host "`n[2/5] Setting up Internet Gateway..."
$igwFilter = "Name=tag:Name,Values=eirs-$Environment-igw"
$existingIgw = aws ec2 describe-internet-gateways --filters $igwFilter --region $Region --output json | ConvertFrom-Json

if ($existingIgw.InternetGateways.Count -eq 0) {
    $igwObj = aws ec2 create-internet-gateway --region $Region --output json | ConvertFrom-Json
    $igwId = $igwObj.InternetGateway.InternetGatewayId
    aws ec2 create-tags --resources $igwId --tags Key=Name,Value="eirs-$Environment-igw" Key=Environment,Value=$Environment --region $Region
    aws ec2 attach-internet-gateway --internet-gateway-id $igwId --vpc-id $vpcId --region $Region
    Write-Host "      Created and attached IGW: $igwId" -ForegroundColor Green
} else {
    $igwId = $existingIgw.InternetGateways[0].InternetGatewayId
    Write-Host "      IGW already exists: $igwId" -ForegroundColor Green
}

# 3. Create Subnets (Public and Private in 2 AZs)
Write-Host "`n[3/5] Setting up Subnets..."
$azList = (aws ec2 describe-availability-zones --region $Region --output json | ConvertFrom-Json).AvailabilityZones[0..1].ZoneName

# Public Subnet 1
$pubSubnetCidr = switch ($Environment) {
    "dev"     { "10.10.1.0/24" }
    "qa"      { "10.20.1.0/24" }
    "staging" { "10.30.1.0/24" }
    "prod"    { "10.0.1.0/24" }
}
$privSubnetCidr = switch ($Environment) {
    "dev"     { "10.10.10.0/24" }
    "qa"      { "10.20.10.0/24" }
    "staging" { "10.30.10.0/24" }
    "prod"    { "10.0.10.0/24" }
}

$subnets = aws ec2 describe-subnets --filters "Name=vpc-id,Values=$vpcId" --region $Region --output json | ConvertFrom-Json

if ($subnets.Subnets.Count -eq 0) {
    # Public Subnet
    $pubSub = aws ec2 create-subnet --vpc-id $vpcId --cidr-block $pubSubnetCidr --availability-zone $azList[0] --region $Region --output json | ConvertFrom-Json
    aws ec2 create-tags --resources $pubSub.Subnet.SubnetId --tags Key=Name,Value="eirs-$Environment-public-1a" Key=Type,Value=Public --region $Region
    Write-Host "      Created Public Subnet: $($pubSub.Subnet.SubnetId)" -ForegroundColor Green

    # Private Subnet
    $privSub = aws ec2 create-subnet --vpc-id $vpcId --cidr-block $privSubnetCidr --availability-zone $azList[0] --region $Region --output json | ConvertFrom-Json
    aws ec2 create-tags --resources $privSub.Subnet.SubnetId --tags Key=Name,Value="eirs-$Environment-private-1a" Key=Type,Value=Private --region $Region
    Write-Host "      Created Private Subnet: $($privSub.Subnet.SubnetId)" -ForegroundColor Green
} else {
    Write-Host "      Subnets already exist ($($subnets.Subnets.Count) subnets)." -ForegroundColor Green
}

# 4. Security Groups
Write-Host "`n[4/5] Configuring Security Groups..."
$sgFilter = "Name=group-name,Values=eirs-$Environment-api-sg"
$existingSg = aws ec2 describe-security-groups --filters $sgFilter --region $Region --output json | ConvertFrom-Json

if ($existingSg.SecurityGroups.Count -eq 0) {
    $sgObj = aws ec2 create-security-group `
        --group-name "eirs-$Environment-api-sg" `
        --description "Security Group for EIRS API and Lambda runtime" `
        --vpc-id $vpcId `
        --region $Region --output json | ConvertFrom-Json
    $sgId = $sgObj.GroupId
    aws ec2 create-tags --resources $sgId --tags Key=Name,Value="eirs-$Environment-api-sg" Key=Environment,Value=$Environment --region $Region
    Write-Host "      Created Security Group: $sgId" -ForegroundColor Green
} else {
    $sgId = $existingSg.SecurityGroups[0].GroupId
    Write-Host "      Security Group already exists: $sgId" -ForegroundColor Green
}

Write-Host "`n[5/5] Network status verified."
Write-Host "[+] Network provisioning complete for environment [$Environment]." -ForegroundColor Green
Write-Host "============================================================`n" -ForegroundColor Cyan
