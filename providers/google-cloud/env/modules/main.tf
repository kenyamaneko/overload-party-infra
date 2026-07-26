terraform {
  required_providers {
    google = {
      source                = "hashicorp/google"
      configuration_aliases = [google.platform]
    }
  }
}

locals {
  migration_image = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/db-migrate:latest"
  newsfeed_image  = "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/newsfeed:latest"

  k8s_services = {
    gateway     = "overload-party-gateway"
    matchmaking = "overload-party-matchmaking"
    battle      = "overload-party-battle"
    card        = "overload-party-card"
    account     = "overload-party-account"
    shop        = "overload-party-shop"
    scenario    = "overload-party-scenario"
    news        = "overload-party-news"
    support     = "overload-party-support"
  }

  non_k8s_services = {
    newsfeed = "overload-party-newsfeed"
  }

  db_services = {
    gateway  = "overload-party-gateway"
    battle   = "overload-party-battle"
    card     = "overload-party-card"
    account  = "overload-party-account"
    shop     = "overload-party-shop"
    scenario = "overload-party-scenario"
    newsfeed = "overload-party-newsfeed"
    news     = "overload-party-news"
    support  = "overload-party-support"
  }

  # GitHub Actions の CI/CD は overload-party-ops プロジェクトの github-ci SA に集約しており
  # env ごとに切り替えない。db-migration / newsfeed の Cloud Run Job invoker 等に付与する。
  deploy_sa_member = "serviceAccount:github-ci@overload-party-ops.iam.gserviceaccount.com"

  cloud_run_images = {
    for svc, _ in local.k8s_services : svc => "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/${svc}:latest"
  }

  cloudsql_connection_name = "${var.project_id}:${var.region}:${var.cloudsql_instance_name}"

  # news/support の config.go は "staging" | "production" のみ要求するため、dev/stg は staging、prod のみ production とする。
  staging_or_production_env = var.env_name == "prod" ? "production" : "staging"

  # db-g1-small のコネクション上限に対する安全側の暫定値。実接続数に基づく正式なサイジングではない。
  cloud_run_max_instance_count = 3

  standard_resources = {
    dev  = { cpu = "100m", memory = "128Mi" }
    stg  = { cpu = "200m", memory = "256Mi" }
    prod = { cpu = "200m", memory = "256Mi" }
  }
  battle_resources = {
    dev  = { cpu = "500m", memory = "512Mi" }
    stg  = { cpu = "1", memory = "1Gi" }
    prod = { cpu = "1", memory = "1Gi" }
  }
  gateway_resources                  = { cpu = "1", memory = "512Mi" }
  gateway_max_concurrent_connections = 250
  gateway_request_timeout_sec        = 3600
}

module "network" {
  source = "./foundation/network"

  project_id = var.project_id
  region     = var.region
}

module "service_accounts" {
  source = "./foundation/service-accounts"

  project_id       = var.project_id
  k8s_namespace    = var.k8s_namespace
  k8s_services     = local.k8s_services
  non_k8s_services = local.non_k8s_services
}

module "database" {
  source = "./data/database"

  project_id                    = var.project_id
  region                        = var.region
  instance_name                 = var.cloudsql_instance_name
  tier                          = var.cloudsql_tier
  database_name                 = var.database_name
  network_id                    = module.network.network_self_link
  ipv4_enabled                  = var.ipv4_enabled
  psc_allowed_consumer_projects = var.psc_allowed_consumer_projects
  deletion_protection           = var.deletion_protection

  db_users = { for svc, _ in local.db_services : svc => module.service_accounts.accounts[svc].email }

  depends_on = [module.network.service_networking_connection]
}

module "psc_cloudsql" {
  source = "./data/psc-cloudsql"

  providers = {
    google.platform = google.platform
  }

  project_id             = var.psc_consumer_project_id
  region                 = var.region
  network                = var.psc_consumer_network
  env_name               = var.env_name
  cloudsql_project_id    = var.project_id
  cloudsql_instance_name = var.cloudsql_instance_name

  depends_on = [module.database]
}

module "pubsub" {
  source = "./messaging/pubsub"

  project_id                        = var.project_id
  matchmaking_service_account_email = module.service_accounts.accounts["matchmaking"].email
  scenario_service_account_email    = module.service_accounts.accounts["scenario"].email
  shop_service_account_email        = module.service_accounts.accounts["shop"].email
  newsfeed_service_account_email    = module.service_accounts.accounts["newsfeed"].email

  gateway_service_url = module.gateway.uri
  account_service_url = module.account.uri
  card_service_url    = module.card.uri
  news_service_url    = module.news.uri
}

module "firestore" {
  source = "./data/firestore"

  project_id  = var.project_id
  location_id = var.firestore_location
  game_config_reader_emails = {
    account  = module.service_accounts.accounts["account"].email
    card     = module.service_accounts.accounts["card"].email
    shop     = module.service_accounts.accounts["shop"].email
    scenario = module.service_accounts.accounts["scenario"].email
    gateway  = module.service_accounts.accounts["gateway"].email
    battle   = module.service_accounts.accounts["battle"].email
  }
}

module "db_migration" {
  source = "./jobs/db-migration"

  project_id          = var.project_id
  region              = var.region
  migration_image     = local.migration_image
  network             = module.network.network_name
  subnetwork          = module.network.subnetwork_name
  cloudsql_private_ip = module.database.private_ip_address
  database_name       = var.database_name
  deploy_sa_member    = local.deploy_sa_member

  depends_on = [module.network.service_networking_connection]
}

module "newsfeed" {
  source = "./app/newsfeed"

  project_id            = var.project_id
  region                = var.region
  newsfeed_image        = local.newsfeed_image
  network               = module.network.network_name
  subnetwork            = module.network.subnetwork_name
  cloudsql_private_ip   = module.database.private_ip_address
  database_name         = var.database_name
  bucket_name           = var.newsfeed_bucket_name
  service_account_email = module.service_accounts.accounts["newsfeed"].email
  deploy_sa_member      = local.deploy_sa_member
  scheduler_paused      = var.newsfeed_scheduler_paused

  depends_on = [module.network.service_networking_connection]
}

module "shop_secrets" {
  source = "./app/shop/shop-secrets"

  project_id                 = var.project_id
  shop_service_account_email = module.service_accounts.accounts["shop"].email
}

module "assets" {
  source = "./app/assets"

  project_id            = var.project_id
  region                = var.region
  assets_bucket_name    = var.assets_bucket_name
  scenarios_bucket_name = var.scenarios_bucket_name
}

module "e2e" {
  count  = var.enable_e2e ? 1 : 0
  source = "./jobs/e2e"

  project_id        = var.project_id
  developer_members = var.e2e_developer_members
}

module "internal_auth_secret" {
  source = "./foundation/internal-auth-secret"

  project_id = var.project_id
  accessor_service_account_emails = {
    gateway     = module.service_accounts.accounts["gateway"].email
    account     = module.service_accounts.accounts["account"].email
    card        = module.service_accounts.accounts["card"].email
    shop        = module.service_accounts.accounts["shop"].email
    scenario    = module.service_accounts.accounts["scenario"].email
    matchmaking = module.service_accounts.accounts["matchmaking"].email
    news        = module.service_accounts.accounts["news"].email
    support     = module.service_accounts.accounts["support"].email
    # battle は対象外 (プレイヤー identity を持たず IAM 到達制御のみを受ける設計のため)
  }
}

module "support_secrets" {
  source = "./app/support/support-secrets"

  project_id                    = var.project_id
  support_service_account_email = module.service_accounts.accounts["support"].email
}

module "account" {
  source = "./app/account"

  project_id               = var.project_id
  region                   = var.region
  image                    = local.cloud_run_images["account"]
  service_account_email    = module.service_accounts.accounts["account"].email
  network                  = module.network.network_name
  subnetwork               = module.network.subnetwork_name
  cloudsql_connection_name = local.cloudsql_connection_name
  database_name            = var.database_name
  max_instance_count       = local.cloud_run_max_instance_count
  resources_limit_cpu      = local.standard_resources[var.env_name].cpu
  resources_limit_memory   = local.standard_resources[var.env_name].memory
  internal_auth_secret_id  = module.internal_auth_secret.secret_id

  depends_on = [module.network.service_networking_connection]
}

module "card" {
  source = "./app/card"

  project_id               = var.project_id
  region                   = var.region
  env_name                 = var.env_name
  image                    = local.cloud_run_images["card"]
  service_account_email    = module.service_accounts.accounts["card"].email
  network                  = module.network.network_name
  subnetwork               = module.network.subnetwork_name
  cloudsql_connection_name = local.cloudsql_connection_name
  database_name            = var.database_name
  max_instance_count       = local.cloud_run_max_instance_count
  resources_limit_cpu      = local.standard_resources[var.env_name].cpu
  resources_limit_memory   = local.standard_resources[var.env_name].memory
  internal_auth_secret_id  = module.internal_auth_secret.secret_id

  account_service_url = module.account.uri

  depends_on = [module.network.service_networking_connection]
}

module "shop" {
  source = "./app/shop"

  project_id               = var.project_id
  region                   = var.region
  image                    = local.cloud_run_images["shop"]
  service_account_email    = module.service_accounts.accounts["shop"].email
  network                  = module.network.network_name
  subnetwork               = module.network.subnetwork_name
  cloudsql_connection_name = local.cloudsql_connection_name
  database_name            = var.database_name
  max_instance_count       = local.cloud_run_max_instance_count
  resources_limit_cpu      = local.standard_resources[var.env_name].cpu
  resources_limit_memory   = local.standard_resources[var.env_name].memory
  internal_auth_secret_id  = module.internal_auth_secret.secret_id

  faction_acquired_topic    = "faction-acquired"
  card_pack_purchased_topic = "card-pack-purchased"
  premium_updated_topic     = "premium-updated"
  apple_environment         = var.shop_apple_environment

  depends_on = [module.network.service_networking_connection]
}

module "scenario" {
  source = "./app/scenario"

  project_id               = var.project_id
  region                   = var.region
  env_name                 = var.env_name
  image                    = local.cloud_run_images["scenario"]
  service_account_email    = module.service_accounts.accounts["scenario"].email
  network                  = module.network.network_name
  subnetwork               = module.network.subnetwork_name
  cloudsql_connection_name = local.cloudsql_connection_name
  database_name            = var.database_name
  max_instance_count       = local.cloud_run_max_instance_count
  resources_limit_cpu      = local.standard_resources[var.env_name].cpu
  resources_limit_memory   = local.standard_resources[var.env_name].memory
  internal_auth_secret_id  = module.internal_auth_secret.secret_id

  story_bucket                 = "overload-party-${var.env_name}-story"
  player_onboarded_topic       = "player-onboarded"
  onboarding_name_set_topic    = "onboarding-name-set"
  onboarding_faction_set_topic = "onboarding-faction-set"
  account_base_url             = module.account.uri

  depends_on = [module.network.service_networking_connection]
}

module "matchmaking" {
  source = "./app/matchmaking"

  project_id              = var.project_id
  region                  = var.region
  image                   = local.cloud_run_images["matchmaking"]
  service_account_email   = module.service_accounts.accounts["matchmaking"].email
  max_instance_count      = local.cloud_run_max_instance_count
  resources_limit_cpu     = local.standard_resources[var.env_name].cpu
  resources_limit_memory  = local.standard_resources[var.env_name].memory
  internal_auth_secret_id = module.internal_auth_secret.secret_id
  match_made_topic        = "matchmaking-events"
}

module "news" {
  source = "./app/news"

  project_id               = var.project_id
  region                   = var.region
  env_name                 = local.staging_or_production_env
  image                    = local.cloud_run_images["news"]
  service_account_email    = module.service_accounts.accounts["news"].email
  network                  = module.network.network_name
  subnetwork               = module.network.subnetwork_name
  cloudsql_connection_name = local.cloudsql_connection_name
  database_name            = var.database_name
  max_instance_count       = local.cloud_run_max_instance_count
  resources_limit_cpu      = local.standard_resources[var.env_name].cpu
  resources_limit_memory   = local.standard_resources[var.env_name].memory
  internal_auth_secret_id  = module.internal_auth_secret.secret_id

  depends_on = [module.network.service_networking_connection]
}

module "support" {
  source = "./app/support"

  project_id               = var.project_id
  region                   = var.region
  env_name                 = local.staging_or_production_env
  image                    = local.cloud_run_images["support"]
  service_account_email    = module.service_accounts.accounts["support"].email
  network                  = module.network.network_name
  subnetwork               = module.network.subnetwork_name
  cloudsql_connection_name = local.cloudsql_connection_name
  database_name            = var.database_name
  max_instance_count       = local.cloud_run_max_instance_count
  resources_limit_cpu      = local.standard_resources[var.env_name].cpu
  resources_limit_memory   = local.standard_resources[var.env_name].memory
  internal_auth_secret_id  = module.internal_auth_secret.secret_id

  cors_allowed_origins       = var.support_cors_allowed_origins
  slack_channel_id           = var.support_slack_channel_id
  sendgrid_from_address      = var.support_sendgrid_from_address
  sendgrid_from_name         = var.support_sendgrid_from_name
  slack_bot_token_secret_id  = module.support_secrets.slack_bot_token_secret_id
  sendgrid_api_key_secret_id = module.support_secrets.sendgrid_api_key_secret_id

  depends_on = [module.network.service_networking_connection]
}

module "battle" {
  source = "./app/battle"

  project_id               = var.project_id
  region                   = var.region
  image                    = local.cloud_run_images["battle"]
  service_account_email    = module.service_accounts.accounts["battle"].email
  network                  = module.network.network_name
  subnetwork               = module.network.subnetwork_name
  cloudsql_connection_name = local.cloudsql_connection_name
  database_name            = var.database_name
  max_instance_count       = local.cloud_run_max_instance_count
  resources_limit_cpu      = local.battle_resources[var.env_name].cpu
  resources_limit_memory   = local.battle_resources[var.env_name].memory

  card_service_url = module.card.uri

  depends_on = [module.network.service_networking_connection]
}

module "gateway" {
  source = "./app/gateway"

  project_id                 = var.project_id
  region                     = var.region
  env_name                   = var.env_name
  image                      = local.cloud_run_images["gateway"]
  container_port             = 9090
  max_concurrent_connections = local.gateway_max_concurrent_connections
  request_timeout_sec        = local.gateway_request_timeout_sec
  resources_limit_cpu        = local.gateway_resources.cpu
  resources_limit_memory     = local.gateway_resources.memory
  service_account_email      = module.service_accounts.accounts["gateway"].email
  network                    = module.network.network_name
  subnetwork                 = module.network.subnetwork_name
  cloudsql_connection_name   = local.cloudsql_connection_name
  database_name              = var.database_name
  internal_auth_secret_id    = module.internal_auth_secret.secret_id

  allowed_origins         = var.gateway_allowed_origins
  battle_service_url      = module.battle.uri
  card_service_url        = module.card.uri
  matchmaking_service_url = module.matchmaking.uri
  account_service_url     = module.account.uri
  shop_service_url        = module.shop.uri
  scenario_service_url    = module.scenario.uri
  news_service_url        = module.news.uri
  support_service_url     = module.support.uri

  matchmaking_timeout_sec = 60

  alert_notification_channel_ids = var.gateway_alert_notification_channel_ids

  pubsub_push_service_account_email = module.pubsub.push_service_account_email
  pubsub_push_audience              = module.pubsub.push_audience

  depends_on = [module.network.service_networking_connection]
}

module "iam_grants" {
  source = "./foundation/iam-grants"

  project_id = var.project_id
  region     = var.region

  cloud_run_service_names = {
    account     = "account"
    card        = "card"
    shop        = "shop"
    scenario    = "scenario"
    matchmaking = "matchmaking"
    news        = "news"
    support     = "support"
    battle      = "battle"
  }
  gateway_service_account_email = module.service_accounts.accounts["gateway"].email

  gateway_cloud_run_service_name = "gateway"

  push_service_account_email = module.pubsub.push_service_account_email
  push_target_cloud_run_service_names = {
    account = "account"
    card    = "card"
    news    = "news"
  }

  ci_deploy_sa_member = local.deploy_sa_member
  cloud_run_runtime_service_account_names = {
    gateway     = module.service_accounts.accounts["gateway"].name
    account     = module.service_accounts.accounts["account"].name
    card        = module.service_accounts.accounts["card"].name
    shop        = module.service_accounts.accounts["shop"].name
    scenario    = module.service_accounts.accounts["scenario"].name
    matchmaking = module.service_accounts.accounts["matchmaking"].name
    news        = module.service_accounts.accounts["news"].name
    support     = module.service_accounts.accounts["support"].name
    battle      = module.service_accounts.accounts["battle"].name
  }

  # 付与先のサービスを名前の文字列で指定しており参照を持たないため、作成順を明示する。
  depends_on = [
    module.account,
    module.battle,
    module.card,
    module.matchmaking,
    module.news,
    module.scenario,
    module.shop,
    module.support,
  ]
}
