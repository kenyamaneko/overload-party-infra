#!/usr/bin/env bash
set -euo pipefail

# Cloud SQL の activation-policy を切り替え、切替操作の完了まで待つ。
# gcloud の組み込み待機は切替が成功していても 10 分で打ち切って非ゼロ終了するため、
# 操作 ID を受け取って明示した上限まで待つ。

: "${PROJECT:?PROJECT is required}"
: "${CLOUDSQL_INSTANCE:?CLOUDSQL_INSTANCE is required}"
: "${POLICY:?POLICY is required (ALWAYS|NEVER)}"
: "${OPERATION_TIMEOUT_SECONDS:?OPERATION_TIMEOUT_SECONDS is required}"

echo "Patching Cloud SQL ${CLOUDSQL_INSTANCE} in ${PROJECT} to ${POLICY}"

OPERATION=$(gcloud sql instances patch "${CLOUDSQL_INSTANCE}" \
  --project="${PROJECT}" \
  --activation-policy="${POLICY}" \
  --async \
  --quiet \
  --format="value(name)")

if [ -z "${OPERATION}" ]; then
  echo "::error::Could not obtain the operation id for the ${POLICY} switch of ${CLOUDSQL_INSTANCE}"
  exit 1
fi

echo "Waiting for operation ${OPERATION} (up to ${OPERATION_TIMEOUT_SECONDS}s)"

if ! gcloud sql operations wait "${OPERATION}" \
  --project="${PROJECT}" \
  --timeout="${OPERATION_TIMEOUT_SECONDS}"; then
  echo "::error::Gave up: could not confirm that operation ${OPERATION} (${POLICY} switch of ${CLOUDSQL_INSTANCE}) completed within the ${OPERATION_TIMEOUT_SECONDS}s limit"
  exit 1
fi
