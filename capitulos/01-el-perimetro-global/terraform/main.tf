data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

data "aws_ec2_managed_prefix_list" "cloudfront_origin_facing" {
  name = "com.amazonaws.global.cloudfront.origin-facing"
}

data "aws_cloudfront_cache_policy" "caching_disabled" {
  name = "Managed-CachingDisabled"
}

data "aws_cloudfront_origin_request_policy" "all_viewer_except_host" {
  name = "Managed-AllViewerExceptHostHeader"
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  public_subnets = {
    for index, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, index)
  }

  app_subnets = {
    for index, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, index + 10)
  }

  db_subnets = {
    for index, az in local.azs : az => cidrsubnet(var.vpc_cidr, 8, index + 20)
  }
}

# -----------------------------------------------------------------------------
# Red
# -----------------------------------------------------------------------------

resource "aws_vpc" "this" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.project_name}-vpc"
  }
}

resource "aws_internet_gateway" "this" {
  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-igw"
  }
}

resource "aws_subnet" "public" {
  for_each = local.public_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = {
    Name = "${var.project_name}-public-${each.key}"
    Tier = "public"
  }
}

resource "aws_subnet" "app" {
  for_each = local.app_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-app-${each.key}"
    Tier = "application"
  }
}

resource "aws_subnet" "db" {
  for_each = local.db_subnets

  vpc_id                  = aws_vpc.this.id
  availability_zone       = each.key
  cidr_block              = each.value
  map_public_ip_on_launch = false

  tags = {
    Name = "${var.project_name}-db-${each.key}"
    Tier = "database"
  }
}

resource "aws_eip" "nat" {
  for_each = aws_subnet.public
  domain   = "vpc"

  tags = {
    Name = "${var.project_name}-nat-eip-${each.key}"
  }
}

resource "aws_nat_gateway" "this" {
  for_each = aws_subnet.public

  allocation_id = aws_eip.nat[each.key].id
  subnet_id     = each.value.id

  depends_on = [aws_internet_gateway.this]

  tags = {
    Name = "${var.project_name}-nat-${each.key}"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.project_name}-public-rt"
  }
}

resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table" "app" {
  for_each = aws_subnet.app

  vpc_id = aws_vpc.this.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.this[each.key].id
  }

  tags = {
    Name = "${var.project_name}-app-rt-${each.key}"
  }
}

resource "aws_route_table_association" "app" {
  for_each = aws_subnet.app

  subnet_id      = each.value.id
  route_table_id = aws_route_table.app[each.key].id
}

resource "aws_route_table" "db" {
  for_each = aws_subnet.db

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.project_name}-db-rt-${each.key}"
  }
}

resource "aws_route_table_association" "db" {
  for_each = aws_subnet.db

  subnet_id      = each.value.id
  route_table_id = aws_route_table.db[each.key].id
}

# -----------------------------------------------------------------------------
# Security Groups
# -----------------------------------------------------------------------------

resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg"
  description = "Permite trafico desde CloudFront hacia el ALB interno"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "HTTP desde CloudFront origin-facing"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    prefix_list_ids = [data.aws_ec2_managed_prefix_list.cloudfront_origin_facing.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "app" {
  name        = "${var.project_name}-app-sg"
  description = "Permite trafico del ALB hacia las instancias"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "HTTP desde ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "db" {
  name        = "${var.project_name}-db-sg"
  description = "Permite PostgreSQL solo desde la capa de aplicacion"
  vpc_id      = aws_vpc.this.id

  ingress {
    description     = "PostgreSQL desde application tier"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# -----------------------------------------------------------------------------
# Application Load Balancer + Auto Scaling
# -----------------------------------------------------------------------------

resource "aws_lb" "app" {
  name               = substr("${var.project_name}-alb", 0, 32)
  internal           = true
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets            = [for subnet in aws_subnet.app : subnet.id]

  enable_deletion_protection = false

  tags = {
    Name = "${var.project_name}-internal-alb"
  }
}

resource "aws_lb_target_group" "app" {
  name     = substr("${var.project_name}-tg", 0, 32)
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.this.id

  health_check {
    enabled             = true
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200-399"
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.app.arn
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "${var.project_name}-"
  image_id      = data.aws_ami.amazon_linux_2023.id
  instance_type = var.instance_type

  vpc_security_group_ids = [aws_security_group.app.id]

  metadata_options {
    http_endpoint = "enabled"
    http_tokens   = "required"
  }

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -euxo pipefail
    dnf install -y nginx
    cat > /usr/share/nginx/html/index.html <<'HTML'
    <!doctype html>
    <html lang="es">
      <head><meta charset="utf-8"><title>AWS Cloud Odyssey</title></head>
      <body style="font-family:Arial;margin:40px">
        <h1>AWS Cloud Odyssey — Capítulo 01</h1>
        <p>Aplicación desplegada detrás de CloudFront, AWS WAF y un ALB interno.</p>
        <p>Infrastructure as Code por Juan Gutierrez · 2026</p>
      </body>
    </html>
    HTML
    systemctl enable --now nginx
  EOF
  )

  tag_specifications {
    resource_type = "instance"

    tags = {
      Name = "${var.project_name}-app"
    }
  }
}

resource "aws_autoscaling_group" "app" {
  name                = "${var.project_name}-asg"
  min_size            = 2
  desired_capacity    = 2
  max_size            = 4
  vpc_zone_identifier = [for subnet in aws_subnet.app : subnet.id]
  target_group_arns   = [aws_lb_target_group.app.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.project_name}-app"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "cpu" {
  name                   = "${var.project_name}-cpu-target"
  autoscaling_group_name = aws_autoscaling_group.app.name
  policy_type            = "TargetTrackingScaling"

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization"
    }

    target_value = 60
  }
}

# -----------------------------------------------------------------------------
# RDS PostgreSQL Multi-AZ
# -----------------------------------------------------------------------------

resource "random_password" "db" {
  length           = 24
  special          = true
  override_special = "!#$%&*+-_="
}

resource "aws_db_subnet_group" "this" {
  name       = "${var.project_name}-db-subnets"
  subnet_ids = [for subnet in aws_subnet.db : subnet.id]
}

resource "aws_db_instance" "postgres" {
  identifier = substr("${var.project_name}-postgres", 0, 63)

  engine              = "postgres"
  instance_class      = var.db_instance_class
  allocated_storage   = 20
  storage_type        = "gp3"
  storage_encrypted   = true
  multi_az            = true
  publicly_accessible = false

  db_name  = "odyssey"
  username = "odysseyadmin"
  password = random_password.db.result
  port     = 5432

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.db.id]

  backup_retention_period = 7
  deletion_protection      = false
  skip_final_snapshot      = true
  apply_immediately        = true
}

# -----------------------------------------------------------------------------
# AWS WAF en us-east-1 para CloudFront
# -----------------------------------------------------------------------------

resource "aws_wafv2_web_acl" "edge" {
  provider = aws.us_east_1

  name  = "${var.project_name}-waf"
  scope = "CLOUDFRONT"

  default_action {
    allow {}
  }

  rule {
    name     = "AWSManagedRulesCommonRuleSet"
    priority = 10

    override_action {
      count {}
    }

    statement {
      managed_rule_group_statement {
        name        = "AWSManagedRulesCommonRuleSet"
        vendor_name = "AWS"
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-common-rules"
      sampled_requests_enabled   = true
    }
  }

  rule {
    name     = "RateLimitPerIP"
    priority = 20

    action {
      block {}
    }

    statement {
      rate_based_statement {
        aggregate_key_type = "IP"
        limit              = var.waf_rate_limit
      }
    }

    visibility_config {
      cloudwatch_metrics_enabled = true
      metric_name                = "${var.project_name}-rate-limit"
      sampled_requests_enabled   = true
    }
  }

  visibility_config {
    cloudwatch_metrics_enabled = true
    metric_name                = "${var.project_name}-waf"
    sampled_requests_enabled   = true
  }
}

# -----------------------------------------------------------------------------
# CloudFront VPC Origin + Distribution
# -----------------------------------------------------------------------------

resource "aws_cloudfront_vpc_origin" "alb" {
  vpc_origin_endpoint_config {
    name                   = "${var.project_name}-vpc-origin"
    arn                    = aws_lb.app.arn
    http_port              = 80
    https_port             = 443
    origin_protocol_policy = "http-only"

    origin_ssl_protocols {
      items    = ["TLSv1.2"]
      quantity = 1
    }
  }
}

resource "aws_cloudfront_distribution" "app" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "AWS Cloud Odyssey - Capitulo 01"
  price_class     = "PriceClass_100"
  web_acl_id      = aws_wafv2_web_acl.edge.arn

  aliases = var.domain_name == null ? [] : [var.domain_name]

  origin {
    domain_name = aws_lb.app.dns_name
    origin_id   = "internal-alb"

    vpc_origin_config {
      vpc_origin_id          = aws_cloudfront_vpc_origin.alb.id
      origin_keepalive_timeout = 5
      origin_read_timeout      = 30
    }
  }

  default_cache_behavior {
    target_origin_id       = "internal-alb"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]

    cache_policy_id          = data.aws_cloudfront_cache_policy.caching_disabled.id
    origin_request_policy_id = data.aws_cloudfront_origin_request_policy.all_viewer_except_host.id
    compress                 = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    cloudfront_default_certificate = var.domain_name == null
    acm_certificate_arn            = var.domain_name == null ? null : aws_acm_certificate_validation.cloudfront[0].certificate_arn
    ssl_support_method             = var.domain_name == null ? null : "sni-only"
    minimum_protocol_version       = var.domain_name == null ? "TLSv1" : "TLSv1.2_2021"
  }
}

# -----------------------------------------------------------------------------
# Dominio opcional: ACM us-east-1 + Route 53
# -----------------------------------------------------------------------------

resource "aws_acm_certificate" "cloudfront" {
  count    = var.domain_name == null ? 0 : 1
  provider = aws.us_east_1

  domain_name       = var.domain_name
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_route53_record" "acm_validation" {
  for_each = var.domain_name == null ? {} : {
    for dvo in aws_acm_certificate.cloudfront[0].domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  ttl     = 60
  records = [each.value.record]
}

resource "aws_acm_certificate_validation" "cloudfront" {
  count    = var.domain_name == null ? 0 : 1
  provider = aws.us_east_1

  certificate_arn         = aws_acm_certificate.cloudfront[0].arn
  validation_record_fqdns = [for record in aws_route53_record.acm_validation : record.fqdn]
}

resource "aws_route53_record" "app" {
  count = var.domain_name == null ? 0 : 1

  zone_id = var.hosted_zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.app.domain_name
    zone_id                = aws_cloudfront_distribution.app.hosted_zone_id
    evaluate_target_health = false
  }
}
