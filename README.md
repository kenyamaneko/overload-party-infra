# overload-party-infra

Overload Party のインフラ管理リポジトリ。VPC / Cloud SQL / Pub/Sub / IAM / CDN の Terraform を管理する。
GKE クラスタは [keyandnotes-platform](https://github.com/kenyamaneko/keyandnotes-platform) リポジトリに分離。

## 環境一覧

| 環境 | GCP Project | 用途 |
|------|-------------|------|
| dev | `overload-party-dev` | 開発環境 |
| stg | `overload-party-stg` | ステージング環境 |
| prod | `overload-party-prod` | 本番環境 |
| platform | `keyandnotes-platform` | 共有基盤 (WIF, CI/TF/Deploy SA, AR, PSC) |
| cloudflare | -- | CDN (アセット配信用 CNAME) + API DNS (A records) |

## ディレクトリ構成

```
environments/
  dev/                   開発環境
  stg/                   ステージング環境
  prod/                  本番環境
  platform/              共有基盤
  cloudflare/            Cloudflare CDN + DNS
modules/
  foundation/            プロジェクト立ち上げに必要な基盤レイヤ
    network/             VPC + サブネット + Private Services Access
    service-accounts/    Per-service GSA + Workload Identity
    artifact-registry/   Artifact Registry
  data/                  データストア
    database/            Cloud SQL PostgreSQL + IAM users
    firestore/           Firestore (game_config store)
    pubsub/              Pub/Sub topics + subscriptions + IAM
  platform/              プロジェクト跨ぎの接続性
    psc-cloudsql/        PSC endpoint for Cloud SQL (cross-project)
  app/                   アプリ固有のリソース
    newsfeed/            ニュースフィード (Cloud Run Job)
    shop-secrets/        Shop IAP Secrets (Secret Manager)
    assets/              ゲームアセット (GCS バケット)
  ops/                   運用 / CI/CD
    ci-cd/               WIF + CI SA + Terraform SA + Deploy SA
    db-migration/        DB マイグレーション (Cloud Run Job)
```

## 使い方

```bash
make plan ENV=dev
make apply ENV=dev

# テスト
cd modules/data/database && terraform test
cd modules/foundation/network && terraform test
```

## 環境ごとの差異

| モジュール | dev | stg | prod | platform | 備考 |
|-----------|-----|-----|------|----------|------|
| foundation/network | o | o | o | - | |
| foundation/service-accounts | o | o | o | - | dev のみ newsfeed GSA を含む |
| foundation/artifact-registry | - | - | - | o | |
| data/database | o | o | o | - | prod は `deletion_protection = true` |
| data/firestore | o | o | o | - | |
| data/pubsub | o | o | o | - | |
| platform/psc-cloudsql | - | - | - | o | dev/stg/prod 各環境分を per-env instantiation |
| app/newsfeed | o | - | - | - | dev のみ |
| app/shop-secrets | o | o | o | - | |
| app/assets | o | o | o | - | |
| ops/ci-cd | - | - | - | o | WIF + CI SA + TF SA + Deploy SA |
| ops/db-migration | o | o | - | - | |

## CI/CD

- **PR**: 変更された環境に対して `terraform plan` を実行し、結果を PR コメントに投稿
- **main マージ**: 変更された環境に対して `terraform apply` を実行
- `modules/` 変更時は全環境に対して実行 (cloudflare 除く)
