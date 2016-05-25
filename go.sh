#!/usr/bin/env bash
#TODO: take environment name from args
#TODO: Remote config terraform backend - merge separate backends
#terraform remote config -backend=s3 -backend-config="bucket=tts_prod_terraform_state" -backend-config="key=network/terraform.tfstate" -backend-config="region=us-east-1"

ROOT_DIR=`pwd`
ENVIRONMENT_NAME="tts_prod"
TIMESTAMP=`date +"%Y-%m-%d_%H-%M-%S"`
echo "Building image at time ${TIMESTAMP}"
cd $ROOT_DIR/terraform/packer
terraform apply -var environment_name=${ENVIRONMENT_NAME}
PACKER_SUBNET=`terraform output packer_subnet`
PACKER_VPC=`terraform output packer_vpc`
cd $ROOT_DIR/packer
packer build -var "vpc_id=${PACKER_VPC}" -var "subnet_id=${PACKER_SUBNET}" -var "ami_name_postfix=${TIMESTAMP}" bootstrap_concourse.json
cd $ROOT_DIR/terraform/concourse
#TODO - AMI NAME
terraform apply -var ami_name=$AMI_NAME -var environment_name=${ENVIRONMENT_NAME}

