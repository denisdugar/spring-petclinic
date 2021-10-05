provider "aws" {
  region = "eu-west-1"
}
data "aws_availability_zones" "available" {}

terraform {
  backend "s3" {
    bucket         = "terraform-state-denisdugar141098"
    key            = "global/s3/terraform.tfstate"
    region         = "eu-west-1"
    dynamodb_table = "terraform-up-and-running-locks"
    encrypt        = true
  }
}


resource "aws_alb" "application_load_balancer" {
  name               = "alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = [aws_subnet.pub_subnet_a.id, aws_subnet.pub_subnet_b.id]
  security_groups    = [aws_security_group.load_balancer_security_group.id]
  depends_on         = [aws_vpc.vpc]
}

resource "aws_security_group" "load_balancer_security_group" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  egress {
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_lb_target_group" "target_group" {
  name        = "tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = aws_vpc.vpc.id

  health_check {
    healthy_threshold   = "3"
    interval            = "300"
    protocol            = "HTTP"
    matcher             = "200"
    timeout             = "120"
    path                = "/v1/status"
    unhealthy_threshold = "10"
  }
  depends_on            = [aws_vpc.vpc]
}

resource "aws_lb_listener" "listener" {
  load_balancer_arn = aws_alb.application_load_balancer.id
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.target_group.id
  }
  depends_on         = [aws_vpc.vpc]
}


resource "aws_appautoscaling_target" "ecs_target" {
  max_capacity       = 2
  min_capacity       = 1
  resource_id        = "service/${aws_ecs_cluster.aws-ecs-cluster.name}/${aws_ecs_service.aws-ecs-service.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
  depends_on         = [aws_vpc.vpc]
}

resource "aws_appautoscaling_policy" "ecs_policy_memory" {
  name               = "memory-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageMemoryUtilization"
    }

    target_value = 80
  }
  depends_on         = [aws_vpc.vpc]
}

resource "aws_appautoscaling_policy" "ecs_policy_cpu" {
  name               = "cpu-autoscaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs_target.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs_target.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs_target.service_namespace

  target_tracking_scaling_policy_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }

    target_value = 80
  }
  depends_on         = [aws_vpc.vpc]
}

resource "aws_db_subnet_group" "db_sub_group" {
  name       = "db_group"
  subnet_ids = [aws_subnet.pr_subnet_a.id, aws_subnet.pr_subnet_b.id]
}

data "aws_secretsmanager_secret_version" "db-creds" {
  secret_id = "db-cred"
}

data "aws_secretsmanager_secret_version" "dd-creds" {
  secret_id = "datadog-cred"
}

locals {
  db_creds = jsondecode(data.aws_secretsmanager_secret_version.db-creds.secret_string)
  datadog_creds = jsondecode(data.aws_secretsmanager_secret_version.dd-creds.secret_string)
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
  depends_on                 = [aws_vpc.vpc]
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

resource "aws_iam_role" "ecsTaskExecutionRole" {
  name               = "execution-task-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role_policy.json
}

data "aws_iam_policy_document" "assume_role_policy" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role_policy_attachment" "ecsTaskExecutionRole_policy" {
  role       = aws_iam_role.ecsTaskExecutionRole.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
}

resource "aws_ecs_cluster" "aws-ecs-cluster" {
  name        = "cluster"
  depends_on  = [aws_vpc.vpc]
}

resource "aws_cloudwatch_log_group" "log-group" {
  name = "logs"
}

data "template_file" "user_data" {
  template = "${file("definition.json")}"
  vars = {
    db_url = "${aws_db_instance.petclinic-db.address}"
    cloudw = "${aws_cloudwatch_log_group.log-group.id}"
    api_key = "${local.datadog_creds.api_key}"
  }
}

resource "aws_ecs_task_definition" "aws-ecs-task" {
  family = "task"

  container_definitions = data.template_file.user_data.rendered
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  memory                   = "4096"
  cpu                      = "2048"
  execution_role_arn       = aws_iam_role.ecsTaskExecutionRole.arn
  task_role_arn            = aws_iam_role.ecsTaskExecutionRole.arn
  depends_on               = [aws_vpc.vpc]
}

data "aws_ecs_task_definition" "main" {
  task_definition = aws_ecs_task_definition.aws-ecs-task.family
  depends_on      = [aws_vpc.vpc]
}

resource "aws_ecs_service" "aws-ecs-service" {
  name                 = "ecs-service"
  cluster              = aws_ecs_cluster.aws-ecs-cluster.id
  task_definition      = "${aws_ecs_task_definition.aws-ecs-task.family}:${max(aws_ecs_task_definition.aws-ecs-task.revision, data.aws_ecs_task_definition.main.revision)}"
  launch_type          = "FARGATE"
  scheduling_strategy  = "REPLICA"
  desired_count        = 1
  force_new_deployment = true
  network_configuration {
    subnets          = [aws_subnet.pub_subnet_a.id, aws_subnet.pub_subnet_b.id]
    assign_public_ip     = true
    security_groups = [
      aws_security_group.service_security_group.id,
      aws_security_group.load_balancer_security_group.id
    ]
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.target_group.arn
    container_name   = "container"
    container_port   = 8080
  }

  depends_on = [aws_lb_listener.listener]
}

resource "aws_security_group" "service_security_group" {
  vpc_id = aws_vpc.vpc.id

  ingress {
    from_port       = 0
    to_port         = 0
    protocol        = "-1"
    security_groups = [aws_security_group.load_balancer_security_group.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
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
