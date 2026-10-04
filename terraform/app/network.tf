# Мережа (завдання 3).
#
#  Інтернет
#     │
#  [Internet Gateway]
#     │
#  Публічні підмережі (2 зони):  ALB, NAT Gateway
#     │                          (єдине, що має вихід в інтернет напряму)
#  Приватні підмережі (2 зони):  контейнери ECS, база RDS
#                                (без публічних адрес; назовні — лише через NAT)

data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # Дві зони доступності: ALB і група підмереж RDS вимагають мінімум дві
  azs      = slice(data.aws_availability_zones.available.names, 0, 2)
  vpc_cidr = "10.0.0.0/16"
}

resource "aws_vpc" "main" {
  cidr_block = local.vpc_cidr
  # DNS-імена всередині VPC — щоб застосунок знаходив базу за адресою RDS
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.project}-vpc" }
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-igw" }
}

# 10.0.0.0/24, 10.0.1.0/24
resource "aws_subnet" "public" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr, 8, count.index)
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.project}-public-${local.azs[count.index]}" }
}

# 10.0.10.0/24, 10.0.11.0/24
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(local.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]
  tags              = { Name = "${var.project}-private-${local.azs[count.index]}" }
}

# NAT Gateway: контейнери в приватних підмережах ходять через нього назовні
# (стягнути образ з ECR, прочитати секрет, писати логи), але ззовні до них
# підключитись неможливо — NAT пропускає лише відповіді на вихідні з'єднання.
# Один NAT на одну зону — дешевше; ціна: якщо зона впаде, вихід зникне (для лаби прийнятно).
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = { Name = "${var.project}-nat" }
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = { Name = "${var.project}-nat" }

  # Явна залежність: NAT без Internet Gateway не працює
  depends_on = [aws_internet_gateway.main]
}

# Що робить підмережу «публічною» — маршрут 0.0.0.0/0 через Internet Gateway
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = { Name = "${var.project}-public" }
}

# «Приватна» — вихід назовні лише через NAT
resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = { Name = "${var.project}-private" }
}

resource "aws_route_table_association" "public" {
  count          = 2
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = 2
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
