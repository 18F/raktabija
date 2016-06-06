#!/usr/bin/env bash
die () {
    echo >&2 "$@"
    exit 1
}

[ "$#" -eq 1 ] || die "1 argument required, $# provided"

ENVIRONMENT_NAME=$1

#Set up some variables
TERRAFORM_CONFIG="terraform remote config -backend=s3 -backend-config='bucket=${ENVIRONMENT_NAME}_terraform_state' -backend-config='key=network/terraform.tfstate' -backend-config='region=us-east-1'"
ROOT_DIR=`pwd`
TIMESTAMP=`date +"%Y-%m-%d_%H-%M-%S"`

#Terraform environment for packer to use to create AMI for Concourse box
echo "Building image at time ${TIMESTAMP}"
cd $ROOT_DIR/terraform/packer
eval $TERRAFORM_CONFIG
terraform apply -var env_name=${ENVIRONMENT_NAME} $ROOT_DIR/terraform/packer
PACKER_SUBNET=`terraform output packer_subnet`
PACKER_VPC=`terraform output packer_vpc`

#Create AMI for Concourse box
cd $ROOT_DIR/packer
packer build -machine-readable -var "vpc_id=${PACKER_VPC}" -var "subnet_id=${PACKER_SUBNET}" -var "ami_name_postfix=${TIMESTAMP}" -var "env_name=${ENVIRONMENT_NAME}" bootstrap_concourse.json | tee build.log
[[ ${PIPESTATUS[0]} -eq 0 ]] || die "Packer failed, exiting"
AMI_NAME=`grep 'artifact,0,id' build.log | cut -d, -f6 | cut -d: -f2`
echo $AMI_NAME

#Create Concourse environment in AWS
cd $ROOT_DIR/terraform/concourse
eval $TERRAFORM_CONFIG
terraform apply -var "ami_name=$AMI_NAME" -var "env_name=${ENVIRONMENT_NAME}" $ROOT_DIR/terraform/concourse
