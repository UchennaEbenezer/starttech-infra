output "ec2_instance_profile_name" {
  description = "The name of the IAM instance profile for backend EC2 instances"
  value       = aws_iam_instance_profile.ec2_profile.name
}

output "log_group_name" {
  description = "The name of the CloudWatch Log Group for application logging"
  value       = aws_cloudwatch_log_group.backend_logs.name
}
