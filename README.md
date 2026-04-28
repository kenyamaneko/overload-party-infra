# overload-party-infra

Overload Party の Google Cloud / Cloudflare / Upstash のリソースを Terraform で管理するリポジトリ。

関連リポジトリ:
- [keyandnotes-platform](https://github.com/kenyamaneko/keyandnotes-platform) — GKE クラスタ / 共有プラットフォーム基盤
- [overload-party-k8s](https://github.com/kenyamaneko/overload-party-k8s) — k8s マニフェスト・デプロイ

## ディレクトリ方針

- `providers/` 配下はプロバイダで区切る
- dev / stg / prod 共通の実装は `env/modules/` に書き、環境で値が異なるもの (project ID / SA email 等) は `env/{dev,stg,prod}/main.tf` から渡す
- 1 state root からしか呼ばれないモジュールはその state root 配下に置く (例: `providers/google-cloud/platform/modules/`)

## k8s リポとの責務分担

Ingress / PSC / DNS / Reserved IP は **永続性の要件**で infra と overload-party-k8s のどちらが所有するかを分ける。仕様は [ADR 018 §管理責務の分担](https://github.com/kenyamaneko/overload-party-common/blob/main/docs/adr/018-argocd-gitops-and-nodepool-based-shutdown.md) に従う。

| リソース | dev / stg | prod |
|---|---|---|
| Deployment / Service / ConfigMap / ServiceAccount | ArgoCD | ArgoCD |
| Ingress / backendConfig / Service annotation | k8s `env-lifecycle` (up/down) | ArgoCD |
| PSC forwarding rule | k8s `env-lifecycle` (up/down) | k8s `env-lifecycle` (初回作成後維持) |
| Reserved global IP | k8s `env-lifecycle` (down で削除) | **infra** (常時保持・削除しない) |
| Cloudflare DNS | k8s `env-lifecycle` (down で 127.0.0.1 に切替) | 常時有効 |

理由: prod の IP は DNS が pin されるため destroy されてはならない。k8s `env-lifecycle` は down の度に IP を消すので prod の永続性を担保する別オーナーが必要 → Terraform (infra) が `env/prod/main.tf` で直接保持する。他のリソース群は env-lifecycle 側で統一管理することで、dev/stg の起動停止サイクルが自然に成立する。

## Secret Manager の値投入方針

Terraform が作るのはシークレットの *枠* のみ。実値のバージョン登録は手動で行う。
これは機密値を tfstate に持ち込まないための共通ポリシー。shop-secrets も matchmaking-upstash-redis-* も同じ扱い。

```bash
gcloud secrets versions add <secret_id> --project <project_id> --data-file=- <<< "<value>"
```

### Upstash Redis の値取得 (matchmaking)

Upstash Redis の **パスワードは Upstash コンソールの UI からは取得できない** ため、Terraform
state から取り出す必要がある。

```bash
cd providers/upstash/env/dev
terraform state pull | jq -r '.resources[] | select(.type=="upstash_redis_database") | .instances[0].attributes.password'
```

endpoint / port は Upstash コンソール (Details タブ) か `terraform state show module.matchmaking_redis.upstash_redis_database.this` で確認。

投入先は `matchmaking-upstash-redis-endpoint` (値: `<host>:<port>`) と `matchmaking-upstash-redis-password` (値: パスワード)。

### Upstash の Management API 認証情報

Upstash 側の Terraform provider は DB 作成のため email + API key を要求する。各 upstash
state root (`providers/upstash/env/{dev,stg,prod}`) に `secret.auto.tfvars` (gitignored) を置く。
全環境共通の値:

```hcl
upstash_email   = "..."
upstash_api_key = "..."
```

## CI/CD

- **PR**: 変更された state root に対して `terraform plan`、結果を PR コメントに投稿
- **apply**: GitHub Actions の `Terraform` workflow を `workflow_dispatch` で手動起動。
  対象 state root を input で 1 つ選んで apply する (誤適用防止のため自動 apply は持たない)
- `providers/<provider>/env/modules/` 配下の変更は同プロバイダの env 全 state root を対象
- `providers/google-cloud/platform/` は直接変更時のみ (modules 含む)
- `providers/cloudflare/` は直接変更時のみ
