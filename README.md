# Raktabija

Raktabija is a way to manage the deployment of systems to AWS, and to delete things that shouldn't be there. It does this by installing and configuring a CI server in your AWS account, which in turn gets a list of what should be deployed to that account from [Chandika](https://github.com/18F/chandika).

Raktabija can be deployed in two ways. If you just want the functionality to delete stuff that shouldn't be there, see the section "Installing Kali Only" below. To obtain the full funcationality, Raktabija will bootstrap a new AWS account with a vpc and autoscaling group containing a host that includes:

* A [gocd](https://www.go.cd/) instance that can run terraform. All further changes to the AWS environment can be made through this mechanism.
* Kali, a script run on a schedule from gocd to delete any AWS resources not included in [Chandika](https://github.com/18F/chandika). Currently we only delete EC2 instances but this will be extended to delete other resources over time.
* A script that configures gocd with a pipeline for each system listed in Chandika for that AWS account. Each pipeline pulls from the `deploy` branch of the Git repository listed in Chandika, and runs a bash script called `deploy` on every change to that branch.

For more on the motivation behind Raktabija, read the blog post [Patterns for managing multi-tenant cloud environments](https://18f.gsa.gov/2016/08/10/patterns-for-managing-multi-tenant-cloud-environments/)

## Requirements

You'll need the following tools installed on your local machine to run Raktabija:

* [Terraform](https://www.terraform.io/)
* [Packer](https://www.packer.io/)
* [AWS CLI](https://aws.amazon.com/cli/)
* An operating system which runs bash

## Installing Raktabija

* Install [Chandika](https://github.com/18F/chandika) before you install Raktabija.
* Set the environment variables `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` and `AWS_DEFAULT_REGION`. The default AMI is configured assuming your default region is `us-east-1` - you'll need to change it if not.
* Run `aws configure list` and ensure it is using the credentials from your environment, as set in the previous step. Bad things will happen if you have previously entered different credentials using `aws configure`.
* Type `./go -n email_address environment_name chandika_host chandika_api_key` at the shell (see the Usage section below for the meaning of these arguments).
* The first time you run Raktabija, look out for two important parameters the script will spit out. First, the credentials to log in to gocd. These will be on a line that begins `Credentials for Go:`. Second, the URL that gocd will be listening on, which will be the last thing the script prints to standard out.

The `go` script uses Terraform to set up a VPC which will be used by Packer to build an AMI with Go, Terraform, Packer, and AWS CLI. It then runs Packer to create the AMI. Finally, Terraform sets up a VPC containing an autoscale group with a single instance of the AMI we just created. This instance has the Power User role in the AWS account, which gets picked up by Terraform running on the instance.

Any further changes to the AWS account, including deployments, can then be made by adding Git repositories to Chandika. Raktabija reconfigures its Go instance daily, creating deployment pipelines for the Git repository listed in Chandika. By convention, it looks for a bash script called `deploy` in the root of a branch called `deploy`. This script should run Terraform to execute changes it wants to make to the AWS environment.

### Usage

Synopsis: `go [-a] [-n email_address] [-s certificate_arn] environment_name chandika_host chandika_api_key`

`environment_name` is a name unique to your environment. It is used (among other things) as a prefix to the S3 bucket name Terraform uses to keep your environment configuration in, so it needs to be unique. `chandika_host` is the hostname you installed Chandika at - Raktabija assumes it's available over https, and that it is installed at the root of the given host.
`chandika_api_key` is a valid API key issued by Chandika. The API key is used to authenticate against Chandika's API.

`email_address` is the address Raktabija will send notifications to for this environment. By default, Raktabija runs a script called Kali which destroys any AWS resources not recorded in Chandika. Raktabija runs Kali in dry run mode on Thursday night at 11pm, and for real on Sunday night at 11pm. Kali sends an email describing what has happened to the email address configured using this setting. It is recommended to create an email group (such as a Google group) to use for this purpose. This only needs to be configured once for the environment.

`-a` bypasses creating an AMI, unless no AMI has been created by Raktabija for this AWS account. You need to create a new AMI if you want to update the Chef configuration for the box Go runs on. However it's not necessary to create a new AMI if you want to change Go's configuration, or if you change the host or API key for Chandika. 

`certificate_arn` is the ARN of an SSL certificate you have already uploaded to AWS. This SSL certificate is used by the ELB that sits in front of the Raktabija instance which hosts gocd. If you do not specify this option, Raktabija will create and upload a self-signed certificate to use for this purpose instead. You can find this self-signed certificate and the private key in the root directory of Raktabija after it has run.

### Making changes to Raktabija's configuration

If you move Chandika to a different host or need to rotate the API key, this can be done by running the `go` script in the root of this repostory, and supplying the new values. You must supply `environment_name` along with `email_address` and `certificate_arn` again if applicable. You can use the `-a` to bypass creating a new AMI. Once this is done, kill any running Raktabija EC2 instances -- new ones with the new Chandika configuration will be created automatically by Raktabija's autoscaling group.

It's only necessary to create a new AMI if you change the base gocd configuration (which is in `packer/cookbooks/gocd/templates/cruise-config.xml.erb`, or if you want to change the packages or Chef configuration of the Raktabija server.

Changes to Kali, along with some other aspects of gocd's configuration, can be made without creating a new machine image, simply by making changes to the scripts in the `scripts` directory.

### Installing Kali Only

If you only want Kali to run, you can have an existing CI server run the Kali script on a schedule. This repository contains a `.travis.yml` configuration file which enables you to point Travis at a clone of the repository. You need to provide the Travis instance with a number of environment variables:

* `CHANDIKA` - The hostname of your Chandika instance.
* `CHANDIKA_API_KEY` - A valid API key from Chandika
* `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` - the credentials to access the AWS account
* `AWS_ACCOUNT_ID` - the AWS account number

You'll also need to set up an SNS topic in this AWS account with the name `raktabija-updates-topic`, and create a subscription which routes messages sent to this topic to an email group so that people using the account can get updates from Kali on what it plans to delete, or has deleted.

Finally, you must [configure Travis to run daily using a cron job](https://docs.travis-ci.com/user/cron-jobs/).

## The origin of the name Raktabija

The demon Raktabija had a superpower that meant that when a drop of his blood hit the ground, a new duplicate Raktabija would be created. Thus when the goddess Kali fought him, every time she wounded him, multiple new Raktabijas would be created. The goddess Chandika helped Kali kill all the clone Raktabijas and eventually killed Raktabija himself. The Chandika app is designed to help you kill the profusion of unused virtual resources that accumulate in a typical cloud environment.

## Public domain

This project is in the worldwide [public domain](LICENSE.md). As stated in [CONTRIBUTING](CONTRIBUTING.md):

> This project is in the public domain within the United States, and copyright and related rights in the work worldwide are waived through the [CC0 1.0 Universal public domain dedication](https://creativecommons.org/publicdomain/zero/1.0/).

> All contributions to this project will be released under the CC0 dedication. By submitting a pull request, you are agreeing to comply with this waiver of copyright interest.
