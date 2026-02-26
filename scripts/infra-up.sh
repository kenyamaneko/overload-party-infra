#!/bin/bash
set -euo pipefail

ENV="${1:?Usage: $0 <dev|stg|prod>}"
SCRIPT_DIR="$(dirname "$0")"

echo "==> Provisioning ${ENV} infrastructure (Cloud SQL + IAM)..."
cd "$SCRIPT_DIR/../environments/${ENV}"
terraform init
terraform apply -auto-approve

echo "==> ${ENV} infrastructure is ready."
echo "    Next: apply K8s manifests in overload-party-k8s repo"
