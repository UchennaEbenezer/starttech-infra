output "cloudfront_domain_name" {
  description = "The static website URL via CloudFront CDN"
  value       = module.storage.cloudfront_domain_name
}

output "alb_dns_name" {
  description = "The API Load Balancer endpoint"
  value       = module.compute.alb_dns_name
}

output "bastion_public_ip" {
  description = "Bastion Host Public IP for management"
  value       = module.compute.bastion_public_ip
}

output "mongodb_private_ip" {
  description = "MongoDB Database server private IP"
  value       = module.compute.mongodb_private_ip
}

output "ecr_repository_url" {
  description = "AWS ECR Registry Repository URL"
  value       = module.compute.ecr_repository_url
}

output "s3_bucket_name" {
  description = "S3 bucket hosting frontend assets"
  value       = module.storage.s3_bucket_name
}

output "cloudfront_distribution_id" {
  value = module.storage.cloudfront_distribution_id
}

output "asg_name" {
  value = module.compute.asg_name
}

output "redis_endpoint" {
  value = module.storage.redis_endpoint
}
