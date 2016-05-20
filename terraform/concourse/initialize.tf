provider "aws" {}

resource "aws_s3_bucket" "terraform_state_bucket" {
    bucket = "tts_prod_terraform_state"
    acl = "private"
    versioning {
        enabled = true
    }
}

resource "aws_key_pair" "raktabija" {
  key_name = "raktabija-key" 
  public_key = "${var.public_key}"
}

resource "aws_vpc" "concourse" {
    cidr_block = "10.0.0.0/24"
}

resource "aws_subnet" "concourse_subnet_1" {
    vpc_id = "${aws_vpc.concourse.id}"
    availability_zone = "us-east-1a"
    cidr_block = "10.0.0.0/25"
    map_public_ip_on_launch = false
}

resource "aws_subnet" "concourse_subnet_2" {
    vpc_id = "${aws_vpc.concourse.id}"
    availability_zone = "us-east-1c"
    cidr_block = "10.0.0.128/25"
    map_public_ip_on_launch = false
}

resource "aws_launch_configuration" "concourse_autoscale_conf" {
    image_id = "ami-50759d3d"
    key_name = "${aws_key_pair.raktabija.id}"
    instance_type = "t2.small"
    security_groups = ["${aws_security_group.allow_bastion.id}"]
    associate_public_ip_address = true
    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_internet_gateway" "councourse_gw" {
  vpc_id = "${aws_vpc.concourse.id}"
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
    Name = "allow_all"
  }
}

resource "aws_elb" "concourse_elb" {
# depends_on = ["${aws_internet_gateway.concourse_gw.id}"]
  name = "foobar-terraform-elb"
  subnets = ["${aws_subnet.concourse_subnet_1.id}", "${aws_subnet.concourse_subnet_2.id}"]

  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
#    ssl_certificate_id = "arn:aws:iam::123456789012:server-certificate/certName"
  }

  health_check {
    healthy_threshold = 2
    unhealthy_threshold = 2
    timeout = 3
    target = "HTTP:80/"
    interval = 30
  }

  cross_zone_load_balancing = true
  idle_timeout = 400
  connection_draining = true
  connection_draining_timeout = 400
}


resource "aws_autoscaling_group" "concourse_autoscale" {
  availability_zones = ["us-east-1a", "us-east-1c"]
  max_size = 1
  min_size = 1
  health_check_grace_period = 300
  health_check_type = "ELB"
  desired_capacity = 1
  vpc_zone_identifier = ["${aws_subnet.concourse_subnet_1.id}", "${aws_subnet.concourse_subnet_2.id}"]
  launch_configuration = "${aws_launch_configuration.concourse_autoscale_conf.id}"
  load_balancers = ["${aws_elb.concourse_elb.id}"]
}
