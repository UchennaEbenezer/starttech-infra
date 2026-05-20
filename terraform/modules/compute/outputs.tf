output "alb_dns_name" {
  description = "The DNS name of the ALB"
  value       = aws_lb.backend_alb.dns_name
}

output "alb_zone_id" {
  value = aws_lb.backend_alb.zone_id
}

output "asg_name" {
  description = "The name of the Auto Scaling Group"
  value       = aws_autoscaling_group.backend_asg.name
}

output "bastion_public_ip" {
  description = "Public IP of Bastion Host"
  value       = aws_eip.bastion_eip.public_ip
}

output "mongodb_private_ip" {
  description = "Private IP of MongoDB EC2 instance"
  value       = aws_instance.mongodb.private_ip
}

output "redis_security_group_id" {
  description = "ID of the Redis security group"
  value       = aws_security_group.redis_sg.id
}

output "ecr_repository_url" {
  description = "The URL of the ECR Repository"
  value       = aws_ecr_repository.backend.repository_url
}

output "backend_security_group_id" {
  value = aws_security_group.backend_sg.id
}
