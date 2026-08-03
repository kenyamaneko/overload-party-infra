#!/usr/bin/env bash
set -euo pipefail

# Ingress 等の後続作業が失敗しないよう、ノードが Ready になるまで待つ。
# 呼び出し元は action == 'up' のときのみこのスクリプトを実行する想定。

: "${GKE_CLUSTER:?GKE_CLUSTER is required}"
: "${ENV:?ENV is required}"

kubectl wait node \
  -l "cloud.google.com/gke-nodepool=${GKE_CLUSTER}-${ENV}" \
  --for=condition=Ready --timeout=5m
