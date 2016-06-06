provider "aws" {
    region = "us-east-1"
}
variable "public_key" {}
variable "ami_name" {}
variable "concourse_username" {}
variable "concourse_password" {}
variable "env_name" {}

resource "aws_key_pair" "raktabija" {
  key_name = "raktabija-key" 
  public_key = "${var.public_key}"
}

resource "aws_vpc" "concourse" {
    cidr_block = "10.0.0.0/24"
    tags {
    	 Creator = "Terraform"
    }
}

resource "aws_s3_bucket" "terraform_state_bucket" {
    bucket = "${var.env_name}_terraform_state"
    acl = "private"
    versioning {
        enabled = true
    }
}

resource "aws_subnet" "concourse_subnet_1" {
    vpc_id = "${aws_vpc.concourse.id}"
    availability_zone = "us-east-1a"
    cidr_block = "10.0.0.0/25"
    map_public_ip_on_launch = false
    tags {
    	 Creator = "Terraform"
    }
}

resource "aws_subnet" "concourse_subnet_2" {
    vpc_id = "${aws_vpc.concourse.id}"
    availability_zone = "us-east-1c"
    cidr_block = "10.0.0.128/25"
    map_public_ip_on_launch = false
    tags {
    	 Creator = "Terraform"
    }
}

resource "aws_iam_role" "ec2_role" {
    name = "ec2_role"
    assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": { "Service": "ec2.amazonaws.com" },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_iam_role_policy" "power_user_policy" {
    name = "power_user_policy"
    role = "${aws_iam_role.ec2_role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "NotAction": "iam:*",
      "Resource": "*"
    }
  ]
}
EOF
}

resource "aws_iam_instance_profile" "concourse_profile" {
    name = "concourse_profile"
    roles = ["${aws_iam_role.ec2_role.name}"]
}

resource "aws_launch_configuration" "concourse_autoscale_conf" {
    image_id = "${var.ami_name}"
    key_name = "${aws_key_pair.raktabija.id}"
    instance_type = "t2.small"
    iam_instance_profile = "${aws_iam_instance_profile.concourse_profile.arn}"
    security_groups = ["${aws_security_group.allow_bastion.id}"]
    associate_public_ip_address = true
    lifecycle {
      create_before_destroy = true
    }
    user_data =  <<EOF
username: ${var.concourse_username}
password: ${var.concourse_password}
env_name: ${var.env_name}
EOF
}

resource "aws_internet_gateway" "concourse_gw" {
  vpc_id = "${aws_vpc.concourse.id}"
  tags {
    Creator = "Terraform"
  }
}

resource "aws_route_table" "concourse_route_table" {
    vpc_id = "${aws_vpc.concourse.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.concourse_gw.id}"
    }
    tags {
    	 Creator = "Terraform"
    }
}

resource "aws_route_table_association" "concourse_route_subnet_1" {
    subnet_id = "${aws_subnet.concourse_subnet_1.id}"
    route_table_id = "${aws_route_table.concourse_route_table.id}"
}

resource "aws_route_table_association" "concourse_route_subnet_2" {
    subnet_id = "${aws_subnet.concourse_subnet_2.id}"
    route_table_id = "${aws_route_table.concourse_route_table.id}"
}

resource "aws_security_group" "allow_bastion" {
  name = "allow_bastion"
  description = "Allow inbound ssh, ping and http"
  vpc_id = "${aws_vpc.concourse.id}"

  ingress {
    from_port = 80
    to_port = 80
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    from_port = 22
    to_port = 22
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
      from_port = 8
      to_port = 0
      protocol = "icmp"
      cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    	 Creator = "Terraform"
  }
}

resource "aws_elb" "concourse_elb" {
# depends_on = ["${aws_internet_gateway.concourse_gw.id}"]
  name = "terraform-concourse-elb"
  subnets = ["${aws_subnet.concourse_subnet_1.id}", "${aws_subnet.concourse_subnet_2.id}"]
  security_groups = ["${aws_security_group.allow_bastion.id}"]

  listener {
    instance_port = 8080
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
#    ssl_certificate_id = "arn:aws:iam::123456789012:server-certificate/certName"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:8080/"
    interval = 30
  }

  cross_zone_load_balancing = true
  connection_draining = true
  connection_draining_timeout = 400
  tags {
    Creator = "Terraform"
  }
}

resource "aws_autoscaling_group" "concourse_autoscale" {
  availability_zones = ["us-east-1a", "us-east-1c"]
  max_size = 1
  min_size = 1
  health_check_grace_period = 300
  health_check_type = "EC2"
  desired_capacity = 1
  vpc_zone_identifier = ["${aws_subnet.concourse_subnet_1.id}", "${aws_subnet.concourse_subnet_2.id}"]
  launch_configuration = "${aws_launch_configuration.concourse_autoscale_conf.id}"
  load_balancers = ["${aws_elb.concourse_elb.id}"]
  tag {
    key = "Creator"
    value = "Terraform"
    propagate_at_launch = true
  }
}
