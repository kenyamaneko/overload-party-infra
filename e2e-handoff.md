# E2E テスト環境セットアップ — 引き継ぎ

## 概要

client リポに Playwright E2E テストを導入し、CI で自動実行できるようにする。
テストには gateway (Go, port 9001) と battle server (.NET, port 9002) が必要。

## 構成

```
overload-party-client/
├── e2e/
│   ├── docker-compose.yml   # gateway + battle を AR から pull して起動
│   ├── playwright.config.ts
│   └── tests/
│       ├── auth.spec.ts           # Dev Login → ホーム画面表示
│       └── npc-battle.spec.ts     # バトルモード選択 → デッキ選択 → NPC → バトル画面
```

## やること (3 ステップ)

### Step 1: WIF allowlist に client リポを追加（infra/k8s 担当）

k8s リポの Terraform を修正して apply する。

**ファイル: `overload-party-k8s/terraform/environments/platform/main.tf`**

`ci_cd` モジュールの 2 箇所にリポを追加:

```hcl
module "ci_cd" {
  # ...
  ci_wif_repositories = [
    "overload-party-battle",
    "overload-party-common",
    "overload-party-gateway",
    "overload-party-ops",
    "overload-party-client",       # ← 追加
  ]
  allowed_repositories = [
    "overload-party-battle",
    "overload-party-common",
    "overload-party-gateway",
    "overload-party-infra",
    "overload-party-k8s",
    "overload-party-ops",
    "overload-party-client",       # ← 追加
  ]
}
```

apply 後、WIF の attribute_condition に client リポが追加され、
`github-ci` SA の WIF binding にも client リポが追加される。

### Step 2: client リポに GitHub Secrets を設定（infra/k8s 担当）

```bash
# client リポのディレクトリで実行
gh secret set WIF_PROVIDER \
  --body "projects/948329072347/locations/global/workloadIdentityPools/github-actions/providers/github"

gh secret set CI_SERVICE_ACCOUNT \
  --body "github-ci@keyandnotes-platform.iam.gserviceaccount.com"
```

### Step 3: E2E テスト環境の構築（client 担当）

#### docker-compose.yml

```yaml
services:
  gateway:
    image: asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/overload-party-gateway:latest
    ports:
      - "9001:9001"
    # gateway は make run-local 相当のインメモリモードで起動
    # → 環境変数で DB/Firebase をモック化する設定が必要なら各リポの README を参照

  battle:
    image: asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/overload-party-battle:latest
    ports:
      - "9002:9002"
```

> **注意**: gateway/battle の Docker イメージが「ローカルモード（DB/Firebase なし）」で
> 起動できるかは、各リポの Dockerfile・エントリポイントの実装次第。
> `make run-local` で使われている環境変数を docker-compose の `environment:` に設定する必要がある可能性あり。

#### CI workflow (.github/workflows/e2e.yaml)

```yaml
name: E2E Tests

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

permissions:
  contents: read
  id-token: write

env:
  REGISTRY: asia-northeast1-docker.pkg.dev

jobs:
  e2e:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - id: auth
        uses: google-github-actions/auth@v2
        with:
          workload_identity_provider: ${{ secrets.WIF_PROVIDER }}
          service_account: ${{ secrets.CI_SERVICE_ACCOUNT }}
          token_format: access_token

      - name: Login to Artifact Registry
        uses: docker/login-action@v3
        with:
          registry: ${{ env.REGISTRY }}
          username: oauth2accesstoken
          password: ${{ steps.auth.outputs.access_token }}

      - name: Start services
        working-directory: e2e
        run: docker compose up -d --wait

      # Node.js / Playwright のセットアップは省略（client リポの構成に合わせる）

      - name: Run E2E tests
        working-directory: e2e
        run: npx playwright test

      - name: Stop services
        if: always()
        working-directory: e2e
        run: docker compose down
```

## 補足

- **AR への認証**: WIF (Workload Identity Federation) を使用。GitHub Actions が OIDC トークンを発行し、GCP 側で `github-ci` SA に impersonate する仕組み。パスワードやキーの管理は不要。
- **gateway/battle イメージ**: 各リポの CI (`ci.yaml`) で main push 時に AR へ push されている。`latest` タグが常に最新。
- **AR レジストリ**: `asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/`
- **テスト対象環境**: ローカル起動（Docker Compose）のため、dev/stg/prod 環境には影響しない
