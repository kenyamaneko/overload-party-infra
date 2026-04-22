locals {
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

  game_server_sa_account_id = "overload-party-app"

  # GitHub Actions の CI/CD は keyandnotes-platform プロジェクトの github-ci SA に集約しており
  # env ごとに切り替えない。db-migration / newsfeed の Cloud Run Job invoker 等に付与する。
  deploy_sa_member = "serviceAccount:github-ci@keyandnotes-platform.iam.gserviceaccount.com"
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
  db_services      = local.db_services
}

module "database" {
  source = "./data/database"

  project_id                    = var.project_id
  region                        = var.region
  instance_name                 = var.cloudsql_instance_name
  tier                          = var.cloudsql_tier
  database_name                 = var.database_name
  network_id                    = module.network.network_self_link
  service_account_id            = local.game_server_sa_account_id
  ipv4_enabled                  = var.ipv4_enabled
  psc_allowed_consumer_projects = var.psc_allowed_consumer_projects
  deletion_protection           = var.deletion_protection

  service_iam_users = { for svc, _ in local.db_services : svc => module.service_accounts.accounts[svc].email }

  depends_on = [module.network.service_networking_connection]
}

module "pubsub" {
  source = "./data/pubsub"

  project_id                        = var.project_id
  matchmaking_service_account_email = module.service_accounts.accounts["matchmaking"].email
  gateway_service_account_email     = module.service_accounts.accounts["gateway"].email
  scenario_service_account_email    = module.service_accounts.accounts["scenario"].email
  shop_service_account_email        = module.service_accounts.accounts["shop"].email
  account_service_account_email     = module.service_accounts.accounts["account"].email
  card_service_account_email        = module.service_accounts.accounts["card"].email
  newsfeed_service_account_email    = module.service_accounts.accounts["newsfeed"].email
  news_service_account_email        = module.service_accounts.accounts["news"].email
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
  count  = var.migration_image != "" ? 1 : 0
  source = "./ops/db-migration"

  project_id          = var.project_id
  region              = var.region
  migration_image     = var.migration_image
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
  newsfeed_image        = var.newsfeed_image
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
  source = "./app/shop-secrets"

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
