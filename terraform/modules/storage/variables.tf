variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "private_subnet_ids" {
  description = "The list of private subnets for Redis"
  type        = list(string)
}

variable "redis_security_group_ids" {
  description = "Security groups for Redis"
  type        = list(string)
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}
