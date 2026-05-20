variable "vpc_id" {
  description = "The ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs for ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs for backend ASG and database"
  type        = list(string)
}

variable "public_subnet_1_id" {
  description = "The ID of Public Subnet 1 for Bastion Host"
  type        = string
}

variable "private_subnet_1_id" {
  description = "The ID of Private Subnet 1 for MongoDB"
  type        = string
}

variable "key_pair_name" {
  description = "Name of the EC2 key pair for SSH access"
  type        = string
}

variable "my_ip_address" {
  description = "Your public IP address for Bastion Host SSH access (e.g. 203.0.113.50/32)"
  type        = string
}

variable "instance_profile_name" {
  description = "The IAM instance profile name for the backend EC2 instances"
  type        = string
}

variable "log_group_name" {
  description = "The name of the CloudWatch Log Group for application logging"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "bastion_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "backend_instance_type" {
  type    = string
  default = "t3.micro"
}

variable "mongo_instance_type" {
  type    = string
  default = "t3.small"
}
