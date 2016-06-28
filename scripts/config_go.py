#!/usr/bin/env python3
#  -*- coding: utf-8 -*-
import argparse
import xml.etree.ElementTree as et

parser = argparse.ArgumentParser(description='Configure go.')
parser.add_argument('config', help="Go's config file")
args = parser.parse_args()

tree = et.parse('packer/cookbooks/gocd/templates/cruise-config.xml.erb')
root = tree.getroot()
pipelines = root.findall('pipelines')[0]
pipeline = et.SubElement(pipelines, 'pipeline', {'name':'kali'})
timer = et.SubElement(pipeline, 'timer', {'onlyOnChanges':'false'})
timer.text = '0 0 22 ? * *'
materials = et.SubElement(pipeline, 'materials')
git = et.SubElement(materials, 'git', {'url':'https://github.com/18F/raktabija.git'})
vcs_filter = et.SubElement(git, 'filter')
et.SubElement(vcs_filter, 'ignore', {'pattern':'**'})
stage = et.SubElement(pipeline,'stage', {'name':'bootstrap'})
job = et.SubElement(stage,'job', {'name':'exec'})
tasks = et.SubElement(job,'tasks')
et.SubElement(tasks, 'exec', {'args':'scripts/kali_cron', 'command':'/bin/bash'})
tree.write(args.config)
