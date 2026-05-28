# IAM Role for EC2
resource "aws_iam_role" "ec2_role" {
  name = "starttech-ec2-role-${var.environment}-${var.suffix}"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    Name        = "starttech-ec2-role-${var.environment}-${var.suffix}"
    Environment = var.environment
  }
}

# Attach CloudWatch Agent Policy
resource "aws_iam_role_policy_attachment" "cw_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# Attach SSM Read Only Access (to retrieve configuration)
resource "aws_iam_role_policy_attachment" "ssm_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMReadOnlyAccess"
}

# Attach ECR Read Only Access (to pull images)
resource "aws_iam_role_policy_attachment" "ecr_policy" {
  role       = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Create IAM Instance Profile
resource "aws_iam_instance_profile" "ec2_profile" {
  name = "starttech-ec2-instance-profile-${var.environment}-${var.suffix}"
  role = aws_iam_role.ec2_role.name
}

# CloudWatch Log Group for Application Container logs
resource "aws_cloudwatch_log_group" "backend_logs" {
  name              = "/aws/ec2/starttech-backend-${var.environment}-${var.suffix}"
  retention_in_days = 7

  tags = {
    Name        = "starttech-backend-logs-${var.environment}-${var.suffix}"
    Environment = var.environment
  }
}
