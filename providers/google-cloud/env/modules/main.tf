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

  # サービスの定義。用途ごとの集合はここから導く。
  # unauthenticated: gateway は外部からの唯一の入口のため許可する。shop は Apple Server
  # Notifications V2 が Google IAM で署名できず allUsers 以外の選択肢が無いため許可する。
  services = {
    account     = { uses_db = true, push_target = true, unauthenticated = false }
    battle      = { uses_db = true, push_target = false, unauthenticated = false }
    card        = { uses_db = true, push_target = true, unauthenticated = false }
    gateway     = { uses_db = true, push_target = true, unauthenticated = true }
    matchmaking = { uses_db = false, push_target = false, unauthenticated = false }
    news        = { uses_db = true, push_target = true, unauthenticated = false }
    newsfeed    = { uses_db = false, push_target = false, unauthenticated = false }
    scenario    = { uses_db = true, push_target = false, unauthenticated = false }
    shop        = { uses_db = true, push_target = true, unauthenticated = true }
    support     = { uses_db = true, push_target = false, unauthenticated = false }
  }

  db_services = { for svc, attributes in local.services : svc => "overload-party-${svc}" if attributes.uses_db }

  # GitHub Actions の CI/CD は overload-party-ops プロジェクトの github-ci SA に集約しており
  # env ごとに切り替えない。db-migration / newsfeed の Cloud Run Job invoker 等に付与する。
  deploy_sa_member = "serviceAccount:github-ci@overload-party-ops.iam.gserviceaccount.com"

  cloud_run_images = {
    for svc, _ in local.k8s_services : svc => "asia-northeast1-docker.pkg.dev/keyandnotes-platform/overload-party/${svc}:latest"
  }

  cloudsql_connection_name = "${var.project_id}:${var.region}:${var.cloudsql_instance_name}"

  # news/support の config.go は "staging" | "production" のみ要求するため、dev/stg は staging、prod のみ production とする。
  staging_or_production_env = var.env_name == "prod" ? "production" : "staging"

  standard_resources = {
    dev  = { cpu = "100m", memory = "128Mi" }
    stg  = { cpu = "200m", memory = "256Mi" }
    prod = { cpu = "200m", memory = "256Mi" }
  }
  # Cloud Run は同時実行数が 1 を超えるとき 1 vCPU 未満を許さないため、dev も 1 にする。
  battle_resources = {
    dev  = { cpu = "1", memory = "512Mi" }
    stg  = { cpu = "1", memory = "1Gi" }
    prod = { cpu = "1", memory = "1Gi" }
  }
  gateway_resources                  = { cpu = "1", memory = "512Mi" }
  gateway_max_concurrent_connections = 250
  gateway_request_timeout_sec        = 3600

  # シークレット自体は upstash provider の state が作る (providers/upstash/env/modules/gateway)。
  # state をまたぐため名前で参照する。
  gateway_upstash_redis_url_secret_id = "gateway-upstash-redis-url"

  # IAM の付与がサービスの作成後に走るよう Terraform に依存を組ませるため、サービス名は
  # リテラルではなくモジュールの出力を経由して渡す。
  cloud_run_service_names = {
    account     = module.account.service_name
    battle      = module.battle.service_name
    card        = module.card.service_name
    gateway     = module.gateway.service_name
    matchmaking = module.matchmaking.service_name
    news        = module.news.service_name
    scenario    = module.scenario.service_name
    shop        = module.shop.service_name
    support     = module.support.service_name
  }

  push_target_cloud_run_service_names = {
    for svc, attributes in local.services : svc => local.cloud_run_service_names[svc] if attributes.push_target
  }

  unauthenticated_cloud_run_service_names = {
    for svc, attributes in local.services : svc => local.cloud_run_service_names[svc] if attributes.unauthenticated
  }

  # 実在するサービス間呼び出しの一覧。各サービスの config が持つ *_SERVICE_URL /
  # *_BASE_URL から洗い出したもの。Cloud Run は呼び出しごとに run.invoker を要求するため、
  # 呼び出しを増やすときはここに足す。
  internal_call_targets = {
    gateway = ["account", "card", "matchmaking", "news", "scenario", "shop", "support", "battle"]
    battle  = ["card"]
    card    = ["account"]
    # scenario は ACCOUNT_BASE_URL でアンロック判定時に account を呼ぶ。
    scenario = ["account"]
  }

  internal_calls = merge([
    for caller, callees in local.internal_call_targets : {
      for callee in callees : "${caller}_to_${callee}" => {
        caller_service_account_email = module.service_accounts.accounts[caller].email
        callee_service_name          = local.cloud_run_service_names[callee]
      }
    }
  ]...)

  # dev と stg は動作確認やテストでエラーパスを意図的に踏み、そのまま発報させると通知が
  # 埋もれるため、単発のエラーでは発報しない閾値にする。
  # 5xx を返す障害は ERROR ログにも現れて 1 件の障害で二度発報するため、prod でも要求の
  # 失敗は 5xx の監視に任せ、ERROR ログは単発では発報しない閾値にする。
  alert_thresholds = {
    dev  = { server_error_count = 5, error_log_count = 20 }
    stg  = { server_error_count = 1, error_log_count = 5 }
    prod = { server_error_count = 0, error_log_count = 2 }
  }

  # 資源の逼迫は環境によらず同じ割合で危険なため、使用率の閾値は env で変えない。
  database_utilization_thresholds = { cpu = 0.9, memory = 0.9, disk = 0.85 }

  # pgxpool の既定は max(4, NumCPU) で、インスタンス数を絞っても接続数の上限は決まらない。
  # 上限を握るのはプール側なので明示する。効くのは Go の 7 サービスだけで、Npgsql を使う
  # battle には効かない (overload-party-battle#260)。
  database_pool_max_conns = 2

  # 接続数の上限は max_connections がマシンタイプで変わるため env ごとに置く。既定は
  # db-f1-micro が 25、db-g1-small が 50。
  # gateway は最大 1 インスタンスに固定されているため、pgxpool を使う他の 6 サービス
  # (account / card / shop / scenario / news / support) と分けて数える。
  # 3 環境とも 6 × 1 × 2 + gateway 2 = 14 まで Go 側が健全に張りうる。それを超えた
  # ところで鳴らす。マシンタイプか最大インスタンス数を env ごとに変えたらここも変える。
  database_connection_count_thresholds = {
    dev  = 18
    stg  = 18
    prod = 18
  }

  # 監視対象の Cloud Run ジョブ。サービスと違い一覧から導けないため、ジョブを増やしたらここに足す。
  monitored_jobs = {
    newsfeed = module.newsfeed.job_name
  }

  # ジョブは要求を受けず動作確認のエラーが紛れ込まないため、環境を問わず 1 件の失敗で発報する。
  job_failed_task_attempt_count_threshold = 0

  # 最小インスタンス数 0 でインスタンスが常時停止しており、計測される応答時間にコールド
  # スタートが含まれるため、秒単位の余裕を持たせる。
  standard_latency_p95_threshold_ms = 20000

  # .NET ランタイムの起動が Go より重いため、battle だけ上限を広く取る。
  battle_latency_p95_threshold_ms = 45000

  # gateway の応答時間は WebSocket 接続が切れるまでの時間そのものになり応答の遅さを
  # 表さないため、gateway だけ応答時間を監視しない。
  service_latency_p95_threshold_ms = {
    account     = local.standard_latency_p95_threshold_ms
    battle      = local.battle_latency_p95_threshold_ms
    card        = local.standard_latency_p95_threshold_ms
    gateway     = null
    matchmaking = local.standard_latency_p95_threshold_ms
    news        = local.standard_latency_p95_threshold_ms
    scenario    = local.standard_latency_p95_threshold_ms
    shop        = local.standard_latency_p95_threshold_ms
    support     = local.standard_latency_p95_threshold_ms
  }
}

module "network" {
  source = "./foundation/network"

  project_id = var.project_id
  region     = var.region
}

module "service_accounts" {
  source = "./foundation/service-accounts"

  project_id       = var.project_id
  k8s_services     = local.k8s_services
  non_k8s_services = local.non_k8s_services
}

module "monitoring" {
  source = "./foundation/monitoring"

  project_id                    = var.project_id
  env_name                      = var.env_name
  alert_email                   = var.alert_email
  slack_notification_channel_id = var.alert_slack_notification_channel_id
  billing_account_id            = var.billing_account_id
  monthly_budget_jpy            = var.monthly_budget_jpy
}

module "service_monitoring" {
  for_each = local.k8s_services

  source = "./foundation/service-monitoring"

  project_id                   = var.project_id
  service_name                 = each.key
  notification_channel_ids     = module.monitoring.notification_channel_ids
  server_error_count_threshold = local.alert_thresholds[var.env_name].server_error_count
  error_log_count_threshold    = local.alert_thresholds[var.env_name].error_log_count
  latency_p95_threshold_ms     = local.service_latency_p95_threshold_ms[each.key]
}

module "job_monitoring" {
  for_each = local.monitored_jobs

  source = "./foundation/job-monitoring"

  project_id                          = var.project_id
  job_name                            = each.value
  notification_channel_ids            = module.monitoring.notification_channel_ids
  failed_task_attempt_count_threshold = local.job_failed_task_attempt_count_threshold
}

module "database_monitoring" {
  source = "./foundation/database-monitoring"

  project_id               = var.project_id
  instance_name            = module.database.instance_name
  notification_channel_ids = module.monitoring.notification_channel_ids

  cpu_utilization_threshold    = local.database_utilization_thresholds.cpu
  memory_utilization_threshold = local.database_utilization_thresholds.memory
  disk_utilization_threshold   = local.database_utilization_thresholds.disk
  connection_count_threshold   = local.database_connection_count_thresholds[var.env_name]
}

module "database" {
  source = "./data/database"

  project_id          = var.project_id
  region              = var.region
  instance_name       = var.cloudsql_instance_name
  tier                = var.cloudsql_tier
  database_name       = var.database_name
  network_id          = module.network.network_self_link
  ipv4_enabled        = var.ipv4_enabled
  deletion_protection = var.deletion_protection

  db_users = { for svc, _ in local.db_services : svc => module.service_accounts.accounts[svc].email }

  depends_on = [module.network.service_networking_connection]
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
  shop_service_url    = module.shop.uri
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
  bucket_name           = var.newsfeed_bucket_name
  service_account_email = module.service_accounts.accounts["newsfeed"].email
  deploy_sa_member      = local.deploy_sa_member
  scheduler_paused      = var.newsfeed_scheduler_paused

  news_article_collected_topic = module.pubsub.news_article_collected_topic

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

module "master_data" {
  source = "./app/master-data"

  project_id                   = var.project_id
  region                       = var.region
  bucket_name                  = var.master_data_bucket_name
  deploy_sa_member             = local.deploy_sa_member
  battle_service_account_email = module.service_accounts.accounts["battle"].email
}

module "e2e" {
  count  = var.enable_e2e ? 1 : 0
  source = "./jobs/e2e"

  project_id        = var.project_id
  developer_members = var.e2e_developer_members
}

module "internal_auth_key" {
  source = "./foundation/internal-auth-key"

  project_id                   = var.project_id
  signer_service_account_email = module.service_accounts.accounts["gateway"].email
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
  db_pool_max_conns        = local.database_pool_max_conns
  max_instance_count       = var.cloud_run_max_instance_count
  resources_limit_cpu      = local.standard_resources[var.env_name].cpu
  resources_limit_memory   = local.standard_resources[var.env_name].memory
  internal_auth_public_key = var.internal_auth_public_key

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
  db_pool_max_conns        = local.database_pool_max_conns
  max_instance_count       = var.cloud_run_max_instance_count
  resources_limit_cpu      = local.standard_resources[var.env_name].cpu
  resources_limit_memory   = local.standard_resources[var.env_name].memory
  internal_auth_public_key = var.internal_auth_public_key

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
  db_pool_max_conns        = local.database_pool_max_conns
  max_instance_count       = var.cloud_run_max_instance_count
  resources_limit_cpu      = local.standard_resources[var.env_name].cpu
  resources_limit_memory   = local.standard_resources[var.env_name].memory
  internal_auth_public_key = var.internal_auth_public_key

  faction_acquired_topic    = "faction-acquired"
  card_pack_purchased_topic = "card-pack-purchased"
  premium_updated_topic     = "premium-updated"
  iap_verifier              = var.shop_iap_verifier
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
  db_pool_max_conns        = local.database_pool_max_conns
  max_instance_count       = var.cloud_run_max_instance_count
  resources_limit_cpu      = local.standard_resources[var.env_name].cpu
  resources_limit_memory   = local.standard_resources[var.env_name].memory
  internal_auth_public_key = var.internal_auth_public_key

  story_bucket                 = "overload-party-${var.env_name}-story"
  player_onboarded_topic       = "player-onboarded"
  onboarding_name_set_topic    = "onboarding-name-set"
  onboarding_faction_set_topic = "onboarding-faction-set"
  account_base_url             = module.account.uri

  depends_on = [module.network.service_networking_connection]
}

module "matchmaking" {
  source = "./app/matchmaking"

  project_id               = var.project_id
  region                   = var.region
  image                    = local.cloud_run_images["matchmaking"]
  service_account_email    = module.service_accounts.accounts["matchmaking"].email
  max_instance_count       = var.cloud_run_max_instance_count
  resources_limit_cpu      = local.standard_resources[var.env_name].cpu
  resources_limit_memory   = local.standard_resources[var.env_name].memory
  internal_auth_public_key = var.internal_auth_public_key
  match_made_topic         = "matchmaking-events"
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
  db_pool_max_conns        = local.database_pool_max_conns
  max_instance_count       = var.cloud_run_max_instance_count
  resources_limit_cpu      = local.standard_resources[var.env_name].cpu
  resources_limit_memory   = local.standard_resources[var.env_name].memory
  internal_auth_public_key = var.internal_auth_public_key

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
  db_pool_max_conns        = local.database_pool_max_conns
  max_instance_count       = var.cloud_run_max_instance_count
  resources_limit_cpu      = local.standard_resources[var.env_name].cpu
  resources_limit_memory   = local.standard_resources[var.env_name].memory

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
  max_instance_count       = var.cloud_run_max_instance_count
  resources_limit_cpu      = local.battle_resources[var.env_name].cpu
  resources_limit_memory   = local.battle_resources[var.env_name].memory

  card_service_url   = module.card.uri
  master_data_bucket = module.master_data.bucket_name

  # 読み取り権限が付く前にリビジョンを作ると battle が起動時にマスターデータを取得できないため、
  # バケットと権限付与の完了を待つ。
  depends_on = [
    module.network.service_networking_connection,
    module.master_data,
  ]
}

module "gateway" {
  source = "./app/gateway"

  project_id                          = var.project_id
  region                              = var.region
  env_name                            = var.env_name
  image                               = local.cloud_run_images["gateway"]
  container_port                      = 9090
  max_concurrent_connections          = local.gateway_max_concurrent_connections
  request_timeout_sec                 = local.gateway_request_timeout_sec
  resources_limit_cpu                 = local.gateway_resources.cpu
  resources_limit_memory              = local.gateway_resources.memory
  service_account_email               = module.service_accounts.accounts["gateway"].email
  network                             = module.network.network_name
  subnetwork                          = module.network.subnetwork_name
  cloudsql_connection_name            = local.cloudsql_connection_name
  database_name                       = var.database_name
  db_pool_max_conns                   = local.database_pool_max_conns
  internal_auth_private_key_secret_id = module.internal_auth_key.secret_id

  upstash_redis_url_secret_id = local.gateway_upstash_redis_url_secret_id

  allowed_origins         = var.gateway_allowed_origins
  battle_service_url      = module.battle.uri
  card_service_url        = module.card.uri
  matchmaking_service_url = module.matchmaking.uri
  account_service_url     = module.account.uri
  shop_service_url        = module.shop.uri
  scenario_service_url    = module.scenario.uri
  news_service_url        = module.news.uri
  support_service_url     = module.support.uri

  matchmaking_timeout_sec = 30

  pubsub_push_service_account_email = module.pubsub.push_service_account_email
  pubsub_push_audience              = module.pubsub.push_audience

  depends_on = [module.network.service_networking_connection]
}

module "iam_grants" {
  source = "./foundation/iam-grants"

  project_id = var.project_id
  region     = var.region

  internal_calls = local.internal_calls

  unauthenticated_cloud_run_service_names = local.unauthenticated_cloud_run_service_names

  push_service_account_email          = module.pubsub.push_service_account_email
  push_target_cloud_run_service_names = local.push_target_cloud_run_service_names

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
}
