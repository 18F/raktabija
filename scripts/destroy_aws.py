#!/usr/bin/env python3
#  -*- coding: utf-8 -*-

import argparse
import sys
import boto3
import pprint

parser = argparse.ArgumentParser(description='Delete all internet gateways, subnets, and unoccupied vpcs in an AWS account. Use with care.')
parser.add_argument('account', help='Account ID')
parser.add_argument('--aws-key', dest='aws_key', help='AWS Key')
parser.add_argument('--aws-secret-key', dest='aws_secret_key', help='AWS Secret Key')
args = parser.parse_args()

if args.aws_key and args.aws_secret_key:
    session = boto3.Session(aws_access_key_id=args.aws_key, aws_secret_access_key=args.aws_secret_key)
else:
    session = boto3.Session()

regions = session.get_available_regions('ec2')

pp = pprint.PrettyPrinter(indent=4)

for region in regions:
    print('Deleting resources in region' + region)
    ec2client = session.client('ec2', region)
    igs = ec2client.describe_internet_gateways()
    pp.pprint(igs)
    for igId in igs['InternetGateways']:
        for attachment in igId['Attachments']:
            ec2client.detach_internet_gateway(InternetGatewayId=igId['InternetGatewayId'], VpcId=attachment['VpcId'])
        ec2client.delete_internet_gateway(InternetGatewayId=igId['InternetGatewayId'])

    subnets = ec2client.describe_subnets()
    pp.pprint(subnets)
    for subnetId in subnets['Subnets']:
        ec2client.delete_subnet(SubnetId=subnetId['SubnetId'])
                
    vpcs = ec2client.describe_vpcs()
    pp.pprint(vpcs)
    for vpcId in vpcs['Vpcs']:
        ec2client.delete_vpc(VpcId=vpcId['VpcId'])
    
