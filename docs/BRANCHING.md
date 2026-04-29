# Branching Strategy

本リポジトリのブランチ戦略と運用を定義する。

## 概要

GitHub Flow を採用する。`main` ブランチが唯一の永続ブランチで、`main` の HEAD が全 state の適用基準。インフラ変更は apply が自動実行されないため（`workflow_dispatch` のみ）、環境昇格フローはブランチではなく apply タイミングの人間判断で制御する。

## ブランチ一覧

| ブランチ | 寿命 | 派生元 | マージ先 |
|---|---|---|---|
| `main` | 永続 | — | — |
| `feature/xxx` | 短命 | `main` | `main` |
| `fix/xxx` | 短命 | `main` | `main` |
| `chore/xxx` | 短命 | `main` | `main` |

## ブランチ運用ルール

### main

- 直 push 禁止。PR 経由のマージのみ
- force push 禁止、履歴書き換え禁止
- PR マージで apply は **起動しない**。apply は `workflow_dispatch` で人間が手動トリガーする

### 作業ブランチ

- `main` から切って `main` にマージする
- 命名プレフィックス: `feature/`（新機能・リソース追加）、`fix/`（バグ修正）、`chore/`（依存更新・リファクタ等）
- 命名例: `feature/add-pubsub-topic`, `feature/infra/issue-123`, `fix/cloudflare-api-record-proxied`
- PR マージ時にブランチ削除

## 開発フロー

```
1. main から作業ブランチを切る
   └─ git switch -c feature/add-pubsub-topic main

2. 変更を push → PR を作成
   └─ PR オープンで terraform plan が自動実行され、結果がコメントに貼られる
   └─ plan の差分を確認してレビュー・マージ

3. main にマージ

4. apply を手動トリガー
   └─ GitHub Actions > Terraform > Run workflow
   └─ path を選択して apply を実行
   └─ 複数 state に変更が及ぶ場合は state ごとに順次実行する
```

## CI/CD パイプライン

| ワークフロー | トリガー | 役割 |
|---|---|---|
| `terraform.yaml` (plan) | PR: main | 変更のある state root を検出して `terraform plan` を実行、結果を PR にコメント |
| `terraform.yaml` (apply) | `workflow_dispatch` (main のみ) | 指定した state root に `terraform apply` を実行 |
| `cloudsql-activation.yaml` | `workflow_dispatch` | Cloud SQL インスタンスの起動・停止 |

## ブランチ保護設定

GitHub Rulesets で以下を設定する。

### main

- 直 push 禁止
- PR マージのみ許可
- force push 禁止、削除禁止
- 必須ステータスチェック: `terraform.yaml` / plan が green（変更対象 state がない場合はスキップ）
