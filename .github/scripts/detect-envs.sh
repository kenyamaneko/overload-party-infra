#!/usr/bin/env bash
set -euo pipefail

# 変更されたファイルから、Terraform を実行すべき環境一覧を JSON 配列で出力する。
# 入力: 環境変数 BASE_SHA, HEAD_SHA, GITHUB_OUTPUT
# 出力: $GITHUB_OUTPUT に envs=<JSON 配列> を追記

: "${BASE_SHA:?BASE_SHA is required}"
: "${HEAD_SHA:=HEAD}"

ALL_ENVS=(dev stg prod platform cloudflare)
# modules/ は GCP 系モジュール置き場なので、変更時は cloudflare を除く全環境を対象にする
GCP_ENVS=(dev stg prod platform)

CHANGED=$(git diff --name-only "${BASE_SHA}" "${HEAD_SHA}")

envs=()
if echo "${CHANGED}" | grep -q '^modules/'; then
  envs=("${GCP_ENVS[@]}")
else
  for env in "${ALL_ENVS[@]}"; do
    if echo "${CHANGED}" | grep -q "^environments/${env}/"; then
      envs+=("${env}")
    fi
  done
fi

if [ ${#envs[@]} -eq 0 ]; then
  ENVS_JSON="[]"
else
  quoted=$(printf '"%s",' "${envs[@]}")
  ENVS_JSON="[${quoted%,}]"
fi

echo "Detected environments: ${ENVS_JSON}"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "envs=${ENVS_JSON}" >> "${GITHUB_OUTPUT}"
fi
