#!/bin/bash
set -euo pipefail

ENV="${1:?Usage: $0 <dev|stg|prod>}"

# ─── Prod guard ─────────────────────────────────────
if [ "${ENV}" = "prod" ]; then
  echo "ERROR: Cannot destroy prod infrastructure via script."
  echo "       Use the GCP Console or run terraform destroy manually."
  exit 1
fi

echo "==> Destroying ${ENV} infrastructure (Cloud SQL + IAM)..."
echo "    This will DELETE the Cloud SQL instance and all data."
read -p "    Are you sure? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Aborted."
  exit 0
fi

cd "$(dirname "$0")/../environments/${ENV}"
terraform destroy -auto-approve
echo "==> ${ENV} infrastructure destroyed."
