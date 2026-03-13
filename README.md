# overload-party-infra

Overload Party のインフラ管理リポジトリ。Cloud SQL / IAM / Cloud Scheduler の Terraform を管理する。

## 環境一覧

| 環境 | GCP Project | Cloud SQL | Scheduler |
|------|-------------|-----------|-----------|
| dev  | `overload-party-dev`  | db-g1-small | 2:00 AM JST 自動停止 |
| stg  | `overload-party-stg`  | db-g1-small | 2:00 AM JST 自動停止 |
| prod | `overload-party-prod` | db-g1-small | なし (常時稼働) |

## Terraform の管轄範囲

| リポ | 対象プロジェクト | 管理するもの |
|------|-----------------|-------------|
| **k8s** | `keyandnotes-platform` | GKE, Artifact Registry, WIF, CI/Deploy SA, platform 内 IAM |
| **infra (このリポ)** | `dev` / `stg` / `prod` | VPC, Cloud SQL, App SA, Cloud Run Jobs, Scheduler, CI SA の環境別権限 |

CI SA (`github-ci`) の **定義** は k8s、各環境プロジェクトへの **権限付与** は infra で管理する。

## ディレクトリ構成

```
environments/        # 環境別 Terraform
  dev/               # 開発環境
  stg/               # ステージング環境
  prod/              # 本番環境
modules/             # 共通モジュール
  cloudsql/          # Cloud SQL PostgreSQL
  iam/               # サービスアカウント + Workload Identity
  scheduler/         # Cloud Scheduler (Cloud SQL 自動停止/起動)
  migration-job/     # DB マイグレーション (Cloud Run Job)
  newsfeed/          # ニュースフィード (Cloud Run Job)
  static-assets/     # 静的アセット (GCS)
scripts/             # 運用スクリプト
```

## 使い方

```bash
# 環境を指定して操作 (デフォルト: dev)
make plan ENV=dev
make apply ENV=dev
make destroy ENV=dev

# Cloud SQL の手動起動/停止
make sql-start ENV=dev
make sql-stop ENV=dev
```

## CI/CD

- **PR**: 変更された環境に対して `terraform plan` を実行し、結果を PR コメントに投稿
- **main マージ**: 変更された環境に対して `terraform apply` を実行
- `modules/` 変更時は全環境に対して実行

## 関連リポジトリ

| リポジトリ | 内容 |
|-----------|------|
| [overload-party-gateway](https://github.com/kenyamaneko/overload-party-gateway) | API ゲートウェイサーバー (Go) |
| [overload-party-battle](https://github.com/kenyamaneko/overload-party-battle) | バトルサーバー (Go) |
| [overload-party-client](https://github.com/kenyamaneko/overload-party-client) | React + Capacitor クライアント |
| [overload-party-k8s](https://github.com/kenyamaneko/overload-party-k8s) | K8s マニフェスト + GKE/AR Terraform |
| [overload-party-common](https://github.com/kenyamaneko/overload-party-common) | 共有データ (カード YAML, 定数, ドキュメント) |
