# --- Guide 20: Optional ElastiCache Redis ---

resource "aws_subnet" "private_data_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.22.0/24"
  availability_zone = "us-east-1b"

  tags = {
    Name = "skin-lesion-learning-dev-private-data-b"
  }
}

resource "aws_security_group" "redis" {
  count       = var.enable_elasticache ? 1 : 0
  name        = "${var.project_name}-redis-${var.environment}"
  description = "Allow Redis only from private app subnets"
  vpc_id      = aws_vpc.main.id

  ingress {
    from_port = 6379
    to_port   = 6379
    protocol  = "tcp"
    cidr_blocks = [
      aws_subnet.private_app_a.cidr_block,
      aws_subnet.private_app_b.cidr_block,
    ]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "redis-cache"
  }
}

resource "aws_elasticache_subnet_group" "redis" {
  count = var.enable_elasticache ? 1 : 0
  name  = "${var.project_name}-redis-${var.environment}"
  subnet_ids = [
    aws_subnet.private_data_a.id,
    aws_subnet.private_data_b.id,
  ]

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_elasticache_parameter_group" "redis_lru" {
  count  = var.enable_elasticache ? 1 : 0
  name   = "${var.project_name}-redis-lru-${var.environment}"
  family = "redis7"

  parameter {
    name  = "maxmemory-policy"
    value = "allkeys-lru"
  }

  tags = {
    Project     = var.project_name
    Environment = var.environment
  }
}

resource "aws_elasticache_replication_group" "redis" {
  count                      = var.enable_elasticache ? 1 : 0
  replication_group_id       = "${var.project_name}-redis-${var.environment}"
  description                = "Skin lesion activation and rate-limit cache"
  node_type                  = var.redis_node_type
  num_cache_clusters         = 1
  port                       = 6379
  subnet_group_name          = aws_elasticache_subnet_group.redis[0].name
  security_group_ids         = [aws_security_group.redis[0].id]
  engine_version             = "7.1"
  parameter_group_name       = aws_elasticache_parameter_group.redis_lru[0].name
  at_rest_encryption_enabled = true
  transit_encryption_enabled = true
  auth_token                 = var.redis_auth_token

  tags = {
    Project     = var.project_name
    Environment = var.environment
    Purpose     = "redis-cache"
  }
}
