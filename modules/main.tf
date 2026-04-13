locals {
  services = {
    gateway     = "overload-party-gateway"
    matchmaking = "overload-party-matchmaking"
    battle      = "overload-party-battle"
    card        = "overload-party-card"
    account     = "overload-party-account"
    shop        = "overload-party-shop"
    scenario    = "overload-party-scenario"
  }

  db_services = {
    gateway  = "overload-party-gateway"
    battle   = "overload-party-battle"
    card     = "overload-party-card"
    account  = "overload-party-account"
    shop     = "overload-party-shop"
    scenario = "overload-party-scenario"
  }

  game_server_sa_account_id = "overload-party-app"
  newsfeed_sa_account_id    = "overload-party-newsfeed"
}

# ──────────────────────────────────────────────
# ネットワーク
# ──────────────────────────────────────────────

module "network" {
  source = "./network"

  project_id = var.project_id
  region     = var.region
}

# ──────────────────────────────────────────────
# データベース (Cloud SQL PostgreSQL)
# ──────────────────────────────────────────────

module "database" {
  source = "./database"

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

  service_iam_users = merge(
    { for svc, _ in local.db_services : svc => module.service_accounts.accounts[svc].email },
    var.enable_newsfeed ? { newsfeed = google_service_account.newsfeed[0].email } : {}
  )

  depends_on = [module.network.service_networking_connection]
}

# ──────────────────────────────────────────────
# サービス別 GSA + Workload Identity
# ──────────────────────────────────────────────

module "service_accounts" {
  source = "./service-accounts"

  project_id    = var.project_id
  k8s_namespace = var.k8s_namespace
  services      = local.services
  db_services   = local.db_services
}

# ──────────────────────────────────────────────
# Pub/Sub
# ──────────────────────────────────────────────

module "pubsub" {
  source = "./pubsub"

  project_id                        = var.project_id
  matchmaking_service_account_email = module.service_accounts.accounts["matchmaking"].email
  gateway_service_account_email     = module.service_accounts.accounts["gateway"].email
  scenario_service_account_email    = module.service_accounts.accounts["scenario"].email
  shop_service_account_email        = module.service_accounts.accounts["shop"].email
  account_service_account_email     = module.service_accounts.accounts["account"].email
  card_service_account_email        = module.service_accounts.accounts["card"].email
}

# ──────────────────────────────────────────────
# Firestore (game_config store, Native モード)
# ──────────────────────────────────────────────

module "firestore" {
  source = "./firestore"

  project_id  = var.project_id
  location_id = var.firestore_location
  reader_service_account_emails = {
    account  = module.service_accounts.accounts["account"].email
    card     = module.service_accounts.accounts["card"].email
    shop     = module.service_accounts.accounts["shop"].email
    scenario = module.service_accounts.accounts["scenario"].email
    gateway  = module.service_accounts.accounts["gateway"].email
    battle   = module.service_accounts.accounts["battle"].email
  }
}

# ──────────────────────────────────────────────
# Cloud SQL 停止権限 (nightly-shutdown workflow 用)
# ──────────────────────────────────────────────

resource "google_project_iam_member" "deploy_cloudsql_editor" {
  count   = var.deploy_sa != "" ? 1 : 0
  project = var.project_id
  role    = "roles/cloudsql.editor"
  member  = var.deploy_sa
}

# ──────────────────────────────────────────────
# DB マイグレーション (Cloud Run Job)
# ──────────────────────────────────────────────

module "db_migration" {
  count  = var.migration_image != "" ? 1 : 0
  source = "./db-migration"

  project_id                   = var.project_id
  region                       = var.region
  migration_image              = var.migration_image
  network                      = module.network.network_name
  subnetwork                   = module.network.subnetwork_name
  cloudsql_private_ip          = module.database.private_ip_address
  database_name                = var.database_name
  deploy_service_account_email = var.deploy_service_account_email

  depends_on = [module.network.service_networking_connection]
}

# ──────────────────────────────────────────────
# Newsfeed ジョブ
# ──────────────────────────────────────────────

resource "google_service_account" "newsfeed" {
  count        = var.enable_newsfeed ? 1 : 0
  project      = var.project_id
  account_id   = local.newsfeed_sa_account_id
  display_name = "Overload Party Newsfeed (Cloud Run Job)"
}

module "newsfeed" {
  count  = var.enable_newsfeed ? 1 : 0
  source = "./newsfeed"

  project_id                   = var.project_id
  region                       = var.region
  newsfeed_image               = var.newsfeed_image
  network                      = module.network.network_name
  subnetwork                   = module.network.subnetwork_name
  cloudsql_private_ip          = module.database.private_ip_address
  database_name                = var.database_name
  bucket_name                  = var.newsfeed_bucket_name
  service_account_email        = google_service_account.newsfeed[0].email
  deploy_service_account_email = var.deploy_service_account_email

  depends_on = [module.network.service_networking_connection]
}

# ──────────────────────────────────────────────
# Shop IAP シークレット (Secret Manager)
# ──────────────────────────────────────────────

module "shop_secrets" {
  source = "./shop-secrets"

  project_id                 = var.project_id
  shop_service_account_email = module.service_accounts.accounts["shop"].email
}

# ──────────────────────────────────────────────
# ゲームアセット
# ──────────────────────────────────────────────

module "assets" {
  source = "./assets"

  project_id            = var.project_id
  region                = var.region
  assets_bucket_name    = var.assets_bucket_name
  scenarios_bucket_name = var.scenarios_bucket_name
}
