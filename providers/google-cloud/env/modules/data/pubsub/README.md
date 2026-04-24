# modules/pubsub

Cloud Pub/Sub (exactly-once delivery) のトピック、サブスクリプション、IAM を管理。

## Topics

| Topic | Publishers | Subscribers | DLQ |
|-------|------------|-------------|-----|
| `matchmaking-events` | matchmaking | gateway | `matchmaking-events-dlq` |
| `faction-purchased` | shop | account, card, gateway | `faction-purchased-dlq` |
| `premium-updated` | shop | account, gateway | `premium-updated-dlq` |
| `player-onboarded` | scenario | account, card, gateway | `player-onboarded-dlq` |
| `news-article-collected` | newsfeed | news | `news-article-collected-dlq` |

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
| `newsfeed_service_account_email` | publisher on `news-article-collected` |
| `news_service_account_email` | subscriber on `news-article-collected` |

## Outputs

(現状 output 無し — `outputs.tf` は存在しない。module 利用側から topic / subscription 名を参照する必要が生じたら都度追加する。)
