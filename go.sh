#!/usr/bin/env bash
ROOT_DIR=`pwd`
TIMESTAMP=`date +"%Y-%m-%d_%H-%M-%S"`
echo "Building image at time ${TIMESTAMP}"
cd $ROOT_DIR/terraform/packer
terraform apply
PACKER_SUBNET=`terraform output packer_subnet`
PACKER_VPC=`terraform output packer_vpc`
cd $ROOT_DIR/packer
packer build -var "vpc_id=${PACKER_VPC}" -var "subnet_id=${PACKER_SUBNET}" -var "ami_name_postfix=${TIMESTAMP}" bootstrap_concourse.json
