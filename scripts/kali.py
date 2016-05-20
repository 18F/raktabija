#!/usr/bin/env python3
#  -*- coding: utf-8 -*-
import argparse
import sys
import http.client
import boto3

parser = argparse.ArgumentParser(description='Kill AWS resources that have not been greenlisted in Chandika.')
parser.add_argument('chandika', help="Chandika's hostname")
parser.add_argument('account', help='Account ID')
parser.add_argument('--aws-key', dest='aws_key', help='AWS Key')
parser.add_argument('--aws-secret-key', dest='aws_secret_key', help='AWS Secret Key')
parser.add_argument('--dry-run', dest='dry_run', help='AWS Secret Key')
args = parser.parse_args()

conn = http.client.HTTPConnection(args.chandika)
conn.request("GET", "/api/unexpired.php?type=AWS+resource&account_id=" + args.account)
response = conn.getresponse()
if response.status != 200:
    sys.exit("Got response " + response.status + " from Chandika at host " + args.chandika)

unexpired = response.read().decode("utf-8").split("\n")

if args.aws_key and args.aws_secret_key:
    session = boto3.Session(aws_access_key_id=args.aws_key, aws_secret_access_key=args.aws_secret_key)

s3client = session.client('s3')
s3buckets = s3client.list_buckets()
for bucket in s3buckets['Buckets']:
    if bucket['Name'] not in unexpired:
        print("s3://" + bucket['Name'])
    
