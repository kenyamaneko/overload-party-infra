ENV ?= dev
PROJECT = overload-party-$(ENV)
REGION = asia-northeast1

.PHONY: init plan apply destroy newsfeed-pause newsfeed-resume

init:
	cd environments/$(ENV) && terraform init

plan:
	cd environments/$(ENV) && terraform plan

apply:
	cd environments/$(ENV) && terraform init && terraform apply -auto-approve

destroy:
	@if [ "$(ENV)" = "prod" ]; then echo "ERROR: Cannot destroy prod infrastructure via make."; exit 1; fi
	@echo "This will DELETE the $(ENV) Cloud SQL instance and all data."
	@read -p "Are you sure? (yes/no): " confirm && [ "$$confirm" = "yes" ] || (echo "Aborted."; exit 1)
	cd environments/$(ENV) && terraform destroy -auto-approve

newsfeed-pause:
	gcloud scheduler jobs pause newsfeed-fetch --project=$(PROJECT) --location=$(REGION)

newsfeed-resume:
	gcloud scheduler jobs resume newsfeed-fetch --project=$(PROJECT) --location=$(REGION)
