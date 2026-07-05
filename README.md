# overload-party-infra

Overload Party の Google Cloud / Cloudflare / Upstash リソースを Terraform で管理するリポジトリ。

関連リポジトリ:
- [keyandnotes-platform](https://github.com/kenyamaneko/keyandnotes-platform)：GKE クラスタ / 共有プラットフォーム基盤
- [overload-party-k8s](https://github.com/kenyamaneko/overload-party-k8s)：k8s マニフェスト・デプロイ

## Package registry (NuGet / npm)

Cross-repo の NuGet / npm package 配布は Cloudsmith を使う。GitHub Actions は OIDC で `overload-party-publisher` / `overload-party-reader` SA を impersonate して push / pull する。
- Terraform 管理: [providers/cloudsmith/](providers/cloudsmith/)
- Cloudsmith 認証 (OIDC) 設定方法: https://docs.cloudsmith.com/integrations/integrating-with-github-actions
