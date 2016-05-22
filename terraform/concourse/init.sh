#!/usr/bin/env bash
terraform remote config -backend=s3 -backend-config="bucket=tts_prod_terraform_state" -backend-config="key=network/terraform.tfstate" -backend-config="region=us-east-1"
