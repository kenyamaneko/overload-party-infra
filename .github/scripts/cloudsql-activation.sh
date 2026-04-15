#!/usr/bin/env bash
set -euo pipefail

# Cloud SQL の activation-policy を切り替える。
# 呼び出し元 (cloudsql-activation.yaml) に対して GITHUB_OUTPUT 経由で
# 以下のいずれかの結果を返す。Slack 通知はこれを見てメッセージを分岐する。
#   changed          : 実際に policy を切り替えた
#   noop             : 既に目的の policy だった (何もしていない)
#   pending-existing : 別オペレーション実行中で操作をスキップした
#   not-found        : インスタンス自体が存在しなかった (skip)

: "${ENV:?ENV is required}"
: "${POLICY:?POLICY is required (ALWAYS|NEVER)}"
: "${CLOUDSQL_INSTANCE:?CLOUDSQL_INSTANCE is required}"

case "${POLICY}" in
  ALWAYS|NEVER) ;;
  *)
    echo "::error::Invalid policy: ${POLICY}"
    exit 1
    ;;
esac

PROJECT="overload-party-${ENV}"

write_result() {
  echo "result=$1" >> "${GITHUB_OUTPUT}"
}

# ─── インスタンス存在確認 ───
CURRENT=$(gcloud sql instances describe "${CLOUDSQL_INSTANCE}" \
  --project="${PROJECT}" \
  --format="value(settings.activationPolicy)" 2>&1) || {
  if echo "${CURRENT}" | grep -qiE 'not[ -]?found|does not exist|was not found'; then
    echo "::warning::Cloud SQL ${CLOUDSQL_INSTANCE} not found in ${PROJECT}"
    write_result "not-found"
    exit 0
  fi
  echo "::error::Failed to describe Cloud SQL instance: ${CURRENT}"
  exit 1
}

# ─── 既に目的状態なら何もしない ───
if [ "${CURRENT}" = "${POLICY}" ]; then
  echo "Cloud SQL ${CLOUDSQL_INSTANCE} is already ${POLICY}"
  write_result "noop"
  exit 0
fi

# ─── 別オペレーション進行中チェック ───
# 進行中の操作があるまま patch すると gcloud 側で conflict エラーになるので、
# 事前に検知してユーザーに「進行中」と返した方が UX が良い。
PENDING=$(gcloud sql operations list \
  --instance="${CLOUDSQL_INSTANCE}" \
  --project="${PROJECT}" \
  --filter="status!=DONE" \
  --format="value(name)" 2>/dev/null || true)

if [ -n "${PENDING}" ]; then
  echo "::warning::Another operation is in progress: ${PENDING}"
  write_result "pending-existing"
  exit 0
fi

# ─── 実施 ───
echo "Patching Cloud SQL ${CLOUDSQL_INSTANCE}: ${CURRENT} -> ${POLICY}"
gcloud sql instances patch "${CLOUDSQL_INSTANCE}" \
  --activation-policy="${POLICY}" \
  --project="${PROJECT}" \
  --quiet

write_result "changed"
