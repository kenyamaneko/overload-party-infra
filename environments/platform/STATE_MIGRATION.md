# State Migration: k8s → infra

WIF プール・CI SA・Terraform SA を k8s リポの Terraform state から infra リポの state に移管する手順。

## 前提

- infra リポの `environments/platform/` と `modules/ci-cd/` が main にマージ済み
- k8s リポの変更はまだマージ **していない** 状態で実施する

## 手順

### 1. infra 側で import

```bash
cd overload-party-infra/environments/platform
terraform init

# WIF プール
terraform import \
  'module.ci_cd.google_iam_workload_identity_pool.github' \
  'projects/keyandnotes-platform/locations/global/workloadIdentityPools/github-actions'

terraform import \
  'module.ci_cd.google_iam_workload_identity_pool_provider.github' \
  'projects/keyandnotes-platform/locations/global/workloadIdentityPools/github-actions/providers/github'

# CI SA
terraform import \
  'module.ci_cd.google_service_account.ci' \
  'projects/keyandnotes-platform/serviceAccounts/github-ci@keyandnotes-platform.iam.gserviceaccount.com'

# Terraform SA
terraform import \
  'module.ci_cd.google_service_account.terraform' \
  'projects/keyandnotes-platform/serviceAccounts/terraform-deployer@keyandnotes-platform.iam.gserviceaccount.com'

# AR writer (CI SA)
terraform import \
  'module.ci_cd.google_artifact_registry_repository_iam_member.ci_ar_writer' \
  'projects/keyandnotes-platform/locations/asia-northeast1/repositories/overload-party/roles/artifactregistry.writer/serviceAccount:github-ci@keyandnotes-platform.iam.gserviceaccount.com'

# Terraform SA editor role
terraform import \
  'module.ci_cd.google_project_iam_member.terraform_editor' \
  'keyandnotes-platform roles/editor serviceAccount:terraform-deployer@keyandnotes-platform.iam.gserviceaccount.com'

# CI SA WIF bindings (1つずつ)
for repo in overload-party-analytics overload-party-battle overload-party-client overload-party-common overload-party-gateway overload-party-infra overload-party-newsfeed overload-party-ops; do
  terraform import \
    "module.ci_cd.google_service_account_iam_member.ci_wif[\"${repo}\"]" \
    "projects/keyandnotes-platform/serviceAccounts/github-ci@keyandnotes-platform.iam.gserviceaccount.com roles/iam.workloadIdentityUser principalSet://iam.googleapis.com/projects/keyandnotes-platform/locations/global/workloadIdentityPools/github-actions/attribute.repository/kenyamaneko/${repo}"
done

# Terraform SA WIF bindings
for repo in overload-party-infra overload-party-k8s; do
  terraform import \
    "module.ci_cd.google_service_account_iam_member.terraform_wif[\"${repo}\"]" \
    "projects/keyandnotes-platform/serviceAccounts/terraform-deployer@keyandnotes-platform.iam.gserviceaccount.com roles/iam.workloadIdentityUser principalSet://iam.googleapis.com/projects/keyandnotes-platform/locations/global/workloadIdentityPools/github-actions/attribute.repository/kenyamaneko/${repo}"
done

# AR reader (Cloud Run Service Agent)
terraform import \
  'google_artifact_registry_repository_iam_member.cloudrun_ar_reader["dev"]' \
  'projects/keyandnotes-platform/locations/asia-northeast1/repositories/overload-party/roles/artifactregistry.reader/serviceAccount:service-346314225010@serverless-robot-prod.iam.gserviceaccount.com'
```

### 2. plan で差分確認

```bash
terraform plan
```

**期待する結果:**
- import 済みリソースは差分なし
- 新規追加のみ表示される:
  - `ci_cloudfunctions_developer`（analytics 用 Cloud Functions 権限）
  - `ci_cloudbuild_editor`（同上）
  - `ci_service_account_user`（同上）
  - `ci_run_developer`（ops・newsfeed 用 Cloud Run 権限）
  - `overload-party-analytics` の WIF binding

### 3. apply

```bash
terraform apply
```

### 4. k8s 側から移管済みリソースを除去

k8s リポの変更をマージし、apply する。

```bash
cd overload-party-k8s/terraform/environments/platform

# 移管済みリソースを state から除去
terraform state rm 'module.ci_cd.google_iam_workload_identity_pool.github'
terraform state rm 'module.ci_cd.google_iam_workload_identity_pool_provider.github'
terraform state rm 'module.ci_cd.google_service_account.ci'
terraform state rm 'module.ci_cd.google_service_account.terraform'
terraform state rm 'module.ci_cd.google_artifact_registry_repository_iam_member.ci_ar_writer'
terraform state rm 'module.ci_cd.google_project_iam_member.terraform_editor'
terraform state rm 'google_artifact_registry_repository_iam_member.cloudrun_ar_reader["dev"]'

# CI SA WIF bindings
for repo in overload-party-battle overload-party-client overload-party-common overload-party-gateway overload-party-infra overload-party-newsfeed overload-party-ops; do
  terraform state rm "module.ci_cd.google_service_account_iam_member.ci_wif[\"${repo}\"]"
done

# Terraform SA WIF bindings
for repo in overload-party-infra overload-party-k8s; do
  terraform state rm "module.ci_cd.google_service_account_iam_member.terraform_wif[\"${repo}\"]"
done

# plan で確認（deploy SA 以外の差分がないこと）
terraform plan
```

### 5. k8s 側を apply

```bash
terraform apply
```

## 実行順序（重要）

```
1. infra: terraform import  （既存リソースを取り込み）
2. infra: terraform plan     （差分なし確認）
3. infra: terraform apply    （新規権限の追加）
4. k8s:   terraform state rm （移管済みリソースを state から除去）
5. k8s:   terraform plan     （差分確認）
6. k8s:   terraform apply    （モジュール縮小の反映）
```

この順序を守れば、リソースが破壊されることはない。
