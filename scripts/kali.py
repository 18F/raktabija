#!/usr/bin/env python3
#  -*- coding: utf-8 -*-
import argparse
import sys
import http.client
import boto3
import json
import socket

parser = argparse.ArgumentParser(description='Kill AWS resources that have not been greenlisted in Chandika.')
parser.add_argument('chandika', help="Chandika's hostname")
parser.add_argument('--no-dry-run', dest='forreal', action='store_const', const=1, default=0, help='Actually delete non-greenlisted resources')
args = parser.parse_args()

aws_conn = http.client.HTTPConnection("169.254.169.254", timeout=2)

try:
    aws_conn.request("GET", "/latest/meta-data/iam/info")
except:
    sys.exit("Could not connect to EC2 instance metadata. NB This script can only be run from inside an EC2 instance!")

iam_json = json.loads(aws_conn.getresponse().read().decode("utf-8"))
account_id = iam_json['InstanceProfileArn'].split(':')[4]

aws_conn.request("GET", "/latest/meta-data/iam/security-credentials/")
iam_role = aws_conn.getresponse().read().decode("utf-8");

try:
    aws_conn.request("GET", "/latest/meta-data/iam/security-credentials/" + iam_role)
except:
    sys.exit("A single IAM role must be defined for this host in order for Kali to run")

creds = json.loads(aws_conn.getresponse().read().decode("utf-8"))
access_key = creds['AccessKeyId']
secret_key = creds['SecretAccessKey']
token = creds['Token']

conn = http.client.HTTPSConnection(args.chandika)

conn.request("GET", "/api/account.php?account_id=" + account_id)
response = conn.getresponse()
if response.status != 200:
    sys.exit("Got response " + response.status + " from Chandika at host " + args.chandika)

tags = ['Raktabija']
resources = []
systems = json.loads(response.read().decode("utf-8"))
for system in systems:
    tags.append(system['Tag'])
    resources.extend(system['Resources'])

output = 'Kali is running against AWS account ' + account_id + '.\n\n'
output = output + 'The following resources are safe: anything tagged with the name "Project" and the values "' + '","'.join(tags) + '", along with these named resources:\n\n'

if len(resources) > 0:
    output = output + '\n'.join(resources)
else:
    output = output + 'No resources specified'

output = output + '\n\n'
    
if args.forreal:
    output = output + 'Kali has deleted the following resources:'
else:
    output = output + 'This is a dry run. If Kali were running for real, the following resources would be deleted. To protect them, visit https://' + args.chandika + '/'

session = boto3.Session(aws_access_key_id=access_key, aws_secret_access_key=secret_key, aws_session_token=token)

output = output + '\n\nEC2:'
ec2_regions = session.get_available_regions('ec2')
for region in ec2_regions:
    ec2client = session.client('ec2', region)
    reservations = ec2client.describe_instances(Filters=[{'Name':'instance-state-name','Values':['running']}])
    instances_to_delete = []
    for reservation in reservations['Reservations']:
        for instance in reservation['Instances']:
            if instance['InstanceId'] in resources:
                break
            instance_tags = []
            for tag in instance['Tags']:
                if tag['Key'] == 'Project':
                    instance_tags.append(tag['Value'])
            if set(instance_tags).isdisjoint(set(tags)):
                instances_to_delete.append(instance['InstanceId'])
    if instances_to_delete:
        output = output + '\n' + '\n'.join(instances_to_delete)
        if args.forreal:
            ec2client.terminate_instances(InstanceIds=instances_to_delete)

sns_client = session.client('sns', 'us-east-1')
topic_arn = 'arn:aws:sns:us-east-1:' + account_id + ':raktabija-updates-topic'
sns_client.publish(TopicArn=topic_arn,Message=output,Subject='Deleting Resources on AWS account '+account_id)
