# S3 Bucket for Frontend Hosting
resource "aws_s3_bucket" "frontend" {
  bucket_prefix = "starttech-frontend-${var.environment}-"
  force_destroy = true

  tags = {
    Name        = "starttech-frontend-${var.environment}"
    Environment = var.environment
  }
}

# Block Direct Public Access to S3
resource "aws_s3_bucket_public_access_block" "frontend_public_block" {
  bucket                  = aws_s3_bucket.frontend.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# CloudFront Origin Access Control (OAC)
resource "aws_cloudfront_origin_access_control" "oac" {
  name                              = "starttech-oac-${var.environment}"
  description                       = "OAC for StartTech static files hosting"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "cdn" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"

  origin {
    domain_name              = aws_s3_bucket.frontend.bucket_regional_domain_name
    origin_id                = "S3-Frontend"
    origin_access_control_id = aws_cloudfront_origin_access_control.oac.id
  }

  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-Frontend"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
  }

  # SPA Routing Support (Redirect 403 & 404 to index.html with a 200 status code)
  custom_error_response {
    error_code            = 403
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  custom_error_response {
    error_code            = 404
    response_code         = 200
    response_page_path    = "/index.html"
    error_caching_min_ttl = 10
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }

  tags = {
    Name        = "starttech-cdn-${var.environment}"
    Environment = var.environment
  }
}

# S3 Bucket Policy to allow CloudFront Access
resource "aws_s3_bucket_policy" "cloudfront_access" {
  bucket = aws_s3_bucket.frontend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "AllowCloudFrontServicePrincipalReadOnly"
        Effect    = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.frontend.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.cdn.arn
          }
        }
      }
    ]
  })
}

# ElastiCache Redis Subnet Group
resource "aws_elasticache_subnet_group" "redis_subnets" {
  name       = "starttech-redis-subnets-${var.environment}"
  subnet_ids = var.private_subnet_ids
}

# ElastiCache Redis Replication Group
resource "aws_elasticache_replication_group" "redis" {
  replication_group_id        = "starttech-redis-${var.environment}"
  description                 = "StartTech Redis cluster for caching"
  node_type                   = "cache.t4g.micro" # Cost-effective modern type
  num_cache_clusters          = 1                 # Single node replica set (cluster mode disabled)
  parameter_group_name        = "default.redis7"
  port                        = 6379
  subnet_group_name           = aws_elasticache_subnet_group.redis_subnets.name
  security_group_ids          = var.redis_security_group_ids
  at_rest_encryption_enabled  = true
  transit_encryption_enabled = false # Keep encryption simple for local code connectivity

  tags = {
    Name        = "starttech-redis-${var.environment}"
    Environment = var.environment
  }
}
