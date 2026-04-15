#!/usr/bin/env bash
set -euo pipefail

# 変更ファイルから Terraform を実行すべきディレクトリ (providers/ 配下の相対パス) を JSON 配列で出力する。
# 入力: 環境変数 BASE_SHA, HEAD_SHA, GITHUB_OUTPUT
# 出力: $GITHUB_OUTPUT に paths=<JSON 配列> を追記 (例: ["google-cloud/env/dev","upstash/env/dev"])

: "${BASE_SHA:?BASE_SHA is required}"
: "${HEAD_SHA:=HEAD}"

GOOGLE_CLOUD_ENV_PATHS=("google-cloud/env/dev" "google-cloud/env/stg" "google-cloud/env/prod")
GOOGLE_CLOUD_PLATFORM_PATHS=("google-cloud/platform")
UPSTASH_ENV_PATHS=("upstash/env/dev" "upstash/env/stg" "upstash/env/prod")
CLOUDFLARE_PATHS=("cloudflare")
ALL_PATHS=("${GOOGLE_CLOUD_ENV_PATHS[@]}" "${GOOGLE_CLOUD_PLATFORM_PATHS[@]}" "${UPSTASH_ENV_PATHS[@]}" "${CLOUDFLARE_PATHS[@]}")

CHANGED=$(git diff --name-only "${BASE_SHA}" "${HEAD_SHA}")

selected=""
add_selection() {
  for p in "$@"; do
    case " ${selected} " in
      *" ${p} "*) ;;
      *) selected="${selected} ${p}" ;;
    esac
  done
}

if echo "${CHANGED}" | grep -q '^providers/google-cloud/env/modules/'; then
  add_selection "${GOOGLE_CLOUD_ENV_PATHS[@]}"
fi
if echo "${CHANGED}" | grep -q '^providers/upstash/env/modules/'; then
  add_selection "${UPSTASH_ENV_PATHS[@]}"
fi
# platform/modules/ は platform/ から呼ばれる (state root は platform 単一) ため
# 専用の if を置かず、下のループで providers/google-cloud/platform/ の直接変更として拾う

for p in "${ALL_PATHS[@]}"; do
  if echo "${CHANGED}" | grep -q "^providers/${p}/"; then
    add_selection "${p}"
  fi
done

paths=()
for p in "${ALL_PATHS[@]}"; do
  case " ${selected} " in
    *" ${p} "*) paths+=("$p") ;;
  esac
done

if [ ${#paths[@]} -eq 0 ]; then
  PATHS_JSON="[]"
else
  quoted=$(printf '"%s",' "${paths[@]}")
  PATHS_JSON="[${quoted%,}]"
fi

echo "Detected paths: ${PATHS_JSON}"

if [ -n "${GITHUB_OUTPUT:-}" ]; then
  echo "paths=${PATHS_JSON}" >> "${GITHUB_OUTPUT}"
fi
