variable "aws_region" {
  description = "Target AWS Region"
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Deployment Environment (dev, qa, staging, prod)"
  type        = string
  default     = "dev"
}

variable "project_name" {
  description = "Project Name Identifier"
  type        = string
  default     = "eirs"
}
