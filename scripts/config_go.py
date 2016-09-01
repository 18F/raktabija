#!/usr/bin/env python3
#  -*- coding: utf-8 -*-
import argparse
import xml.etree.ElementTree as et
import chandika_client

def add_pipeline(pipelines, name, url):
    pipeline = et.SubElement(pipelines, 'pipeline', {'name':name})
    materials = et.SubElement(pipeline, 'materials')
    git = et.SubElement(materials, 'git', {'url':url, 'branch':'deploy'})
    stage = et.SubElement(pipeline,'stage', {'name':'bootstrap'})
    jobs = et.SubElement(stage,'jobs')
    job = et.SubElement(jobs,'job', {'name':'exec'})
    tasks = et.SubElement(job,'tasks')
    et.SubElement(tasks, 'exec', {'args':'deploy', 'command':'/bin/bash'})

parser = argparse.ArgumentParser(description='Configure go.')
parser.add_argument('config', help="Go's config file")
parser.add_argument('chandika', help="Chandika's hostname")
parser.add_argument('chandika_api_key', help="Chandika API key")
args = parser.parse_args()

# get go server id from existing config file
tree = et.parse(args.config)
root = tree.getroot()
schemaVersion = root.get('schemaVersion')
server = root.findall('server')[0]
serverId = server.get('serverId')

# get template
tree = et.parse('packer/cookbooks/gocd/templates/cruise-config.xml.erb')
root = tree.getroot()
root.set('schemaVersion', schemaVersion)
pipelines = root.findall('pipelines')[0]

# set server id
server = root.findall('server')[0]
server.set('serverId', serverId)

# add new pipeline for kali
pipeline = et.SubElement(pipelines, 'pipeline', {'name':'kali'})
timer = et.SubElement(pipeline, 'timer', {'onlyOnChanges':'false'})
timer.text = '0 0 22 ? * *'
materials = et.SubElement(pipeline, 'materials')
git = et.SubElement(materials, 'git', {'url':'https://github.com/18F/raktabija.git'})
vcs_filter = et.SubElement(git, 'filter')
et.SubElement(vcs_filter, 'ignore', {'pattern':'**'})
stage = et.SubElement(pipeline,'stage', {'name':'bootstrap'})
jobs = et.SubElement(stage,'jobs')
job = et.SubElement(jobs,'job', {'name':'exec'})
tasks = et.SubElement(job,'tasks')
et.SubElement(tasks, 'exec', {'args':'scripts/kali_cron', 'command':'/bin/bash'})

aws_creds = chandika_client.aws_credentials()
account = chandika_client.chandika_metadata(aws_creds['account_id'], args.chandika, args.chandika_api_key)
urls = {}
for system in account['Systems']:
    repository = system['Repository']
    if repository and repository.strip():
        urls[system["Name"]] = repository

for name in urls:
    add_pipeline(pipelines, name, urls[name])

# write out config file
tree.write(args.config)
