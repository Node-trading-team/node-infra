# VPC
resource "aws_vpc" "main" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support = true

  tags = {
    Name = "mongodb-vpc"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id
  tags = {
    Name = "mongodb-igw"
  }
}

# Public Subnet
resource "aws_subnet" "public" {
  vpc_id = aws_vpc.main.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "${var.aws_region}a"
  map_public_ip_on_launch = true

  tags = {
    Name = "mongodb-public-subnet"
  }
}

# Route Table
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  # 외부로부터 오는 모든 트래픽을 IG로 보냄
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "mongodb-public-rt"
  }
}

# Route Table과 Subnet 연결
resource "aws_route_table_association" "a" {
  subnet_id = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# Security Group
resource "aws_security_group" "mongodb_sg" {
  name = "mongodb-server-sg"
  vpc_id = aws_vpc.main.id

  ingress {
    from_port = 27017
    to_port = 27017
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "mongodb-sg"
  }
}

data "aws_iam_policy_document" "ec2_assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2_role" {
  name = "mongodb-ec2-role"

  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role_policy.json
}

# EC2 role에 AmazonS3FullAccess 정책 부착
resource "aws_iam_role_policy_attachment" "s3_full_access" {
  role = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

# EC2 role에 AmazonEC2RoleforSSM 정책 부착
resource "aws_iam_role_policy_attachment" "ec2_ssm" {
  role = aws_iam_role.ec2_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2RoleforSSM"
}

# IAM 인스턴스 프로파일 생성
resource "aws_iam_instance_profile" "instance_profile" {
  name = "mongodb-instance-profile"
  role = aws_iam_role.ec2_role.name
}

# Amazon Linux AMI 동적으로 조회
data "aws_ami" "amazon_linux_2" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

# EC2
resource "aws_instance" "mongodb_server" {
  ami = data.aws_ami.amazon_linux_2.id
  instance_type = var.instance_type
  iam_instance_profile = aws_iam_instance_profile.instance_profile.name
  
  subnet_id = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.mongodb_sg.id]

  # 인스턴스가 부팅 시 MongoDB 설치 스크립트 수행
  user_data = templatefile("${path.module}/install_mongodb.tftpl", {
    mongo_user = var.mongodb_admin_user
    mongo_password = var.mongodb_admin_password
  })

  tags = {
    Name = "MongoDB-Server"
  }
}
