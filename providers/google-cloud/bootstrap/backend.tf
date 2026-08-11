# CI 自身の認証経路 (WIF プール) と state 保存先を管理するため、CI が日常的に apply する
# ops root と同居させず、人間がローカルから手動で apply する root として分離する。
terraform {
  backend "gcs" {
    bucket = "overload-party-tfstate"
    prefix = "bootstrap"
  }
}
