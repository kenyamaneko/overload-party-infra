#!/usr/bin/env bash
set -euo pipefail

# cloudsql-activation.yaml 用の Slack 通知。
# RESULT (cloudsql-activation.sh の GITHUB_OUTPUT) と JOB_STATUS を元に
# メッセージを分岐する。

: "${ACTION:?ACTION is required (up|down)}"
: "${ENV:?ENV is required}"
: "${JOB_STATUS:?JOB_STATUS is required}"
: "${SLACK_WEBHOOK_URL:?SLACK_WEBHOOK_URL is required}"
: "${GITHUB_REPOSITORY:?GITHUB_REPOSITORY is required}"
: "${GITHUB_RUN_ID:?GITHUB_RUN_ID is required}"

RESULT="${RESULT:-}"

if [ "${ACTION}" = "up" ]; then
  ACTION_JP="起動"
else
  ACTION_JP="停止"
fi

LOG_URL="https://github.com/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}"

if [ "${JOB_STATUS}" != "success" ]; then
  MSG=":x: \`${ENV}\` の Cloud SQL ${ACTION_JP}に失敗しました。<${LOG_URL}|ログを確認>"
else
  case "${RESULT}" in
    changed)
      MSG=":white_check_mark: \`${ENV}\` の Cloud SQL を${ACTION_JP}しました"
      ;;
    noop)
      if [ "${ACTION}" = "up" ]; then
        MSG=":white_check_mark: \`${ENV}\` の Cloud SQL は既に起動中です"
      else
        MSG=":white_check_mark: \`${ENV}\` の Cloud SQL は既に停止しています"
      fi
      ;;
    pending-existing)
      MSG=":hourglass_flowing_sand: \`${ENV}\` の Cloud SQL は別のオペレーションが進行中です。完了後に再度お試しください"
      ;;
    not-found)
      MSG=":warning: \`${ENV}\` の Cloud SQL インスタンスが存在しません (スキップ)"
      ;;
    *)
      MSG=":white_check_mark: \`${ENV}\` の Cloud SQL ${ACTION_JP}が完了しました"
      ;;
  esac
fi

curl -sf -X POST "${SLACK_WEBHOOK_URL}" \
  -H 'Content-type: application/json' \
  --data "$(jq -cn --arg text "${MSG}" '{text: $text}')"
