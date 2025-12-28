# ------------------------------------------------------------------------------
# 1. NETWORKING (VPC, Subnets, Gateways)
# ------------------------------------------------------------------------------
data "aws_availability_zones" "available" {}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = { Name = "ws-ha-vpc" }
}

# Subnets Públicas (Para ALB y NAT)
resource "aws_subnet" "public" {
  count                   = 2
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  map_public_ip_on_launch = true

  tags = { Name = "ws-ha-public-${count.index + 1}" }
}

# Subnets Privadas (Para EC2 Apps y RDS)
resource "aws_subnet" "private" {
  count             = 2
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 2)
  availability_zone = data.aws_availability_zones.available.names[count.index]

  tags = { Name = "ws-ha-private-${count.index + 1}" }
}

# Internet Gateway (Salida para subnets públicas)
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
}

# NAT Gateway (Salida segura para subnets privadas)
resource "aws_eip" "nat" {
  domain = "vpc"
}

resource "aws_nat_gateway" "nat" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id # Se aloja en la pública

  depends_on = [aws_internet_gateway.igw]
}

# Tablas de Rutas
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat.id
  }
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

# ------------------------------------------------------------------------------
# 2. SECURITY GROUPS (Firewalls)
# ------------------------------------------------------------------------------

# SG para el Load Balancer (Acepta HTTP del mundo)
resource "aws_security_group" "alb_sg" {
  name        = "ws-ha-alb-sg"
  vpc_id      = aws_vpc.main.id

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

# SG para las Instancias EC2 (Solo acepta tráfico del ALB)
resource "aws_security_group" "app_sg" {
  name        = "ws-ha-app-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# SG para RDS (Solo acepta tráfico de las Instancias EC2)
resource "aws_security_group" "db_sg" {
  name        = "ws-ha-db-sg"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "MySQL from App"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.app_sg.id]
  }
}

# ------------------------------------------------------------------------------
# 3. APPLICATION LOAD BALANCER (ALB)
# ------------------------------------------------------------------------------
resource "aws_lb" "main" {
  name               = "ws-ha-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = aws_subnet.public[*].id
}

resource "aws_lb_target_group" "main" {
  name     = "ws-ha-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path                = "/"
    healthy_threshold   = 2
    unhealthy_threshold = 10
  }
}

resource "aws_lb_listener" "front_end" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
}

# ------------------------------------------------------------------------------
# 4. COMPUTE (Launch Template & Auto Scaling)
# ------------------------------------------------------------------------------
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_launch_template" "app" {
  name_prefix   = "ws-ha-lt-"
  image_id      = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type

  network_interfaces {
    associate_public_ip_address = false # Privada
    security_groups             = [aws_security_group.app_sg.id]
  }

  # User Data codificado en Base64 (Llama a Ansible)
  user_data = filebase64("${path.module}/user_data.sh")

  tag_specifications {
    resource_type = "instance"
    tags = {
      Name = "ws-ha-instance"
    }
  }
}

resource "aws_autoscaling_group" "main" {
  name                = "ws-ha-asg"
  vpc_zone_identifier = aws_subnet.private[*].id # Instancias en redes privadas
  target_group_arns   = [aws_lb_target_group.main.arn]
  health_check_type   = "ELB"
  
  # Capacidad (Escalabilidad)
  min_size         = 2
  max_size         = 4
  desired_capacity = 2

  launch_template {
    id      = aws_launch_template.app.id
    version = "$Latest"
  }

  # Refrescar instancias si cambia el Launch Template
  instance_refresh {
    strategy = "Rolling"
  }
}

# ------------------------------------------------------------------------------
# 5. DATABASE (RDS MySQL)
# ------------------------------------------------------------------------------
resource "aws_db_subnet_group" "main" {
  name       = "ws-ha-db-subnet-group"
  subnet_ids = aws_subnet.private[*].id

  tags = { Name = "My DB subnet group" }
}

resource "aws_db_instance" "default" {
  allocated_storage      = 10
  db_name                = "webappdb"
  engine                 = "mysql"
  engine_version         = "8.0"
  instance_class         = "db.t3.micro"
  username               = "admin"
  password               = var.db_password
  parameter_group_name   = "default.mysql8.0"
  skip_final_snapshot    = true # Solo para lab, en prod debe ser false
  vpc_security_group_ids = [aws_security_group.db_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.main.name
  multi_az               = false 
}
