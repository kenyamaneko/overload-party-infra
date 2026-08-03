#!/usr/bin/env bash
set -euo pipefail

# node-pool-scale.yaml から呼ばれるノードプール resize スクリプト。
# down は常に 0 ノード、up は INPUT_COUNT (未指定時 1)。

: "${GKE_CLUSTER:?GKE_CLUSTER is required}"
: "${GKE_ZONE:?GKE_ZONE is required}"
: "${GKE_PROJECT:?GKE_PROJECT is required}"
: "${ENV:?ENV is required}"
: "${ACTION:?ACTION is required (up|down)}"

if [ "${ACTION}" = "down" ]; then
  COUNT=0
else
  COUNT="${INPUT_COUNT:-1}"
fi

gcloud container clusters resize "${GKE_CLUSTER}" \
  --node-pool="${GKE_CLUSTER}-${ENV}" \
  --num-nodes="${COUNT}" \
  --zone="${GKE_ZONE}" \
  --project="${GKE_PROJECT}" \
  --quiet
