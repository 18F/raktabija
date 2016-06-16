#!/usr/bin/env bash

die () {
    echo >&2 "$@"
    exit 1
}

config_s3_terraform()
{
    aws s3 mb s3://$1_$2_terraform_state
    terraform remote config -backend=s3 -backend-config="bucket=${1}_${2}_terraform_state" -backend-config="key=network/terraform.tfstate" -backend-config="region=us-east-1"
}

if [ -z ${ENVIRONMENT_NAME+x} ]; then
    [ "$#" -eq 1 ] || die "1 argument required, $# provided"
    ENVIRONMENT_NAME=$1
fi

#Set up some variables
ROOT_DIR=`pwd`
TIMESTAMP=`date +"%Y-%m-%d_%H-%M-%S"`

#Terraform environment for packer to use to create AMI for Concourse box
echo "Building image at time ${TIMESTAMP}"
cd $ROOT_DIR/terraform/packer
config_s3_terraform $ENVIRONMENT_NAME "packer"
terraform apply -var env_name=${ENVIRONMENT_NAME} $ROOT_DIR/terraform/packer
PACKER_SUBNET=`terraform output packer_subnet`
PACKER_VPC=`terraform output packer_vpc`

#Create AMI for Concourse box
export LC_CTYPE=C
GOCD_PASSWORD=$(tr -cd "[:alnum:]" < /dev/urandom | fold -w30 | head -n1)
echo "Credentials for Go: username raktabija, password ${GOCD_PASSWORD}"
cd $ROOT_DIR/packer
packer build -machine-readable -var "vpc_id=${PACKER_VPC}" -var "subnet_id=${PACKER_SUBNET}" -var "ami_name_postfix=${TIMESTAMP}" -var "env_name=${ENVIRONMENT_NAME}" -var "gocd_password=${GOCD_PASSWORD}" bootstrap_concourse.json | tee build.log
[[ ${PIPESTATUS[0]} -eq 0 ]] || die "Packer failed, exiting"
AMI_NAME=`grep 'artifact,0,id' build.log | cut -d, -f6 | cut -d: -f2`
echo $AMI_NAME

#Create Concourse environment in AWS
cd $ROOT_DIR/terraform/concourse
APPNAME=gocd
config_s3_terraform $ENVIRONMENT_NAME "gocd"
terraform apply -var "ami_name=$AMI_NAME" -var "env_name=${ENVIRONMENT_NAME}" $ROOT_DIR/terraform/concourse
