locals {
  common_tags = {
    Project         = "GamePlatform"
    Environment     = var.environment
    Component       = "Networking"
    ManagedBy       = "terraform"
    TerraformModule = "gameplatform-shared-infrastructure/networking"
  }

  tags = merge(local.common_tags, var.additional_tags)
}

# VPC
module "vpc" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/vpc"

  name                 = "gameplatform-${var.environment}-vpc"
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = var.enable_dns_hostnames
  enable_dns_support   = var.enable_dns_support

  tags = local.tags
}

# Internet Gateway
module "internet_gateway" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/internet-gateway"

  name   = "gameplatform-${var.environment}-igw"
  vpc_id = module.vpc.vpc_id

  tags = local.tags
}

# Public Subnets (use shared module list interface)
module "public_subnets" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/subnet"

  vpc_id = module.vpc.vpc_id
  subnets = [
    for idx, cidr in var.public_subnet_cidrs : {
      name                    = "gameplatform-${var.environment}-public-${idx + 1}"
      cidr_block              = cidr
      availability_zone       = var.availability_zones[idx]
      map_public_ip_on_launch = true
    }
  ]

  tags = merge(local.tags, {
    Type = "Public"
    Tier = "public"
  })
}

# Private Subnets (use shared module list interface)
module "private_subnets" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/subnet"

  vpc_id = module.vpc.vpc_id
  subnets = [
    for idx, cidr in var.private_subnet_cidrs : {
      name                    = "gameplatform-${var.environment}-private-${idx + 1}"
      cidr_block              = cidr
      availability_zone       = var.availability_zones[idx]
      map_public_ip_on_launch = false
    }
  ]

  tags = merge(local.tags, {
    Type = "Private"
    Tier = "private"
  })
}

# Elastic IPs for NAT Gateways
resource "aws_eip" "nat_gateway" {
  count = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0

  domain = "vpc"

  tags = merge(local.tags, {
    Name = "gameplatform-${var.environment}-eip-nat-${count.index + 1}"
    Type = "NAT"
  })

  depends_on = [module.internet_gateway]
}

# NAT Gateways
module "nat_gateways" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/nat-gateway"
  count  = var.enable_nat_gateway ? (var.single_nat_gateway ? 1 : length(var.public_subnet_cidrs)) : 0

  name          = "gameplatform-${var.environment}-nat-${count.index + 1}"
  subnet_id     = module.public_subnets.subnet_ids[count.index]
  allocation_id = aws_eip.nat_gateway[count.index].id

  tags = local.tags
}

# Route Tables for Public Subnets
module "public_route_table" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route-table"

  name   = "gameplatform-${var.environment}-public-rt"
  vpc_id = module.vpc.vpc_id

  routes = [
    {
      cidr_block = "0.0.0.0/0"
      gateway_id = module.internet_gateway.id
    }
  ]

  tags = merge(local.tags, {
    Type = "Public"
  })
}

# Associate public subnets with public route table
resource "aws_route_table_association" "public" {
  count = length(var.public_subnet_cidrs)

  subnet_id      = module.public_subnets.subnet_ids[count.index]
  route_table_id = module.public_route_table.route_table_id
}

# Route Tables for Private Subnets
module "private_route_tables" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/route-table"
  count  = var.enable_nat_gateway ? length(var.private_subnet_cidrs) : 1

  name   = "gameplatform-${var.environment}-private-rt-${count.index + 1}"
  vpc_id = module.vpc.vpc_id

  routes = var.enable_nat_gateway ? [
    {
      cidr_block     = "0.0.0.0/0"
      nat_gateway_id = var.single_nat_gateway ? module.nat_gateways[0].id : module.nat_gateways[count.index].id
    }
  ] : []

  tags = merge(local.tags, {
    Type = "private"
  })
}

# Associate private subnets with private route tables
resource "aws_route_table_association" "private" {
  count = length(var.private_subnet_cidrs)

  subnet_id      = module.private_subnets.subnet_ids[count.index]
  route_table_id = var.enable_nat_gateway ? module.private_route_tables[count.index].route_table_id : module.private_route_tables[0].route_table_id
}

# VPC Flow Logs
module "vpc_flow_logs" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/cloudwatch-log-group"
  count  = var.enable_vpc_flow_logs ? 1 : 0

  name              = "/aws/vpc/flowlogs/${var.environment}"
  retention_in_days = var.vpc_flow_logs_retention

  tags = merge(local.tags, {
    Purpose = "VPC-Flow-Logs"
  })
}

# IAM Role for VPC Flow Logs
module "flow_logs_role" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role"
  count  = var.enable_vpc_flow_logs ? 1 : 0

  name = "gameplatform-${var.environment}-vpc-flow-logs-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
      }
    ]
  })

  tags = local.tags
}

# IAM Policy for VPC Flow Logs
module "flow_logs_policy" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-policy"
  count  = var.enable_vpc_flow_logs ? 1 : 0

  name = "gameplatform-${var.environment}-vpc-flow-logs-policy"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        Resource = "*"
      }
    ]
  })

  tags = local.tags
}

# Attach policy to role
module "flow_logs_role_policy_attachment" {
  source = "github.com/example-gamedev-org/gameplatform-terraform.git//modules/aws/iam-role-policy-attachment"
  count  = var.enable_vpc_flow_logs ? 1 : 0

  role       = module.flow_logs_role[0].name
  policy_arn = module.flow_logs_policy[0].arn
}

# VPC Flow Logs
resource "aws_flow_log" "vpc" {
  count = var.enable_vpc_flow_logs ? 1 : 0

  iam_role_arn    = module.flow_logs_role[0].arn
  log_destination = module.vpc_flow_logs[0].arn
  traffic_type    = "ALL"
  vpc_id          = module.vpc.vpc_id

  tags = merge(local.tags, {
    Name = "gameplatform-${var.environment}-vpc-flow-logs"
  })
}
