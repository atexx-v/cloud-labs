resource "aws_elasticache_subnet_group" "cache" {
  name       = "${var.project}-cache"
  subnet_ids = aws_subnet.private[*].id
}

resource "aws_elasticache_cluster" "cache" {
  cluster_id           = "${var.project}-cache"
  engine               = "redis"
  engine_version       = "7.1"
  node_type            = var.cache_node_type
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.cache.name
  security_group_ids   = [aws_security_group.cache.id]
}
