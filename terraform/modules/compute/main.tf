# --- AMI Data Source ---
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# --- ECR Repository ---
resource "aws_ecr_repository" "backend" {
  name                 = "starttech-backend-${var.environment}"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name        = "starttech-backend-ecr-${var.environment}"
    Environment = var.environment
  }
}

# --- Security Groups ---

# 1. Bastion Host Security Group
resource "aws_security_group" "bastion_sg" {
  name        = "starttech-bastion-sg-${var.environment}"
  description = "Security group for Bastion Host"
  vpc_id      = var.vpc_id

  ingress {
    description = "SSH from my IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip_address]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "starttech-bastion-sg-${var.environment}"
    Environment = var.environment
  }
}

# 2. ALB Security Group
resource "aws_security_group" "alb_sg" {
  name        = "starttech-alb-sg-${var.environment}"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    description = "HTTP from anywhere"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from anywhere"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "starttech-alb-sg-${var.environment}"
    Environment = var.environment
  }
}

# 3. Backend EC2 Security Group
resource "aws_security_group" "backend_sg" {
  name        = "starttech-backend-sg-${var.environment}"
  description = "Security group for Backend instances"
  vpc_id      = var.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 8080
    to_port         = 8080
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "starttech-backend-sg-${var.environment}"
    Environment = var.environment
  }
}

# 4. MongoDB Database Security Group
resource "aws_security_group" "mongodb_sg" {
  name        = "starttech-mongodb-sg-${var.environment}"
  description = "Security group for MongoDB Database"
  vpc_id      = var.vpc_id

  ingress {
    description     = "MongoDB from Backend"
    from_port       = 27017
    to_port         = 27017
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  ingress {
    description     = "SSH from Bastion"
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "starttech-mongodb-sg-${var.environment}"
    Environment = var.environment
  }
}

# 5. Redis Security Group
resource "aws_security_group" "redis_sg" {
  name        = "starttech-redis-sg-${var.environment}"
  description = "Security group for Redis ElastiCache"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Redis from Backend"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.backend_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "starttech-redis-sg-${var.environment}"
    Environment = var.environment
  }
}


# --- Compute Instances ---

# 1. Bastion Host (Public Subnet)
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.amazon_linux_2023.id
  instance_type               = var.bastion_instance_type
  subnet_id                   = var.public_subnet_1_id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = var.key_pair_name
  associate_public_ip_address = true

  tags = {
    Name        = "starttech-bastion-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_eip" "bastion_eip" {
  instance = aws_instance.bastion.id
  domain   = "vpc"
  tags = {
    Name        = "starttech-bastion-eip-${var.environment}"
    Environment = var.environment
  }
}

# 2. MongoDB EC2 Instance (Private Subnet)
resource "aws_instance" "mongodb" {
  ami                    = data.aws_ami.amazon_linux_2023.id
  instance_type          = var.mongo_instance_type
  subnet_id              = var.private_subnet_1_id
  vpc_security_group_ids = [aws_security_group.mongodb_sg.id]
  key_name               = var.key_pair_name

  # Provision MongoDB via Docker
  user_data = base64encode(<<-EOF
    #!/bin/bash
    yum update -y
    yum install -y docker aws-cli jq
    systemctl start docker
    systemctl enable docker

    # Fetch DB credentials from SSM or write hardcoded root values for DB boot
    # In production, fetch these passwords dynamically
    DB_USER="root"
    DB_PASS="Password!234"
    DB_NAME="much_todo_db"

    # Start MongoDB container in standalone mode (with authentication enabled)
    docker run -d \
      --name mongodb \
      --restart unless-stopped \
      -p 27017:27017 \
      -v /var/lib/mongodb:/data/db \
      -e MONGO_INITDB_ROOT_USERNAME=$DB_USER \
      -e MONGO_INITDB_ROOT_PASSWORD=$DB_PASS \
      -e MONGO_INITDB_DATABASE=$DB_NAME \
      mongo:8.0 --bind_ip_all
  EOF
  )

  tags = {
    Name        = "starttech-mongodb-${var.environment}"
    Environment = var.environment
  }
}


# --- Application Load Balancer (ALB) ---
resource "aws_lb" "backend_alb" {
  name               = "techcorp-backend-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = var.public_subnet_ids

  tags = {
    Name        = "starttech-alb-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_lb_target_group" "backend_tg" {
  name     = "starttech-backend-tg-${var.environment}"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 20
    matcher             = "200"
  }

  tags = {
    Name        = "starttech-backend-tg-${var.environment}"
    Environment = var.environment
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.backend_alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}


# --- Auto Scaling Group (ASG) ---

# Launch Template for backend EC2 instances
resource "aws_launch_template" "backend_lt" {
  name_prefix   = "starttech-backend-lt-${var.environment}-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.backend_instance_type
  key_name      = var.key_pair_name

  iam_instance_profile {
    name = var.instance_profile_name
  }

  network_interfaces {
    associate_public_ip_address = false
    security_groups             = [aws_security_group.backend_sg.id]
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    # Install Docker and dependencies
    yum update -y
    yum install -y docker aws-cli jq
    systemctl start docker
    systemctl enable docker

    # Define variables
    AWS_DEFAULT_REGION="${var.aws_region}"
    
    echo "Fetching SSM Parameters..."
    
    # Retrieve configuration variables from AWS SSM Parameter Store
    DB_PASSWORD=$(aws ssm get-parameter --name "/starttech/database/root_password" --with-decryption --query "Parameter.Value" --output text --region $AWS_DEFAULT_REGION)
    JWT_SECRET=$(aws ssm get-parameter --name "/starttech/backend/jwt_secret" --with-decryption --query "Parameter.Value" --output text --region $AWS_DEFAULT_REGION)
    REDIS_ENDPOINT=$(aws ssm get-parameter --name "/starttech/cache/redis_endpoint" --query "Parameter.Value" --output text --region $AWS_DEFAULT_REGION)
    MONGO_IP=$(aws ssm get-parameter --name "/starttech/database/mongo_ip" --query "Parameter.Value" --output text --region $AWS_DEFAULT_REGION)
    IMAGE_TAG=$(aws ssm get-parameter --name "/starttech/backend/image_tag" --query "Parameter.Value" --output text --region $AWS_DEFAULT_REGION || echo "latest")
    ECR_REGISTRY=$(aws ssm get-parameter --name "/starttech/backend/ecr_registry" --query "Parameter.Value" --output text --region $AWS_DEFAULT_REGION)
    
    # Authenticate Docker to AWS ECR
    aws ecr get-login-password --region $AWS_DEFAULT_REGION | docker login --username AWS --password-stdin $ECR_REGISTRY
    
    # Target Docker image url
    IMAGE_URL="$ECR_REGISTRY/starttech-backend-${var.environment}:$IMAGE_TAG"
    if [ -z "$ECR_REGISTRY" ]; then
       # Fallback registry path if not set
       IMAGE_URL="${aws_ecr_repository.backend.repository_url}:$IMAGE_TAG"
    fi

    # Pull image
    docker pull $IMAGE_URL

    # Stop and clean existing backend containers
    docker stop starttech-backend || true
    docker rm starttech-backend || true

    # Run Golang API container, utilizing awslogs driver to push stdout/stderr logs to CloudWatch Log Group
    docker run -d \
      --name starttech-backend \
      --restart unless-stopped \
      -p 8080:8080 \
      -e PORT=8080 \
      -e MONGO_URI="mongodb://root:$DB_PASSWORD@$MONGO_IP:27017/much_todo_db?authSource=admin" \
      -e DB_NAME="much_todo_db" \
      -e JWT_SECRET_KEY="$JWT_SECRET" \
      -e ENABLE_CACHE="true" \
      -e REDIS_ADDR="$REDIS_ENDPOINT:6379" \
      -e LOG_LEVEL="INFO" \
      -e LOG_FORMAT="json" \
      --log-driver=awslogs \
      --log-opt awslogs-group="${var.log_group_name}" \
      --log-opt awslogs-stream="backend-instance" \
      --log-opt awslogs-create-group=true \
      $IMAGE_URL
  EOF
  )

  lifecycle {
    create_before_destroy = true
  }

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name        = "starttech-backend-instance-${var.environment}"
      Environment = var.environment
    }
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "backend_asg" {
  name_prefix         = "techcorp-backend-asg-${var.environment}-"
  vpc_zone_identifier = var.private_subnet_ids
  target_group_arns   = [aws_lb_target_group.backend_tg.arn]

  min_size         = 1
  max_size         = 3
  desired_capacity = 2

  force_delete          = true
  health_check_type     = "ELB"
  health_check_grace_period = 300

  launch_template {
    id      = aws_launch_template.backend_lt.id
    version = "$Latest"
  }

  instance_refresh {
    strategy = "Rolling"
    preferences {
      min_healthy_percentage = 50
      instance_warmup        = 300
    }
    triggers = ["tag"]
  }

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "starttech-backend-asg-${var.environment}"
    propagate_at_launch = true
  }

  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
}

# Target Tracking Scaling Policy (Scale based on average CPU utilization)
resource "aws_autoscaling_policy" "cpu_scaling" {
  name                   = "starttech-backend-cpu-scaling-${var.environment}"
  policy_type            = "TargetTrackingScaling"
  autoscaling_group_name = aws_autoscaling_group.backend_asg.name

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }
    target_value = 70.0
  }
}
