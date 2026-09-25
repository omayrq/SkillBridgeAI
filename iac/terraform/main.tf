terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project     = var.project_name
      Environment = var.environment
      ManagedBy   = "Terraform-Antigravity"
    }
  }
}

# -------------------------------------------------------------
# Layer 5: VPC & Networking
# -------------------------------------------------------------
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "${var.project_name}-${var.environment}-vpc"
  }
}

resource "aws_subnet" "public_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-${var.environment}-public-1a"
  }
}

resource "aws_subnet" "private_1a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.10.0/24"
  availability_zone = "${var.aws_region}a"

  tags = {
    Name = "${var.project_name}-${var.environment}-private-1a"
  }
}

# -------------------------------------------------------------
# Layer 5: KMS Key & Security
# -------------------------------------------------------------
resource "aws_kms_key" "cmk" {
  description             = "EIRS Customer Managed Key for ${var.environment}"
  deletion_window_in_days = 30
  enable_key_rotation     = true
}

resource "aws_kms_alias" "cmk_alias" {
  name          = "alias/${var.project_name}-${var.environment}-cmk"
  target_key_id = aws_kms_key.cmk.key_id
}

# -------------------------------------------------------------
# Layer 4: DynamoDB Registry Table
# -------------------------------------------------------------
resource "aws_dynamodb_table" "registry" {
  name         = "${var.project_name}-${var.environment}-devices"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "PK"
  range_key    = "SK"

  attribute {
    name = "PK"
    type = "S"
  }

  attribute {
    name = "SK"
    type = "S"
  }

  attribute {
    name = "MSISDN"
    type = "S"
  }

  attribute {
    name = "DeviceStatus"
    type = "S"
  }

  global_secondary_index {
    name            = "GSI1-MSISDN"
    hash_key        = "MSISDN"
    projection_type = "ALL"
  }

  global_secondary_index {
    name            = "GSI2-Status"
    hash_key        = "DeviceStatus"
    projection_type = "ALL"
  }

  point_in_time_recovery {
    enabled = true
  }

  server_side_encryption {
    enabled     = true
    kms_key_arn = aws_kms_key.cmk.arn
  }
}
