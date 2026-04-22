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

## Outputs

| Name | Description |
|------|-------------|
| `topic_name` / `topic_id` | matchmaking-events topic |
| `subscription_name` / `subscription_id` | matchmaking-events-gateway subscription |
| `dlq_topic_id` | matchmaking DLQ topic |
| `faction_purchased_topic_name` | faction-purchased topic |
| `faction_purchased_subscription_names` | map of subscriber -> subscription name |
| `premium_updated_topic_name` | premium-updated topic |
| `premium_updated_subscription_names` | map of subscriber -> subscription name |
| `player_onboarded_topic_name` | player-onboarded topic |
| `player_onboarded_subscription_names` | map of subscriber -> subscription name |
