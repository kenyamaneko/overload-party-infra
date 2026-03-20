# overload-party-infra

Overload Party のインフラ管理リポジトリ。Cloud SQL / IAM / Cloud Scheduler の Terraform を管理する。

## 環境一覧

| 環境 | GCP Project | 用途 |
|------|-------------|------|
| dev  | `overload-party-dev`  | 開発環境（VPC, Cloud SQL, Scheduler, Migration Job, Newsfeed Job） |
| stg  | `overload-party-stg`  | ステージング環境（VPC, Cloud SQL, Scheduler, Migration Job） |
| prod | `overload-party-prod` | 本番環境（VPC, Cloud SQL のみ、常時稼働） |
| platform | `keyandnotes-platform` | 共有基盤（WIF, CI SA, Terraform SA, AR reader） |

## Terraform の管轄範囲

| リポ | 対象プロジェクト | 管理するもの |
|------|-----------------|-------------|
| **infra (このリポ)** | `dev` / `stg` / `prod` | VPC, Cloud SQL, App SA, Cloud Run Jobs, Scheduler |
| **infra (このリポ)** | `keyandnotes-platform` | WIF プール, CI SA (`github-ci`), Terraform SA (`terraform-deployer`) |
| **k8s** | `keyandnotes-platform` | GKE, Artifact Registry, Deploy SA (`github-deploy`) |

## ディレクトリ構成

```
environments/        # 環境別 Terraform
  dev/               # 開発環境
  stg/               # ステージング環境
  prod/              # 本番環境
  platform/          # 共有基盤 (WIF, CI/TF SA)
modules/             # 共通モジュール
  vpc/               # VPC + サブネット + Private Services Access
  ci-cd/             # WIF プール + CI SA + Terraform SA
  cloudsql/          # Cloud SQL PostgreSQL
  iam/               # サービスアカウント + Workload Identity
  scheduler/         # Cloud Scheduler (Cloud SQL 自動停止/起動)
  migration-job/     # DB マイグレーション (Cloud Run Job)
  newsfeed/          # ニュースフィード (Cloud Run Job)
  static-assets/     # 静的アセット (GCS)
```

## 使い方

```bash
# 環境を指定して操作 (デフォルト: dev)
make plan ENV=dev
make apply ENV=dev
make destroy ENV=dev

# Cloud SQL の手動起動/停止は Slack コマンド (/db-start, /db-stop) で実行

# テスト実行
cd modules/scheduler && terraform test
cd modules/iam && terraform test
cd modules/vpc && terraform test
```

## 環境ごとの差異

| モジュール | dev | stg | prod | 備考 |
|-----------|-----|-----|------|------|
| vpc | o | o | o | |
| cloudsql | o | o | o | prod は `deletion_protection = true` |
| iam | o | o | o | |
| scheduler | o | o | - | prod は常時稼働のため不要 |
| migration-job | o | o | - | prod の DB マイグレーションは手動実行 |
| newsfeed | o | - | - | dev のみ（stg/prod は未デプロイ） |
| static-assets | o | o | o | |

### Cloud Scheduler の auto-start

`modules/scheduler` は `start_schedule` 変数で朝の自動起動を設定できます（デフォルト: 無効）。

```hcl
module "scheduler" {
  source         = "../../modules/scheduler"
  project_id     = local.project_id
  region         = local.region
  stop_schedule  = "0 2 * * *"     # 2:00 AM JST に停止
  start_schedule = "0 9 * * 1-5"   # 平日 9:00 AM JST に起動（任意）
}
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
