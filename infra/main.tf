# main.tf - Main terraform configuration file
provider "aws" {
  region = var.aws_region
}

# VPC and Networking
module "vpc" {
  source          = "terraform-aws-modules/vpc/aws"
  name            = "${var.api_name}-vpc"
  cidr            = "10.0.0.0/16"
  azs             = ["${var.aws_region}a", "${var.aws_region}b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]     // ECS containers reside here
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"] // ALB resides here
}

# VPC Endpoints for ECR and S3
resource "aws_vpc_endpoint" "ecr_dkr" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.dkr"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "ecr_api" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.ecr.api"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = module.vpc.vpc_id
  service_name      = "com.amazonaws.${var.aws_region}.s3"
  vpc_endpoint_type = "Gateway"
  route_table_ids   = module.vpc.private_route_table_ids
}

resource "aws_vpc_endpoint" "logs" {
  vpc_id              = module.vpc.vpc_id
  service_name        = "com.amazonaws.${var.aws_region}.logs"
  vpc_endpoint_type   = "Interface"
  subnet_ids          = module.vpc.private_subnets
  security_group_ids  = [aws_security_group.vpc_endpoints.id]
  private_dns_enabled = true
}

# Security Groups
resource "aws_security_group" "vpc_endpoints" {
  name        = "vpc-endponts-sg"
  description = "Allow HTTPS inbound (traffic from ECS) for VPC endpoints"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = [module.vpc.vpc_cidr_block]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ECR Repository for the API image
resource "aws_ecr_repository" "time_api" {
  name         = "${var.api_name}-repo"
  force_delete = true # Easier cleanup :)
}

# ECS Cluster
resource "aws_ecs_cluster" "time_api" {
  name = "${var.api_name}-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "time_api" {
  family                   = "${var.api_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  execution_role_arn       = aws_iam_role.ecs_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "time-api-container"
      image     = "${aws_ecr_repository.time_api.repository_url}:${var.image_tag}"
      essential = true
      portMappings = [{
        containerPort = var.container_port
        hostPort      = var.host_port
      }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.api_name}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "ecs"
        }
      }
      environment = [
        { name = "AWS_REGION", value = var.aws_region },
        { name = "api_name", value = var.api_name }
      ]
      depends_on = [aws_cloudwatch_log_group.time_api]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "time_api" {
  name            = "${var.api_name}-service"
  cluster         = aws_ecs_cluster.time_api.id
  task_definition = aws_ecs_task_definition.time_api.arn
  launch_type     = "FARGATE"
  desired_count   = var.desired_count

  network_configuration {
    subnets          = module.vpc.private_subnets
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.time_api.arn
    container_name   = "${var.api_name}-container"
    container_port   = var.container_port
  }
}

# ALB for API Access
resource "aws_lb" "time_api" {
  name               = "${var.api_name}-lb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.lb.id]
  subnets            = module.vpc.public_subnets
}

resource "aws_lb_target_group" "time_api" {
  name        = "${var.api_name}-tg"
  port        = var.container_port
  protocol    = "HTTP"
  vpc_id      = module.vpc.vpc_id
  target_type = "ip"

  health_check {
    path                = "/health"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 3
    unhealthy_threshold = 3
  }
}

resource "aws_lb_listener" "time_api" {
  load_balancer_arn = aws_lb.time_api.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.time_api.arn
  }
}

resource "aws_security_group" "lb" {
  name        = "${var.api_name}-lb-sg"
  description = "Make the API open to the public"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "ecs_tasks" {
  name        = "${var.api_name}-ecs-tasks-sg"
  description = "Allow inbound traffic from the ALB only"
  vpc_id      = module.vpc.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# IAM Role for ECS
resource "aws_iam_role" "ecs_execution_role" {
  name = "${var.api_name}-ecs-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_execution_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_execution_role.name
}

# CloudWatch Logs
resource "aws_cloudwatch_log_group" "time_api" {
  name              = "/ecs/${var.api_name}"
  retention_in_days = 14
}

# Outputs
output "ecr_repository_url" {
  value = aws_ecr_repository.time_api.repository_url
}

output "ecs_execution_role_arn" {
  value = aws_iam_role.ecs_execution_role.arn
}

output "alb_dns_name" {
  value = aws_lb.time_api.dns_name
}

output "alb_arn" {
  value = aws_lb.time_api.arn
}
