provider "aws" {
  region = "eu-central-1"
}

data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

data "aws_ami" "latest_amazon_linux" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}


resource "aws_security_group" "web" {
  vpc_id = aws_vpc.vpc.id
  depends_on  = [aws_vpc.vpc]
  dynamic "ingress" {
    for_each = ["8080", "80", "22"]
    content {
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_launch_configuration" "web" {
  image_id        = data.aws_ami.latest_amazon_linux.id
  instance_type   = "t2.medium"
  security_groups = [aws_security_group.web.id]
  key_name        = "mykey"
  user_data       = <<-EOF
  #!/bin/bash
  apt -y update
  apt -y install nginx
  ufw allow 'Nginx HTTP'
  sudo echo "MY_MYSQL_URL=${aws_db_instance.petclinic-db.address}" >> /etc/environment
  EOF
  depends_on      = [aws_db_instance.petclinic-db]
}



resource "aws_autoscaling_group" "web" {
  launch_configuration = aws_launch_configuration.web.name
  min_size             = 2
  max_size             = 2
  min_elb_capacity     = 2
  health_check_type    = "EC2"
  vpc_zone_identifier  = [aws_subnet.pub_subnet_a.id, aws_subnet.pub_subnet_b.id]
  load_balancers       = [aws_elb.web.name]
  depends_on           = [aws_db_instance.petclinic-db]
  provisioner "local-exec" {
    command = <<-EOF
    ips=""
    ids=""
    while [ "$ids" = "" ]; do
      ids=$(aws autoscaling describe-auto-scaling-groups --auto-scaling-group-names ${aws_autoscaling_group.web.name} --region ${data.aws_region.current.name} --query AutoScalingGroups[].Instances[].InstanceId --output text)
      sleep 1
    done
    for ID in $ids;
    do
      IP=$(aws ec2 describe-instances --instance-ids $ID --region ${data.aws_region.current.name} --query Reservations[].Instances[].PublicIpAddress --output text)
      ips="$ips\n$IP"
    done
    echo "$ips" > /home/denis/ansible/hosts.txt
    EOF
  }
}


resource "aws_elb" "web" {
  subnets               = [aws_subnet.pub_subnet_a.id, aws_subnet.pub_subnet_b.id]
  security_groups       = [aws_security_group.web.id]
  listener {
    lb_port             = 80
    lb_protocol         = "http"
    instance_port       = 8080
    instance_protocol   = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 3
    target              = "HTTP:80/"
    interval            = 10
  }
}

resource "aws_db_subnet_group" "db_sub_group" {
  name       = "db_group"
  subnet_ids = [aws_subnet.pr_subnet_a.id, aws_subnet.pr_subnet_b.id]
}

data "aws_secretsmanager_secret_version" "creds" {
  secret_id = "db-cred"
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.creds.secret_string)
}

resource "aws_db_instance" "petclinic-db" {
  allocated_storage          = 10
  db_subnet_group_name       = aws_db_subnet_group.db_sub_group.id
  engine                     = "mysql"
  engine_version             = "5.7"
  identifier                 = "pet-db"
  instance_class             = "db.t3.micro"
  vpc_security_group_ids     = [aws_security_group.sg_rds.id]
  password                   = local.db_creds.password
  skip_final_snapshot        = true
  storage_encrypted          = true
  username                   = local.db_creds.username
  name                       = local.db_creds.name
  port                       = 3306
}

resource "aws_security_group" "sg_rds" {
  vpc_id        = aws_vpc.vpc.id
}

resource "aws_security_group_rule" "rds_sg_in" {
  security_group_id        = aws_security_group.sg_rds.id
  type                     = "ingress"
  from_port                = 3306
  to_port                  = 3306
  protocol                 = "tcp"
  cidr_blocks              = ["0.0.0.0/0"]
}

resource "aws_vpc" "vpc" {
  cidr_block          = "10.0.0.0/16"
}

resource "aws_subnet" "pub_subnet_a" {
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = "10.0.1.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "pub_subnet_b" {
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[1]
  cidr_block              = "10.0.2.0/24"
  map_public_ip_on_launch = true
}

resource "aws_subnet" "pr_subnet_a" {
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[0]
  cidr_block              = "10.0.10.0/24"
}

resource "aws_subnet" "pr_subnet_b" {
  vpc_id                  = aws_vpc.vpc.id
  availability_zone       = data.aws_availability_zones.available.names[1]
  cidr_block              = "10.0.20.0/24"
}

resource "aws_internet_gateway" "ig" {
  vpc_id = aws_vpc.vpc.id 
}

resource "aws_eip" "nat_eip_1" {
  vpc        = true
  depends_on = [aws_internet_gateway.ig]
}
resource "aws_eip" "nat_eip_2" {
  vpc        = true
  depends_on = [aws_internet_gateway.ig]
}

resource "aws_nat_gateway" "nat_a" {
  allocation_id = aws_eip.nat_eip_1.id
  subnet_id     = aws_subnet.pr_subnet_a.id
  depends_on    = [aws_internet_gateway.ig]
}

resource "aws_nat_gateway" "nat_b" {
  allocation_id = aws_eip.nat_eip_2.id
  subnet_id     = aws_subnet.pr_subnet_b.id
  depends_on    = [aws_internet_gateway.ig]
}

resource "aws_route_table" "route_pub" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.ig.id
  }
}

resource "aws_route_table" "route_pr_a" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_a.id
  }
}

resource "aws_route_table" "route_pr_b" {
  vpc_id = aws_vpc.vpc.id

  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.nat_b.id
  }
}

resource "aws_route_table_association" "pub_a_route" {
  subnet_id      = aws_subnet.pub_subnet_a.id
  route_table_id = aws_route_table.route_pub.id
}
resource "aws_route_table_association" "pub_b_route" {
  subnet_id      = aws_subnet.pub_subnet_b.id
  route_table_id = aws_route_table.route_pub.id
}
resource "aws_route_table_association" "pr_a_route" {
  subnet_id      = aws_subnet.pr_subnet_a.id
  route_table_id = aws_route_table.route_pr_a.id
}
resource "aws_route_table_association" "pr_b_route" {
  subnet_id      = aws_subnet.pr_subnet_b.id
  route_table_id = aws_route_table.route_pr_b.id
}

output "web_loadbalancer_url" {
  value = aws_elb.web.dns_name
}