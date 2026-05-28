terraform {
  required_version = ">= 1.0.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Generate random JWT secret and Database password if needed, or define them in SSM
resource "random_password" "jwt_secret" {
  length  = 32
  special = false
}

resource "random_password" "mongo_password" {
  length  = 16
  special = false
}

resource "random_id" "suffix" {
  byte_length = 3
}

# --- Module Invocations ---

# 1. Networking Module
module "networking" {
  source                = "./modules/networking"
  vpc_cidr              = var.vpc_cidr
  public_subnet_1_cidr  = var.public_subnet_1_cidr
  public_subnet_2_cidr  = var.public_subnet_2_cidr
  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
  environment           = var.environment
}

# 2. Monitoring Module
module "monitoring" {
  source      = "./modules/monitoring"
  environment = var.environment
  suffix      = random_id.suffix.hex
}

# 3. Compute Module (contains SGs, ASG, ALB, Bastion, MongoDB, and ECR)
module "compute" {
  source                = "./modules/compute"
  vpc_id                = module.networking.vpc_id
  public_subnet_ids     = module.networking.public_subnet_ids
  private_subnet_ids    = module.networking.private_subnet_ids
  public_subnet_1_id    = module.networking.public_subnet_1_id
  private_subnet_1_id   = module.networking.private_subnet_1_id
  key_pair_name         = var.key_pair_name
  my_ip_address         = var.my_ip_address
  instance_profile_name = module.monitoring.ec2_instance_profile_name
  log_group_name        = module.monitoring.log_group_name
  environment           = var.environment
  aws_region            = var.aws_region
  bastion_instance_type = var.bastion_instance_type
  backend_instance_type = var.backend_instance_type
  mongo_instance_type   = var.mongo_instance_type
}

# 4. Storage Module (contains S3 static site, CloudFront CDN, and Redis ElastiCache)
module "storage" {
  source                   = "./modules/storage"
  vpc_id                   = module.networking.vpc_id
  private_subnet_ids       = module.networking.private_subnet_ids
  redis_security_group_ids = [module.compute.redis_security_group_id]
  environment              = var.environment
  suffix                   = random_id.suffix.hex
}


# --- SSM Parameter Store Configuration Setup ---

resource "aws_ssm_parameter" "db_password" {
  name        = "/starttech/database/root_password"
  description = "MongoDB Root Password"
  type        = "SecureString"
  value       = "Password!234" # Set to default or random_password.mongo_password.result
  overwrite   = true
}

resource "aws_ssm_parameter" "jwt_secret" {
  name        = "/starttech/backend/jwt_secret"
  description = "JSON Web Token Secret Key"
  type        = "SecureString"
  value       = random_password.jwt_secret.result
  overwrite   = true
}

resource "aws_ssm_parameter" "redis_endpoint" {
  name        = "/starttech/cache/redis_endpoint"
  description = "ElastiCache Redis primary endpoint host"
  type        = "String"
  value       = module.storage.redis_endpoint
  overwrite   = true
}

resource "aws_ssm_parameter" "mongo_ip" {
  name        = "/starttech/database/mongo_ip"
  description = "MongoDB EC2 Private IP"
  type        = "String"
  value       = module.compute.mongodb_private_ip
  overwrite   = true
}

resource "aws_ssm_parameter" "ecr_registry" {
  name        = "/starttech/backend/ecr_registry"
  description = "Amazon ECR Registry URL prefix"
  type        = "String"
  value       = split("/", module.compute.ecr_repository_url)[0]
  overwrite   = true
}

resource "aws_ssm_parameter" "image_tag" {
  name        = "/starttech/backend/image_tag"
  description = "Current deployed Backend ECR Image Tag"
  type        = "String"
  value       = "latest"
  overwrite   = false # Do not overwrite in terraform apply to prevent resetting deployments
  lifecycle {
    ignore_changes = [value]
  }
}
