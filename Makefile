.PHONY: test lint build fmt terraform-fmt terraform-validate

test:
	go test -race -cover ./...

lint:
	go vet ./...

build:
	docker build -t production-platform-simulation:local .

fmt:
	gofmt -w cmd
	terraform fmt -recursive terraform

terraform-fmt:
	terraform fmt -check -recursive terraform

terraform-validate:
	terraform -chdir=terraform/bootstrap init -backend=false
	terraform -chdir=terraform/bootstrap validate
	terraform -chdir=terraform/environments/prod init -backend=false
	terraform -chdir=terraform/environments/prod validate
