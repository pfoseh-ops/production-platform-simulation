#!/usr/bin/env bash
set -euo pipefail

test -z "$(gofmt -l cmd)"
go test -race ./...
go vet ./...

if command -v terraform >/dev/null 2>&1; then
  terraform fmt -check -recursive terraform
  terraform -chdir=terraform/bootstrap init -backend=false
  terraform -chdir=terraform/bootstrap validate
  terraform -chdir=terraform/environments/prod init -backend=false
  terraform -chdir=terraform/environments/prod validate
else
  echo "terraform not installed; skipped Terraform validation" >&2
fi

if command -v helm >/dev/null 2>&1; then
  helm lint deploy/chart
else
  echo "helm not installed; skipped Helm validation" >&2
fi
