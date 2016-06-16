# Raktabija

Raktabija bootstraps a new AWS account with a vpc and autoscaling group containing a host that includes:

* A [gocd](https://www.go.cd/) instance that can run terraform. All further changes to the AWS environment can be made through this mechanism.
* Scripts run on a schedule from gocd to delete any AWS resources not included in [Chandika](https://github.com/18F/chandika)

In future, support will be added to run Chaos Monkey against the AWS account.

## Requirements

You'll need the following tools installed to bootstrap Raktabija:

* [Terraform](https://www.terraform.io/)
* [Packer](https://www.packer.io/)
* [AWS CLI](https://aws.amazon.com/cli/)
* An operating system which runs bash

## Installing Raktabija

* Run `aws configure` and enter the credentials for your AWS account
* Type `./go environment_name` at the shell.

The `go` script uses Terraform to set up a VPC which will be used by Packer to build an AMI with Go, Terraform, Packer, and AWS CLI. It then runs Packer to create the AMI. Finally, Terraform sets up a VPC containing an autoscale group with a single instance of the AMI we just created. This instance has the Power User role in the AWS account, which gets picked up by Terraform.

## The origin of the name Raktabija

The demon Raktabija had a superpower that meant that when a drop of his blood hit the ground, a new duplicate Raktabija would be created. Thus when the goddess Kali fought him, every time she wounded him, multiple new Raktabijas would be created. The goddess Chandika helped Kali kill all the clone Raktabijas and eventually killed Raktabija himself. The Chandika app is designed to help you kill the profusion of unused virtual resources that accumulate in a typical cloud environment.

## Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).

> All contributions to this project will be released under the CC0 dedication. By submitting a pull request, you are agreeing to comply with this waiver of copyright interest.
