# overload-party-infra

Overload Party のインフラ管理リポジトリ。VPC / Cloud SQL / GKE / Pub/Sub / IAM / CDN の Terraform を管理する。

## 環境一覧

| 環境 | GCP Project | 用途 |
|------|-------------|------|
| dev | `overload-party-dev` | 開発環境 |
| stg | `overload-party-stg` | ステージング環境 |
| prod | `overload-party-prod` | 本番環境 |
| platform | `keyandnotes-platform` | 共有基盤 (GKE, WIF, CI/TF/Deploy SA, AR) |
| cloudflare | -- | CDN (アセット配信用 CNAME) + API DNS (A records) |

## ディレクトリ構成

```
environments/
  dev/               開発環境
  stg/               ステージング環境
  prod/              本番環境
  platform/          共有基盤
  cloudflare/        Cloudflare CDN + DNS
modules/
  network/           VPC + サブネット + Private Services Access
  database/          Cloud SQL PostgreSQL + IAM users
  gke/               GKE Autopilot クラスタ
  gke-standard/      GKE Standard クラスタ (Autopilot からの移行用)
  psc-cloudsql/      PSC endpoint for Cloud SQL (cross-project)
  service-accounts/  Per-service GSA + Workload Identity
  pubsub/            Pub/Sub topics + subscriptions + IAM
  db-migration/      DB マイグレーション (Cloud Run Job)
  newsfeed/          ニュースフィード (Cloud Run Job)
  assets/            ゲームアセット (GCS バケット)
  ci-cd/             WIF + CI SA + Terraform SA + Deploy SA
  artifact-registry/ Artifact Registry
  shop-secrets/      Shop IAP Secrets (Secret Manager)
```

## 使い方

```bash
make plan ENV=dev
make apply ENV=dev

# テスト
cd modules/database && terraform test
cd modules/network && terraform test
```

## 環境ごとの差異

| モジュール | dev | stg | prod | platform | 備考 |
|-----------|-----|-----|------|----------|------|
| network | o | o | o | - | |
| database | o | o | o | - | prod は `deletion_protection = true` |
| gke | - | - | - | o | Autopilot (keyandnotes-shared) |
| gke-standard | - | - | - | o | Standard (keyandnotes-standard) |
| psc-cloudsql | - | - | - | o | dev のみ (per-env instantiation) |
| service-accounts | o | o | o | - | dev のみ newsfeed GSA を含む |
| pubsub | o | o | o | - | |
| db-migration | o | o | - | - | |
| newsfeed | o | - | - | - | |
| assets | o | o | o | - | |
| ci-cd | - | - | - | o | WIF + CI SA + TF SA + Deploy SA |
| artifact-registry | - | - | - | o | |
| shop-secrets | o | o | o | - | |

## CI/CD

- **PR**: 変更された環境に対して `terraform plan` を実行し、結果を PR コメントに投稿
- **main マージ**: 変更された環境に対して `terraform apply` を実行
- `modules/` 変更時は全環境に対して実行 (cloudflare 除く)
