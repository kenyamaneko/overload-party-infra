# インフラ設計

本ドキュメントは **コードを読んでも一見しては分からない設計意図** だけを残す。各 `main.tf` / `variables.tf` の内容はファイル自体が一次情報。

## State 分割の原則

Terraform state は **変更ライフサイクルと権限境界** で分割している。

| State root | 対象 Google Cloud プロジェクト | 分割理由 |
|---|---|---|
| `google-cloud/env/{dev,stg,prod}` | `overload-party-{dev,stg,prod}` | 環境ごとのワークロードリソース。state を分けて env ごとに独立に apply できるようにする |
| `google-cloud/ops` | `overload-party-ops` | 運用ツール（drift-monitor / cost-monitor）は env を全 destroy しても残す必要があり、env のライフサイクルから独立させる |
| `google-cloud/bootstrap` | `overload-party-ops` | CI 自身の認証経路 (WIF プール) と state 保存先 (バケット) を管理する。CI が日常的に apply する `ops` root と同居させると、壊れたときに CI から直せなくなるため、人間がローカルから手動で apply する root として分離する |
| `cloudflare` | — | DNS レコードは Google Cloud とライフサイクルが異なる |
| `upstash/env/{dev,stg,prod}` | — | Upstash は Google Cloud provider と独立しており、env ごとに state を分けて独立に apply できるようにする |

`env/{dev,stg,prod}/main.tf` はそれぞれ `env/modules` を呼ぶ薄い composition で、全環境が同一モジュールセットを使う。環境差異を呼び出し側の変数だけに閉じ込めることで、module 内に環境分岐を持たせず、環境間で実装が乖離して再現できないバグが起きるのを防ぐ。

## keyandnotes-platform と overload-party-* の関係

`keyandnotes-platform` は overload-party サービス群が相乗りするプラットフォームプロジェクト。所有境界は **「リソースが書き込まれる Google Cloud プロジェクトと、管理する Terraform リポを一対一に対応させる」** という原則で決める。Terraform リソースの `project = ...` を見れば管理リポが分かる、という形にすることで、境界が一意に決まり、SA や IAM の変更時に複数リポを横断する必要がなくなる。

具体例: `google_service_account` (project = `overload-party-ops`) は overload-party-infra (`ops/modules/ci-cd`) が管理。`google_project_iam_member` で SA に IAM を付与する場合、`project = overload-party-dev` ならこのリポ、`project = keyandnotes-platform` なら `keyandnotes-platform` リポ。SA がどのプロジェクトに属するかは関係なく、IAM binding が書き込まれる側のプロジェクトで決まる。

例外: PSC エンドポイント (`env/modules/data/psc-cloudsql/`) は **書き込まれるプロジェクトが `keyandnotes-platform`、所有リポが `overload-party-infra` の env state** で、原則の対応関係が崩れている。

- なぜ keyandnotes-platform プロジェクトに書くか: 内部 IP は接続元 VPC の subnet からしか払い出せず別 VPC から経路が無いため、GKE Pod が走る `keyandnotes-platform` VPC に置くしかない。
- なぜ overload-party-infra の env state が所有するか: PSC は機能的に overload-party 専用 (overload-party-{env} の Cloud SQL に接続するためだけに存在) で、env 単位で 1 つずつ増減し、env-up/down で forwarding rule を動的に作成削除する。機能オーナーが所有することで env apply 一発で配線が完結し、env 追加時に `keyandnotes-platform` リポを触らずに済む。

## Cloud SQL アクセス経路 (PSC)

各環境の Cloud SQL (`overload-party-{dev,stg,prod}`) は **PSC (Private Service Connect)** で `keyandnotes-platform` の VPC に接続する。DB 接続の手段として PSC を選んだ理由: forwarding rule の作成・削除だけで接続を on/off でき、env 未使用時のコスト ($0.025/時間) を `env-up/down` で動的に落としやすいため。

PSC エンドポイントの永続リソース (IP / DNS) は env state (`env/modules/data/psc-cloudsql/`) で管理する。詳細は上の節「keyandnotes-platform と overload-party-* の関係」の例外項参照。forwarding rule は overload-party-k8s 側が `env-up/down` で動的に管理する。

## Upstash の接続情報の受け渡し

Upstash のデータベースと、その接続情報を保持する Secret Manager シークレットは同じ `upstash/env/{env}` state が作る。データベースを作った state だけが接続情報を持つため、シークレットの入れ物と権限をそこに置くことで、値の出所と置き場所が離れずに済む。

`google-cloud/env/{env}` state はシークレットを名前の文字列で参照する。state をまたいで参照するので、名前が両側で一致していることは Terraform が保証しない。

シークレットの値は Terraform が投入せず、apply 後に人が入れる。値の投入前に Cloud Run のリビジョンを作ると起動に失敗するため、Upstash 側の apply、値の投入、Google Cloud 側の apply の順で行う。

## CI/CD SA の集約

overload-party 系全リポの GitHub Actions CI は `overload-party-ops` の `github-ci` SA を共用する。env や repo ごとに分けると、apply で権限不足が出るたびに複数の権限定義を横断する必要が生じるため、`ops/modules/ci-cd` の一箇所に権限マトリクスを集約している。

SA を `overload-party-ops` プロジェクトに置くのは、プロジェクト境界 = 権限境界として機能させるため。`overload-party-ops` の owner だけが overload-party CI 認証情報を管理できる状態にする。

## overload-party-infra と overload-party-k8s の責務分担

k8s manifest と Terraform はデプロイ頻度・更新ライフサイクルが異なるためリポを分けている。

例外として prod の Reserved global IP は infra (`env/prod/main.tf`) が直接保持する。Cloudflare DNS が prod IP に pin されており、k8s 側の env-lifecycle が down のたびに IP を消すと DNS 不整合で外部から到達不能になるため。

## Cloud SQL ライフサイクルの所有権

Cloud SQL インスタンスは `env/` の Terraform が所有している。起動・停止（`activation_policy` 切替）も、リソースの所有者と操作の所有者を一致させるため、このリポの `cloudsql-activation.yaml` が担当する。手動で起動・停止する場合は `cloudsql-activation.yaml` を `workflow_dispatch` で叩く。

## 監視の当て方

Cloud Run サービスの監視は `env/modules/foundation/service-monitoring` を全サービスに `for_each` で当てる。サービスごとに監視を書くと、サービスが増えたときに当て忘れても誰も気づけないため、当てる範囲をサービス一覧そのものから導く。サービス固有の指標だけを各サービスのモジュールに置く。

ERROR ログの監視には Cloud Logging が標準で出す件数メトリクスを severity で絞って使う。ログベースメトリクスを定義する方式と違い、ログバケットもシンクも要らず、アラートポリシーだけで完結する。

dev も監視対象に含める。dev のデプロイが 3 週間失敗し続けても気づけなかったため、通知の届かない環境を作らない。テストで踏んだエラーが通知を埋めないよう、閾値は環境ごとに変える。

gateway の応答時間は監視しない。WebSocket 接続は切断まで 1 リクエストとして計測され、応答時間が接続時間そのものになって遅さを表さないため。

予算アラートは環境ごとのプロジェクトを対象に 1 つずつ置く。請求先アカウント単位でまとめると、どの環境で費用が増えたのかが分からないため。

## apply は手動トリガー

PR 時は `terraform plan` を自動実行してコメントに結果を貼る。`terraform apply` は `workflow_dispatch` のみ（main ブランチ限定）。PR マージが即 apply にならないのは、インフラ変更は人間が apply タイミングを判断すべきであるため。
