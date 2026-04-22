# modules/pubsub

Cloud Pub/Sub (exactly-once delivery) のトピック、サブスクリプション、IAM を管理。

## Topics

| Topic | Publishers | Subscribers | DLQ |
|-------|------------|-------------|-----|
| `matchmaking-events` | matchmaking | gateway | `matchmaking-events-dlq` |
| `faction-purchased` | shop | account, card, gateway | `faction-purchased-dlq` |
| `premium-updated` | shop | account, gateway | `premium-updated-dlq` |
| `player-onboarded` | scenario | account, card, gateway | `player-onboarded-dlq` |

## Inputs

| Name | Description |
|------|-------------|
| `project_id` | Google Cloud project ID |
| `matchmaking_service_account_email` | publisher on `matchmaking-events` |
| `gateway_service_account_email` | subscriber on matchmaking / faction-purchased / premium-updated / player-onboarded |
| `scenario_service_account_email` | publisher on `player-onboarded` |
| `shop_service_account_email` | publisher on `faction-purchased` + `premium-updated` |
| `account_service_account_email` | subscriber on faction-purchased / premium-updated / player-onboarded |
| `card_service_account_email` | subscriber on `faction-purchased` + `player-onboarded` |
| `newsfeed_service_account_email` | Email of the newsfeed Cloud Run Job GSA. Granted roles/pubsub.publisher on the news-article-collected topic (ADR-020). |

## Outputs

(現状 output 無し — `outputs.tf` は存在しない。module 利用側から topic / subscription 名を参照する必要が生じたら都度追加する。)

## State migration note (ADR-022)

ADR-022 で `faction-selected` topic / subscription を `faction-purchased` に rename し、併せて
`player-onboarded` への subscriber を account / card / gateway に拡大した。Terraform の
resource アドレスも変わるため、既に旧名で資源が存在する dev / stg 環境に本変更を
apply すると旧 topic / subscription は destroy、新 topic / subscription は create される。

メッセージ欠損や subscriber の重複購読を避けるため、apply は以下の順で行う:

1. 対象環境の publisher / subscriber Pod (scenario / shop / account / card / gateway)
   を一旦停止、または新 env 名 (`FACTION_PURCHASED_*` / `PLAYER_ONBOARDED_*`)
   を参照する manifest に切り替える
2. 旧 topic 上の未 ack メッセージがある場合は消化を待つ (stg の負荷に応じて判断)
3. `terraform apply` で destroy + create を通す
4. Pod を再起動し、新 topic / subscription への pub/sub が成立することを確認する

prod への apply は上記を dev / stg で検証した後に行う。詳細 runbook は別途作成する。
