provider "aws" {
    region = "us-east-1"
}

variable "public_key" {}
variable "ami_name" {}
variable "env_name" {}

resource "aws_key_pair" "raktabija" {
  key_name = "raktabija-key" 
  public_key = "${var.public_key}"
}

resource "aws_vpc" "gocd" {
    cidr_block = "10.0.0.0/24"
    tags {
    	 Creator = "Terraform"
	 Project = "Raktabija"
    }
}

resource "aws_s3_bucket" "terraform_state_bucket" {
    bucket = "${var.env_name}_gocd_terraform_state"
    acl = "private"
    versioning {
        enabled = true
    }
    tags {
        Name = "Project"
	Value = "Raktabija"
    }
}

resource "aws_subnet" "gocd_subnet_1" {
    vpc_id = "${aws_vpc.gocd.id}"
    availability_zone = "us-east-1a"
    cidr_block = "10.0.0.0/25"
    map_public_ip_on_launch = false
    tags {
    	 Creator = "Terraform"
	 Project = "Raktabija"
    }
}

resource "aws_subnet" "gocd_subnet_2" {
    vpc_id = "${aws_vpc.gocd.id}"
    availability_zone = "us-east-1c"
    cidr_block = "10.0.0.128/25"
    map_public_ip_on_launch = false
    tags {
    	 Creator = "Terraform"
	 Project = "Raktabija"
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

resource "aws_iam_instance_profile" "gocd_profile" {
    name = "gocd_profile"
    roles = ["${aws_iam_role.ec2_role.name}"]
}

resource "aws_launch_configuration" "gocd_autoscale_conf" {
    image_id = "${var.ami_name}"
    key_name = "${aws_key_pair.raktabija.id}"
    instance_type = "t2.medium"
    iam_instance_profile = "${aws_iam_instance_profile.gocd_profile.arn}"
    security_groups = ["${aws_security_group.allow_bastion.id}", "${aws_security_group.gocd_instance.id}"]
    associate_public_ip_address = true
    lifecycle {
      create_before_destroy = true
    }
    user_data =  <<EOF
#!/usr/bin/env bash
echo "$(curl http://169.254.169.254/latest/meta-data/public-ipv4) $(curl http://169.254.169.254/latest/meta-data/hostname | cut -d. -f1)" >> /etc/hosts
EOF
}

resource "aws_internet_gateway" "gocd_gw" {
  vpc_id = "${aws_vpc.gocd.id}"
  tags {
    Creator = "Terraform"
    Project = "Raktabija"
  }
}

resource "aws_route_table" "gocd_route_table" {
    vpc_id = "${aws_vpc.gocd.id}"
    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.gocd_gw.id}"
    }
    tags {
    	 Creator = "Terraform"
	 Project = "Raktabija"
    }
}

resource "aws_route_table_association" "gocd_route_subnet_1" {
    subnet_id = "${aws_subnet.gocd_subnet_1.id}"
    route_table_id = "${aws_route_table.gocd_route_table.id}"
}

resource "aws_route_table_association" "gocd_route_subnet_2" {
    subnet_id = "${aws_subnet.gocd_subnet_2.id}"
    route_table_id = "${aws_route_table.gocd_route_table.id}"
}

resource "aws_security_group" "load_balancer" {
  name = "load_balancer"
  description = "Allow inbound https"
  vpc_id = "${aws_vpc.gocd.id}"

  ingress {
    from_port = 443
    to_port = 443
    protocol = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 8153
    to_port = 8153
    protocol = "tcp"
    cidr_blocks = ["10.0.0.0/24"]
  }

  tags {
    	 Creator = "Terraform"
	 Project = "Raktabija"
  }
}

resource "aws_security_group" "gocd_instance" {
  name = "gocd_instance"
  description = "Allow inbound gocd connections"
  vpc_id = "${aws_vpc.gocd.id}"

  ingress {
    from_port = 8153
    to_port = 8153
    protocol = "tcp"
    security_groups = [ "${aws_security_group.load_balancer.id}" ]
  }

  tags {
    	 Creator = "Terraform"
	 Project = "Raktabija"
  }
}

resource "aws_security_group" "allow_bastion" {
  name = "allow_bastion"
  description = "Allow inbound ssh, ping and http"
  vpc_id = "${aws_vpc.gocd.id}"

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
	 Project = "Raktabija"
  }
}

resource "aws_elb" "gocd_elb" {
# depends_on = ["${aws_internet_gateway.gocd_gw.id}"]
  name = "terraform-gocd-elb"
  subnets = ["${aws_subnet.gocd_subnet_1.id}", "${aws_subnet.gocd_subnet_2.id}"]
  security_groups = ["${aws_security_group.load_balancer.id}"]

  # We should never use this, but it's mandatory to configure at least one listener
  listener {
    instance_port = 8153
    instance_protocol = "http"
    lb_port = 8153
    lb_protocol = "http"
#    ssl_certificate_id = "arn:aws:iam::123456789012:server-certificate/certName"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "TCP:8153"
    interval = 30
  }

  cross_zone_load_balancing = true
  connection_draining = true
  connection_draining_timeout = 400
  tags {
    Creator = "Terraform"
	 Project = "Raktabija"
  }
}

output "elb_dns_name" {
    value="${aws_elb.gocd_elb.dns_name}"
}

resource "aws_autoscaling_group" "gocd_autoscale" {
  availability_zones = ["us-east-1a", "us-east-1c"]
  max_size = 1
  min_size = 1
  health_check_grace_period = 300
  health_check_type = "EC2"
  desired_capacity = 1
  vpc_zone_identifier = ["${aws_subnet.gocd_subnet_1.id}", "${aws_subnet.gocd_subnet_2.id}"]
  launch_configuration = "${aws_launch_configuration.gocd_autoscale_conf.id}"
  load_balancers = ["${aws_elb.gocd_elb.id}"]
  tag {
    key = "Creator"
    value = "Terraform"
    propagate_at_launch = true
  }
  tag {
    key = "Project"
    value = "Raktabija"
    propagate_at_launch = true
  }
}

resource "aws_sns_topic" "raktabija_updates" {
  name = "raktabija-updates-topic"
}

output "sns_topic_name" {
    value="${aws_sns_topic.raktabija_updates.arn}"
}
