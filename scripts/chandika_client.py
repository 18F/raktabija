#!/usr/bin/env python3
#  -*- coding: utf-8 -*-
import sys
import http.client
import json
import socket

def aws_credentials():
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
    return {'account_id':account_id, 'access_key':access_key, 'secret_key':secret_key, 'token':token}

def chandika_metadata(account_id, chandika_url):
    conn = http.client.HTTPSConnection(chandika_url)

    conn.request("GET", "/api/account.php?account_id=" + account_id)
    response = conn.getresponse()
    if response.status != 200:
        sys.exit("Got response " + response.status + " from Chandika at host " + args.chandika)

    account = json.loads(response.read().decode("utf-8"))
    return account
