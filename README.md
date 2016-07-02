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

* Install [Chandika](https://github.com/18F/chandika) before you install Raktabija.
* Set the environment variables `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_DEFAULT_REGION`. The default AMI is configured assuming your default region is `us-east-1` - you'll need to change it if not.
* Run `aws configure list` and ensure it is using the credentials from your environment, as set in the previous step. Bad things will happen if you have previously entered different credentials using `aws configure`.
* Type `./go -i email_address environment_name chandika_host` at the shell (see the Usage section below for the meaning of these arguments).

The `go` script uses Terraform to set up a VPC which will be used by Packer to build an AMI with Go, Terraform, Packer, and AWS CLI. It then runs Packer to create the AMI. Finally, Terraform sets up a VPC containing an autoscale group with a single instance of the AMI we just created. This instance has the Power User role in the AWS account, which gets picked up by Terraform.

### Usage

Synopsis: `go [-a] [-i email_address] environment_name chandika_host`

`environment_name` is a name unique to your environment. It is used (among other things) as a prefix to the S3 bucket name Terraform uses to keep your environment configuration in, so it needs to be unique. `chandika_host` is the hostname you installed Chandika at - Raktabija assumes it's avaiable over https, and that it is installed at the root of the given host.

`email_address` is the address Raktabija will send notifications to for this environment. By default, Raktabija runs a script called Kali which destroys any AWS resources not recorded in Chandika. By default Raktabija runs Kali in dry run mode on Thursday night at 11pm, and for real on Sunday night at 11pm. Kali sends an email describing what has happened to the email address configured using this setting. It is recommended to create an email group (such as a Google group) to use for this purpose. This only needs to be configured once for the environment.

`-a` bypasses creating an AMI, unless no AMI has been created by Raktabija for this AWS account. You need to create a new AMI if you want to update the Chef configuration for the box Go runs on. However it's not necessary to create a new AMI if you want to change Go's configuration.

## The origin of the name Raktabija

The demon Raktabija had a superpower that meant that when a drop of his blood hit the ground, a new duplicate Raktabija would be created. Thus when the goddess Kali fought him, every time she wounded him, multiple new Raktabijas would be created. The goddess Chandika helped Kali kill all the clone Raktabijas and eventually killed Raktabija himself. The Chandika app is designed to help you kill the profusion of unused virtual resources that accumulate in a typical cloud environment.

## Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).

> All contributions to this project will be released under the CC0 dedication. By submitting a pull request, you are agreeing to comply with this waiver of copyright interest.
