ENV ?= dev

.PHONY: init plan apply destroy sql-start sql-stop

init:
	cd environments/$(ENV) && terraform init

plan:
	cd environments/$(ENV) && terraform plan

apply:
	cd environments/$(ENV) && terraform init && terraform apply -auto-approve

destroy:
	./scripts/infra-destroy.sh $(ENV)

sql-start:
	./scripts/cloudsql-start.sh $(ENV)

sql-stop:
	./scripts/cloudsql-stop.sh $(ENV)
