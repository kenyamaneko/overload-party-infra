#!/usr/bin/env bash
set -euo pipefail

# apply 対象の環境の Cloud SQL を起動し、使える状態になるまで待つ。
# 夜間停止が既定の運用で、停止中は DB ユーザーの読み書きが必ず失敗して apply が
# 落ちるため、apply の前に起動を保証する。

: "${TF_PATH:?TF_PATH is required}"
: "${CLOUDSQL_INSTANCE:?CLOUDSQL_INSTANCE is required}"
: "${OPERATION_TIMEOUT_SECONDS:?OPERATION_TIMEOUT_SECONDS is required}"
: "${READY_TIMEOUT_SECONDS:?READY_TIMEOUT_SECONDS is required}"

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
CLOUDSQL_SCRIPT_DIR="${SCRIPT_DIR}/../cloudsql"

ENV="${TF_PATH##*/}"
case "${ENV}" in
  dev|stg|prod) ;;
  *)
    echo "::error::Cannot resolve the environment from the state root path: ${TF_PATH}"
    exit 1
    ;;
esac

PROJECT="overload-party-${ENV}"
export PROJECT

CURRENT=$(gcloud sql instances describe "${CLOUDSQL_INSTANCE}" \
  --project="${PROJECT}" \
  --format="value(settings.activationPolicy)" 2>&1) || {
  # インスタンス自体を作る apply があるため、存在しない場合は起動を待たずに進む。
  if echo "${CURRENT}" | grep -qiE 'not[ -]?found|does not exist|was not found'; then
    echo "::warning::Cloud SQL ${CLOUDSQL_INSTANCE} not found in ${PROJECT}"
    exit 0
  fi
  echo "::error::Failed to describe Cloud SQL instance: ${CURRENT}"
  exit 1
}

if [ "${CURRENT}" = "ALWAYS" ]; then
  echo "Cloud SQL ${CLOUDSQL_INSTANCE} in ${PROJECT} is already ALWAYS"
else
  POLICY="ALWAYS" "${CLOUDSQL_SCRIPT_DIR}/patch-activation-policy.sh"
fi

# 起動直後や別経路で起動された直後は policy だけ ALWAYS で操作を受け付けないため、
# patch の有無にかかわらず使える状態になるまで待つ。
"${CLOUDSQL_SCRIPT_DIR}/wait-until-ready.sh"
