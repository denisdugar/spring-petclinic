provider "aws" {
  region = "eu-central-1"
}

data "aws_region" "current" {}
data "aws_availability_zones" "available" {}

data "aws_ami" "ubuntu" {
  owners      = ["099720109477"]
  most_recent = true
  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*"]
  }
}

data "aws_secretsmanager_secret_version" "creds" {
  secret_id = "aws-cred"
}

locals {
  aws_creds = jsondecode(data.aws_secretsmanager_secret_version.creds.secret_string)
}

data "aws_db_instance" "database" {
  db_instance_identifier = "pet-db"
}

resource "aws_default_vpc" "default" {
  tags = {
    Name = "Default VPC"
  }
}


resource "aws_security_group" "build" {
  vpc_id = aws_default_vpc.default.id
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

resource "aws_cloudwatch_metric_alarm" "ec2_cpu" {
     alarm_name                = "cpu-utilization"
     comparison_operator       = "GreaterThanOrEqualToThreshold"
     evaluation_periods        = "2"
     metric_name               = "CPUUtilization"
     namespace                 = "AWS/EC2"
     period                    = "120"
     statistic                 = "Average"
     threshold                 = "80"
     alarm_description         = "This metric monitors ec2 cpu utilization"
     insufficient_data_actions = []
     dimensions                = {       
       InstanceId = aws_instance.build.id     
     }
}

resource "aws_instance" "build" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.xlarge"
  vpc_security_group_ids = [aws_security_group.build.id]
  user_data = <<-EOF
  #!/bin/bash
  sudo apt update
  sudo apt install awscli -y
  sudo apt install maven -y
  sudo apt install docker.io -y 
  aws configure set aws_access_key_id ${local.aws_creds.access_key}
  aws configure set aws_secret_access_key ${local.aws_creds.secret_key}
  aws configure set default.region eu-central-1
  git clone https://github.com/denisdugar/spring-petclinic.git
  sudo echo "MY_MYSQL_URL=${data.aws_db_instance.database.address}" >> /etc/environment
  sed -i "s/localhost/$MY_MYSQL_URL/g" /spring-petclinic/src/main/resources/application-mysql.properties
  (cd /spring-petclinic && ./mvnw package -Dspring-boot.run.profiles=mysql)
  sudo docker build -t my_project /spring-petclinic
  aws ecr get-login-password --region eu-central-1 | sudo docker login --username AWS --password-stdin 966425126302.dkr.ecr.eu-central-1.amazonaws.com
  docker tag my_project:latest 966425126302.dkr.ecr.eu-central-1.amazonaws.com/my_project:latest
  docker push 966425126302.dkr.ecr.eu-central-1.amazonaws.com/my_project:latest
  sleep 1m
  aws ecs stop-task --cluster cluster --task $(aws ecs list-tasks --cluster cluster --service ecs-service --output text --query taskArns[0])
  EOF
}