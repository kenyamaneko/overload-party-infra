# overload-party-infra

Overload Party のインフラ管理リポジトリ。Google Cloud (VPC / Cloud SQL / Pub/Sub / IAM) + Cloudflare (DNS / CDN) を Terraform で管理する。
GKE クラスタは [keyandnotes-platform](https://github.com/kenyamaneko/keyandnotes-platform) リポジトリに分離。

`providers/` 配下はプロバイダで区切り、その中で state root (dev/stg/prod/platform) を持つ。1つの state root からしか呼ばれないモジュールはその state root 配下に置き、複数の state から使われるモジュールのみ兄弟の `modules/` に置く。

## 使い方

```bash
# Google Cloud env (dev/stg/prod)
cd providers/google-cloud/env/dev && terraform init && terraform plan

# Google Cloud 共有基盤 (keyandnotes-platform)
cd providers/google-cloud/platform && terraform init && terraform plan

# Cloudflare (全環境の DNS を 1 state で管理)
cd providers/cloudflare && terraform init && terraform plan

# モジュールのテスト
cd providers/google-cloud/env/modules/data/database && terraform test
cd providers/google-cloud/env/modules/foundation/network && terraform test
```

## CI/CD

- **PR**: 変更された state root に対して `terraform plan`、結果を PR コメントに投稿
- **main マージ**: 変更された state root に対して `terraform apply`
- `providers/<provider>/env/modules/` 配下の変更時は同プロバイダの env 配下全 state root を対象にする
- `providers/google-cloud/platform/` は直接変更時のみ (modules も同居)
- cloudflare は `providers/cloudflare/` 直接変更時のみ
