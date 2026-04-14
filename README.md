# overload-party-infra

Overload Party の Google Cloud / Cloudflare / Upstash のリソースを Terraform で管理するリポジトリ。

関連リポジトリ:
- [keyandnotes-platform](https://github.com/kenyamaneko/keyandnotes-platform) — GKE クラスタ / 共有プラットフォーム基盤
- [overload-party-k8s](https://github.com/kenyamaneko/overload-party-k8s) — k8s マニフェスト・デプロイ

## ディレクトリ方針

- `providers/` 配下はプロバイダで区切る
- dev / stg / prod 共通の実装は `env/modules/` に書き、環境で値が異なるもの (project ID / SA email 等) は `env/{dev,stg,prod}/main.tf` から渡す
- 1 state root からしか呼ばれないモジュールはその state root 配下に置く (例: `providers/google-cloud/platform/modules/`)

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
- **main マージ**: 変更された state root に対して `terraform apply`
- `providers/<provider>/env/modules/` 配下の変更は同プロバイダの env 全 state root を対象
- `providers/google-cloud/platform/` は直接変更時のみ (modules 含む)
- `providers/cloudflare/` は直接変更時のみ
