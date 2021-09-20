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

resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id
  instance_type = "t2.medium"

  user_data = <<-EOF
  #!/bin/bash
  sudo apt update
  sudo apt install awscli -y
  sudo apt install maven -y
  sudo apt install docker -y 
  aws configure set aws_access_key_id ${local.aws_creds.access_key}
  aws configure set aws_secret_access_key ${local.aws_creds.secret_key}
  aws configure set default.region eu-central-1
  git clone https://github.com/denisdugar/spring-petclinic.git
  sed -i "s/localhost/${data.aws_db_instance.database.address}/g" spring-petclinic/src/main/resources/application-mysql.properties
  (cd spring-petclinic && ./mvnw package -Dspring-boot.run.profiles=mysql)
  sudo docker build -t my_project spring-petclinic/
  aws ecr get-login-password --region eu-central-1 | sudo docker login --username AWS --password-stdin 966425126302.dkr.ecr.eu-central-1.amazonaws.com
  docker tag my_project:latest 966425126302.dkr.ecr.eu-central-1.amazonaws.com/my_project:latest
  docker push 966425126302.dkr.ecr.eu-central-1.amazonaws.com/my_project:latest
  EOF
}