terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-2"
}

# 1. Create the VPC (The Network)
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "Project-VPC"
  }
}

# 2. Create a Subnet (A slice of the network where the server lives)
resource "aws_subnet" "web" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-2a"

  tags = {
    Name = "Web-Subnet"
  }
}

# 3. Create an Internet Gateway (Allows the network to talk to the internet)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
}

# 4. Create a Route Table (Traffic rules)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }
}

# 5. Connect the Subnet to the Internet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.web.id
  route_table_id = aws_route_table.public_rt.id
}
# 6. Security Group (The Firewall) - Allows SSH and Web Traffic
resource "aws_security_group" "allow_web_traffic" {
  name        = "allow_web_traffic"
  description = "Allow Web and SSH inbound traffic"
  vpc_id      = aws_vpc.main.id

  # Allow SSH (Port 22) - So you can log in
  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP (Port 80) - For your future website
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all traffic to leave the server
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# 7. Find the latest Ubuntu Image (The Operating System)
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["099720109477"] # Canonical (The company that makes Ubuntu)
}

# 8. Create the Server (EC2 Instance)
resource "aws_instance" "k8s_server" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t3.micro" # This is Free Tier eligible
  subnet_id     = aws_subnet.web.id
  
  # Attach the Key Pair you downloaded manually
  key_name = "devops-project-key" 

  # Attach the Firewall
  vpc_security_group_ids = [aws_security_group.allow_web_traffic.id]

  # Give it a public IP so you can reach it
  associate_public_ip_address = true

  tags = {
    Name = "My-K8s-Node"
  }
}

# 9. Output the Public IP (So you know where to connect)
output "server_public_ip" {
  value = aws_instance.k8s_server.public_ip
}