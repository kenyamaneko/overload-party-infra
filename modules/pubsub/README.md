# modules/pubsub

Cloud Pub/Sub (exactly-once delivery) のトピック、サブスクリプション、IAM を管理。

## Topics

| Topic | Publishers | Subscribers | DLQ |
|-------|------------|-------------|-----|
| `matchmaking-events` | matchmaking | gateway | `matchmaking-events-dlq` |
| `faction-selected` | scenario, shop | account, card, gateway | `faction-selected-dlq` |
| `premium-updated` | shop | account, gateway | `premium-updated-dlq` |

## Inputs

| Name | Description |
|------|-------------|
| `project_id` | GCP project ID |
| `matchmaking_service_account_email` | publisher on `matchmaking-events` |
| `gateway_service_account_email` | subscriber on matchmaking / faction-selected / premium-updated |
| `scenario_service_account_email` | publisher on `faction-selected` |
| `shop_service_account_email` | publisher on `faction-selected` + `premium-updated` |
| `account_service_account_email` | subscriber on faction-selected / premium-updated |
| `card_service_account_email` | subscriber on `faction-selected` |

## Outputs

| Name | Description |
|------|-------------|
| `topic_name` / `topic_id` | matchmaking-events topic |
| `subscription_name` / `subscription_id` | matchmaking-events-gateway subscription |
| `dlq_topic_id` | matchmaking DLQ topic |
| `faction_selected_topic_name` | faction-selected topic |
| `faction_selected_subscription_names` | map of subscriber -> subscription name |
| `premium_updated_topic_name` | premium-updated topic |
| `premium_updated_subscription_names` | map of subscriber -> subscription name |
