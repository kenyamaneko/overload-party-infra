#!/usr/bin/env bash
set -euo pipefail

# Cloud SQL が RUNNABLE になり、Admin API がインスタンスへの操作を受け付けるまで待つ。
# state が RUNNABLE になった後もインスタンスが "not running" として操作を拒む時間が
# あるため、後続が実際に使う Admin API を叩けることまで確かめる。

: "${PROJECT:?PROJECT is required}"
: "${CLOUDSQL_INSTANCE:?CLOUDSQL_INSTANCE is required}"
: "${READY_TIMEOUT_SECONDS:?READY_TIMEOUT_SECONDS is required}"

POLL_INTERVAL_SECONDS=10

echo "Waiting for Cloud SQL ${CLOUDSQL_INSTANCE} in ${PROJECT} to accept operations (up to ${READY_TIMEOUT_SECONDS}s)"

DEADLINE=$((SECONDS + READY_TIMEOUT_SECONDS))
STATE="unknown"
PROBE="not attempted"

while [ "${SECONDS}" -lt "${DEADLINE}" ]; do
  # 一時的な API エラーで待機を打ち切ると、起動しているのに赤くなるため、次の周回で見直す。
  STATE=$(gcloud sql instances describe "${CLOUDSQL_INSTANCE}" \
    --project="${PROJECT}" \
    --format="value(state)" 2>&1) || {
    echo "::warning::Failed to describe ${CLOUDSQL_INSTANCE}: ${STATE}"
    STATE="describe-failed"
  }

  if [ "${STATE}" = "RUNNABLE" ]; then
    if PROBE=$(gcloud sql users list \
      --instance="${CLOUDSQL_INSTANCE}" \
      --project="${PROJECT}" \
      --format="value(name)" 2>&1); then
      echo "Cloud SQL ${CLOUDSQL_INSTANCE} is RUNNABLE and accepting operations"
      exit 0
    fi
  fi

  echo "Not ready yet (state: ${STATE})"
  sleep "${POLL_INTERVAL_SECONDS}"
done

echo "::error::Gave up waiting: Cloud SQL ${CLOUDSQL_INSTANCE} did not become usable within ${READY_TIMEOUT_SECONDS}s (last state: ${STATE}, last probe: ${PROBE})"
exit 1
