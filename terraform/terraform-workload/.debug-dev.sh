#!/usr/bin/env bash
set -e

rm -rf .terraform

terraform init \
  -backend-config="resource_group_name=rg-hybridlab-tfstate" \
  -backend-config="storage_account_name=sthybridlabtfstate01" \
  -backend-config="container_name=tfstate" \
  -backend-config="key=workload-dev.tfstate"

ACTION=${1:-plan}

terraform "$ACTION" -var-file="env/dev.tfvars"