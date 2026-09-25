output "vpc_id" {
  description = "VPC ID"
  value       = aws_vpc.main.id
}

output "dynamodb_table_name" {
  description = "DynamoDB Device Registry Table Name"
  value       = aws_dynamodb_table.registry.name
}

output "kms_key_arn" {
  description = "KMS Customer Managed Key ARN"
  value       = aws_kms_key.cmk.arn
}
