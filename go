#!/usr/bin/env bash
USAGE="Usage: go [-a] [-s server_certificate_arn] [-n notifications_email_address] environment_name chandika_url"

die () {
    echo >&2 "$@"
    exit 1
}

config_s3_terraform()
{
    aws s3 mb s3://$1_$2_terraform_state
    cd $ROOT_DIR/terraform/$2
    rm -rf .terraform
    terraform remote config -backend=s3 -backend-config="bucket=${1}_${2}_terraform_state" -backend-config="key=network/terraform.tfstate" -backend-config="region=us-east-1"
}

# See if there's already an SSL cert uploaded for Go

SSL_CERT_ARN=`aws iam get-server-certificate --server-certificate-name terraform-gocd-elb --query 'ServerCertificate.ServerCertificateMetadata.{Arn:Arn}' --output text 2> /dev/null`
# Get command line args
OPTINT=1
while getopts ":as:n:" opt; do
    case $opt in
	a)
	    CREATEAMI=0
	    ;;
	s)
	    SSL_CERT_ARN=$OPTARG
	    ;;
	n)
	    NOTIFICATIONS_EMAIL=$OPTARG
	    ;;
	\?) die $USAGE
	    ;;
    esac
done
shift $((OPTIND-1))

if [[ -z ${ENVIRONMENT_NAME+x} || -z ${CHANDIKA+x} ]]; then
    [[ "$#" -eq 2 ]] || die $USAGE
    ENVIRONMENT_NAME=$1
    CHANDIKA=$2
fi
ROOT_DIR=`pwd`

#Terraform environment for packer to use to create AMI for Concourse box
config_s3_terraform $ENVIRONMENT_NAME "packer"
terraform apply -var env_name=${ENVIRONMENT_NAME} $ROOT_DIR/terraform/packer
PACKER_SUBNET=`terraform output packer_subnet`
PACKER_VPC=`terraform output packer_vpc`

#Create AMI for Concourse box
AMI_NAME=`aws ec2 describe-images --owners self --filters Name=tag:Environment,Values=${ENVIRONMENT_NAME} Name=tag:Creator,Values=packer --query 'Images[*].{DATE:CreationDate,ID:ImageId}' --output text | sort -r | cut -f 2 | head -n1`
if [[ -z $AMI_NAME || $CREATEAMI ]]; then
    export LC_CTYPE=C
    GOCD_PASSWORD=$(tr -cd "[:alnum:]" < /dev/urandom | fold -w30 | head -n1)
    cd $ROOT_DIR/packer
    packer build -machine-readable -var "vpc_id=${PACKER_VPC}" -var "subnet_id=${PACKER_SUBNET}" -var "env_name=${ENVIRONMENT_NAME}" -var "gocd_password=${GOCD_PASSWORD}" bootstrap_concourse.json | tee build.log
    [[ ${PIPESTATUS[0]} -eq 0 ]] || die "Packer failed, exiting"
    AMI_NAME=`grep 'artifact,0,id' build.log | cut -d, -f6 | cut -d: -f2`
    echo "Credentials for Go: username raktabija, password ${GOCD_PASSWORD}"
fi
echo $AMI_NAME

#Create Go.CD environment in AWS
config_s3_terraform $ENVIRONMENT_NAME "gocd"
terraform apply -var "ami_name=$AMI_NAME" -var "env_name=${ENVIRONMENT_NAME}" -var "chandika=${CHANDIKA}" $ROOT_DIR/terraform/gocd || die "Terraform failed"
ELB_DNS_NAME=`terraform output elb_dns_name`
SNS_TOPIC_ARN=`terraform output sns_topic_name`

#Set up email notifications
if [[ -n ${NOTIFICATIONS_EMAIL+x} ]]; then
    aws sns subscribe --topic-arn ${SNS_TOPIC_ARN} --protocol email --notification-endpoint "${NOTIFICATIONS_EMAIL}"
fi

#Create SSL cert if not provided
if [[ -z $SSL_CERT_ARN ]]; then
    cd $ROOT_DIR
    openssl genrsa -out terraform-gocd-elb-pk.pem 2048
    openssl req -sha256 -new -key terraform-gocd-elb-pk.pem -out terraform-gocd-elb.pem -subj "/CN=${ELB_DNS_NAME}"
    openssl x509 -req -days 365 -in terraform-gocd-elb.pem -signkey terraform-gocd-elb-pk.pem -out terraform-gocd-elb-cert.pem
    SSL_CERT_ARN=`aws iam upload-server-certificate --server-certificate-name terraform-gocd-elb --certificate-body file://${ROOT_DIR}/terraform-gocd-elb-cert.pem --private-key file://${ROOT_DIR}/terraform-gocd-elb-pk.pem --query 'ServerCertificateMetadata.{Arn:Arn}' --output text`
    sleep 5 #AWS needs to have a little think
fi
aws elb create-load-balancer-listeners --load-balancer-name terraform-gocd-elb --listeners Protocol=HTTPS,LoadBalancerPort=443,InstanceProtocol=HTTP,InstancePort=8153,SSLCertificateId=${SSL_CERT_ARN}
echo "Go is listening at https://${ELB_DNS_NAME}/"
