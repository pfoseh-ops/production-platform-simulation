#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <globally-unique-state-bucket> <github-owner/repository>" >&2
  exit 1
fi

state_bucket=$1
github_repository=$2

terraform -chdir=terraform/bootstrap init
terraform -chdir=terraform/bootstrap apply \
  -var="state_bucket_name=${state_bucket}" \
  -var="github_repository=${github_repository}"
