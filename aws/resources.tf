data "aws_availability_zones" "available" { }

resource "aws_vpc" "vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.name}-vpc"
  }
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.vpc.id
  cidr_block = cidrsubnet(
    var.vpc_cidr,
    24 - replace(var.vpc_cidr, "/[^/]*[/]/", ""),
    0
  )
  map_public_ip_on_launch = true
  availability_zone       = element(data.aws_availability_zones.available.names, 0)

  tags = {
    Name = "${var.name}-subnet"
  }
}

resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "${var.name}-rt"
  }
}

resource "aws_main_route_table_association" "a" {
  vpc_id         = aws_vpc.vpc.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_route_table_association" "rta" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.rt.id
}

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.vpc.id

  tags = {
    Name = "${var.name}-gw"
  }
}

locals {
  root_volume_type = "gp2"
  root_volume_size = "50"
  volume_delete_on_termination = true
}

resource "aws_key_pair" "key_pair" {
  key_name   = var.key_pair_name
  public_key = var.public_key
}

resource "aws_instance" "server" {
  ami                         = data.aws_ami.nodes.id
  instance_type               = var.instance_type
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sg.id]
  subnet_id                   = aws_subnet.public.id
  
  key_name = var.key_pair_name

  tags = {
    Name = var.name
  }

  volume_tags = {
    Name = "${var.name}-volume"
  }

  user_data = data.template_cloudinit_config.init.rendered

  # OS
  root_block_device {
    volume_type           = local.root_volume_type
    volume_size           = local.root_volume_size
    delete_on_termination = local.volume_delete_on_termination
  }
}
