resource "aws_launch_configuration" "awslaunch" {
  name = var.aws_launchcfg_name
  image_id = data.aws_ami.amazonlinux.image_id
  instance_type = "t2.micro"
  security_groups = [aws_security_group.awsfw.id]
  associate_public_ip_address = var.aws_publicip
  key_name = aws_key_pair.ssh.key_name
  user_data = var.user_data
 
}

resource "aws_security_group" "awsfw" {
  name = "aws-fw"
  vpc_id = aws_vpc.tfvpc.id

  dynamic "ingress" {
    for_each = local.ingress_config2

    content {
      description = ingress.value.description
      protocol = "tcp"
      to_port = ingress.value.port
      from_port = ingress.value.port
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress {
    description = "allow_all"
    from_port = 0
    protocol = "-1"
    to_port = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_key_pair" "ssh" {
  key_name = "awspublickey"
#  public_key = file("~/testec2.pub") ##please use your public key
  public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDq8ys8EjAAPgl7lSV0DUI2WsHkeoUcVsEu4y8lOd4uUdVY1P/17KHUzPNXmuhRF+mu3prqwtkT6dRGBxwCdFX1oQtgj3c5iyJOAjzbF3fXLWwEhIXR1zh9uVIGB0ci9iwVIPrLA+sDbLJOMyKBkKdmiJKlZiLkgl7DVhw01n656/bpMwrc8Uw6UEgBxKTA0UV96UYr6V8uQ9h4WhpbCHvA5p+866Mqf714Kd3l1NPd2JA0HG5Rgn+i/9NORB7vtZcB/VHOmLyS61S7hciEs7hcnS+773UVqRCXuCjeN0NjN/oZQe2o3ZLCfqtJT4euhPvlf9A8jik/5fQbHxJGE3LOx5AYTxnuPb8i6KnI+nWYTrBGzTYjDcNL/tfybSPHhKSHGwy1/ABg1hC2uc0vzJfHC7ySNwyp/CGWcmwtcuQqz/D4NW00kE/+Qucy/PHGQV5xdM+9b4hDfiOdcRQmlg2QcILbvbWxhyXBC45Emxjm4mdFMtw3/uf+UQYS8ZUWS68= bharathkumarraju@R77-NB193"
  tags = {
    env = "prod"
  }
}

resource "aws_autoscaling_group" "tfasg" {
  name = "tf-asg"
  max_size = 4
  min_size = 2
  launch_configuration = aws_launch_configuration.awslaunch.name
  vpc_zone_identifier = [aws_subnet.web1.id,aws_subnet.web2.id]
  target_group_arns = [aws_lb_target_group.pool.arn]

  tag {
    key = "Name"
    propagate_at_launch = true
    value = "tf-ec2VM"
  }
}

//Network Loadbalancer configuration
resource "aws_lb" "nlb" {
  name = "tf-nlb"
  load_balancer_type = "network"
  enable_cross_zone_load_balancing = true
  subnets = [aws_subnet.web1.id,aws_subnet.web2.id]
}

resource "aws_lb_listener" "frontend" {
  load_balancer_arn = aws_lb.nlb.arn
  port = 80
  protocol = "TCP"
  default_action {
    type = "forward"
    target_group_arn = aws_lb_target_group.pool.arn
  }
}

resource "aws_lb_target_group" "pool" {
  name = "web"
  port = 80
  protocol = "TCP"
  vpc_id = aws_vpc.tfvpc.id
}

//network config
resource "aws_vpc" "tfvpc" {
  cidr_block = "172.20.0.0/16"

}

resource "aws_subnet" "web1" {
      cidr_block = "172.20.10.0/24"
  vpc_id = aws_vpc.tfvpc.id
  availability_zone = element(data.aws_availability_zones.azs.names,0)

  tags = {
    name = "web1"
  }

}

resource "aws_subnet" "web2" {
  cidr_block = "172.20.20.0/24"
  vpc_id = aws_vpc.tfvpc.id
  availability_zone = element(data.aws_availability_zones.azs.names,1)

  tags = {
    name = "web1"
  }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.tfvpc.id

  tags = {
    name = "igw"
  }
}

resource "aws_route" "tfroute" {
  route_table_id = aws_vpc.tfvpc.main_route_table_id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id = aws_internet_gateway.igw.id
}

