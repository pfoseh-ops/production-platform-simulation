#!/usr/bin/env bash
set -euo pipefail

: "${TF_STATE_BUCKET:?Set TF_STATE_BUCKET}"
: "${TF_LOCK_TABLE:?Set TF_LOCK_TABLE}"
: "${TF_VAR_public_access_cidrs:?Set TF_VAR_public_access_cidrs as a Terraform list}"
: "${TF_VAR_grafana_admin_password:?Set TF_VAR_grafana_admin_password}"

aws_region=${AWS_REGION:-us-east-1}
environment_dir=terraform/environments/prod

terraform -chdir="${environment_dir}" init \
  -backend-config="bucket=${TF_STATE_BUCKET}" \
  -backend-config="key=production-platform-simulation/prod.tfstate" \
  -backend-config="region=${aws_region}" \
  -backend-config="dynamodb_table=${TF_LOCK_TABLE}" \
  -backend-config="encrypt=true"

terraform -chdir="${environment_dir}" plan -input=false -out=tfplan
terraform -chdir="${environment_dir}" apply -input=false tfplan
