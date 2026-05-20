output "s3_bucket_name" {
  description = "The name of the frontend hosting S3 bucket"
  value       = aws_s3_bucket.frontend.id
}

output "cloudfront_domain_name" {
  description = "The domain name of the CloudFront CDN distribution"
  value       = aws_cloudfront_distribution.cdn.domain_name
}

output "cloudfront_distribution_id" {
  description = "The ID of the CloudFront distribution"
  value       = aws_cloudfront_distribution.cdn.id
}

output "redis_endpoint" {
  description = "The address of the Redis primary endpoint"
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
}
