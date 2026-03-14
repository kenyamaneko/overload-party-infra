ENV ?= dev
PROJECT = overload-party-$(ENV)
REGION = asia-northeast1

.PHONY: init plan apply destroy sql-start sql-stop newsfeed-pause newsfeed-resume

init:
	cd environments/$(ENV) && terraform init

plan:
	cd environments/$(ENV) && terraform plan

apply:
	cd environments/$(ENV) && terraform init && terraform apply -auto-approve

destroy:
	./scripts/infra-destroy.sh $(ENV)

sql-start:
	./db-ctl/cloudsql-start.sh $(ENV)

sql-stop:
	./db-ctl/cloudsql-stop.sh $(ENV)

newsfeed-pause:
	gcloud scheduler jobs pause newsfeed-fetch --project=$(PROJECT) --location=$(REGION)

newsfeed-resume:
	gcloud scheduler jobs resume newsfeed-fetch --project=$(PROJECT) --location=$(REGION)
