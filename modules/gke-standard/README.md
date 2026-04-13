# gke-standard

Autopilot -> Standard 移行用モジュール。既存 `modules/gke` (Autopilot) と side-by-side で共存可能。

## 概要

- Mode: Standard (not Autopilot)
- Location: **zonal** (`asia-northeast1-a`) -- 無料ゾーナル枠を使い $49/月 を維持するため。regional にすると control plane 料金が発生する。
- Machine type: `e2-standard-2` (2 vCPU / 8 GiB)
- Node count: 1 (単一ノード・単一ノードプール・単一ゾーン)
- Release channel: REGULAR
- Workload Identity: 有効 (`${project_id}.svc.id.goog`)
- Network: `default` (VPC-native, `ip_allocation_policy {}`)

単一ノードが SPOF である点、ゾーン障害時にクラスタ全体が停止する点は許容済み。

固定値 (cluster name / machine type / node count / zone) はモジュール内部の `locals` に置いている。

## 入力変数

| 変数 | 説明 |
|---|---|
| `project_id` | GCP プロジェクト ID (必須) |
| `network` | VPC network 名 (default: `"default"`) |

## フォローアップ

- dev/stg の auto-shutdown は未実装。Standard クラスタではノードプールサイズを 0 にすることでコスト削減可能。後続タスクで `env-lifecycle` / `nightly-shutdown` を移植する。
