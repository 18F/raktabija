provider "aws" {}

resource "aws_s3_bucket" "terraform_state_bucket" {
    bucket = "tts_prod_terraform_state"
    acl = "private"
    versioning {
        enabled = true
    }
}

resource "terraform_remote_state" "terraform_state" {
    backend = "s3"
    config {
        bucket = "${aws_s3_bucket.terraform_state_bucket.id}"
        key = "network/terraform.tfstate"
        region = "us-east-1"
    }
}

resource "aws_vpc" "concourse" {
    cidr_block = "10.0.0.0/24"
}

resource "aws_subnet" "concourse_subnet_1" {
    vpc_id = "${aws_vpc.concourse.id}"
    availability_zone = "us-east-1a"
    cidr_block = "10.0.0.0/25"
}

resource "aws_subnet" "concourse_subnet_2" {
    vpc_id = "${aws_vpc.concourse.id}"
    availability_zone = "us-east-1c"
    cidr_block = "10.0.0.128/25"
}

resource "aws_launch_configuration" "concourse_autoscale_conf" {
    image_id = "ami-50759d3d"
    instance_type = "t2.small"

    lifecycle {
      create_before_destroy = true
    }
}

resource "aws_internet_gateway" "councourse_gw" {
  vpc_id = "${aws_vpc.concourse.id}"
}

resource "aws_security_group" "allow_https" {
  name = "allow_https"
  description = "Allow all inbound https"
  vpc_id = "${aws_vpc.concourse.id}"
  ingress {
      from_port = 443
      to_port = 443
      protocol = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
  }

  tags {
    Name = "allow_all"
  }
}

resource "aws_elb" "concourse_elb" {
 depends_on = ["aws_internet_gateway.concourse_gw"]
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
    target = "HTTP:8080/"
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
