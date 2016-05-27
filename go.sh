#!/usr/bin/env bash
die () {
    echo >&2 "$@"
    exit 1
}

[ "$#" -eq 1 ] || die "1 argument required, $# provided"

terraform remote config -backend=s3 -backend-config="bucket=tts_prod_terraform_state" -backend-config="key=network/terraform.tfstate" -backend-config="region=us-east-1"

ROOT_DIR=`pwd`
ENVIRONMENT_NAME=$1
TIMESTAMP=`date +"%Y-%m-%d_%H-%M-%S"`
echo "Building image at time ${TIMESTAMP}"
terraform apply -var env_name=${ENVIRONMENT_NAME} $ROOT_DIR/terraform/packer
PACKER_SUBNET=`terraform output packer_subnet`
PACKER_VPC=`terraform output packer_vpc`
cd $ROOT_DIR/packer
packer build -machine-readable -var "vpc_id=$PACKER_VPC" -var "subnet_id=$PACKER_SUBNET" -var "ami_name_postfix=$TIMESTAMP" bootstrap_concourse.json | tee build.log
[ ${PIPESTATUS[0]} -eq 0 ] || die "Packer failed, exiting"
$AMI_NAME=`grep 'artifact,0,id' build.log | cut -d, -f6 | cut -d: -f2`
echo $AMI_NAME
cd $ROOT_DIR/terraform/concourse
terraform apply -var ami_name=$AMI_NAME $ROOT_DIR/terraform/concourse
