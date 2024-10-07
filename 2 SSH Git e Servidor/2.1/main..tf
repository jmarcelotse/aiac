terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = "us-east-2"
}

# Criar a VPC
resource "aws_vpc" "main_vpc" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "ExampleVPC"
  }
}

# Criar uma Subnet Pública
resource "aws_subnet" "public_subnet" {
  vpc_id                  = aws_vpc.main_vpc.id
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true # Isso garante que as instâncias na subnet recebam IP público
  availability_zone       = "us-east-2a"
  tags = {
    Name = "PublicSubnet"
  }
}

# Criar o Internet Gateway para permitir o acesso à Internet
resource "aws_internet_gateway" "main_igw" {
  vpc_id = aws_vpc.main_vpc.id
  tags = {
    Name = "MainIGW"
  }
}

# Criar a Tabela de Roteamento para a VPC
resource "aws_route_table" "public_route_table" {
  vpc_id = aws_vpc.main_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main_igw.id
  }

  tags = {
    Name = "PublicRouteTable"
  }
}

# Associar a Subnet Pública à Tabela de Roteamento
resource "aws_route_table_association" "public_rt_assoc" {
  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.public_route_table.id
}

# Criar o Security Group para liberar apenas a porta SSH (22)
resource "aws_security_group" "ssh_sg" {
  name        = "allow_ssh_only"
  description = "Allow SSH traffic only"
  vpc_id      = aws_vpc.main_vpc.id

  # Regras de entrada (ingress)
  ingress {
    description = "Allow SSH from anywhere"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"] # Permite SSH de qualquer lugar, você pode restringir ao IP necessário
  }

  # Regras de saída (egress) - Permitir todo o tráfego de saída
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AllowSSHOnly"
  }
}

# Criar a Instância EC2 dentro da Subnet Pública
resource "aws_instance" "app_server" {
  ami           = "ami-0ea3c35c5c3284d82"
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.public_subnet.id # Coloca a instância na subnet pública

  # Relacionar o Security Group pela ID à instância
  vpc_security_group_ids = [aws_security_group.ssh_sg.id]

  # Relacionar o par de chaves existente chamado "terraform"
  key_name = "terraform"

  tags = {
    Name = "ExampleAppServerInstance"
  }
}
