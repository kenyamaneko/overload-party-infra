# 予算アラートの取り込み手順

請求先アカウント `019A0B-9A103A-B4C602` には、コンソールで手作りした予算が先にあった。そこへ terraform が同じプロジェクトの予算を新規に作ったため、dev / stg / prod は予算が 2 つずつある状態になっている。金額と閾値は手作りした側を正とし、terraform が作った側を消して手作りした側を state に取り込む。ops は terraform が作っていないので、取り込みだけを行う。

この手順は一度きりの移行のためのもので、取り込みが済めば以降の予算の変更は通常の apply で足りる。

## 先に読むこと

**この変更を通常の apply で先に流してはいけない。**コードは表示名を手作りした側 (`overload-party-<env>-budget`) に合わせてある。取り込む前に apply すると、terraform が作った予算の表示名と金額が書き換わり、同じ名前の予算が 2 つ並ぶ。どちらが state に載っているか見分けが付かなくなる。

state root ごとに、その root の plan / apply が動いていないことを確かめてから始める。terraform を Ctrl-C で止めてはいけない。GCS のロックを掴んだまま終了し、以降の plan がすべてロック競合で失敗する。

`terraform destroy` と `terraform import` は CI の workflow に無いので、手元で実行する。`TF_VAR_alert_email` が要る (env の 3 root のみ)。

## 対象の予算

| state root | 取り込む予算 (残す側) | 予算 ID | 消す予算 (terraform が作った側) | 予算 ID |
|---|---|---|---|---|
| `google-cloud/env/dev` | `overload-party-dev-budget` ¥1,000 | `e9b42dd0-1ef2-44d8-b68b-f39f45b361aa` | `Overload Party 月次予算 (dev)` ¥15,000 | `3c2a2cd9-6e70-4731-a29c-b31b94ea2ece` |
| `google-cloud/env/stg` | `overload-party-stg-budget` ¥1,000 | `50fff14c-72c0-499a-a2db-ebac6540c35d` | `Overload Party 月次予算 (stg)` ¥15,000 | `37b64f68-aeb6-4af6-9358-a256ee2098d6` |
| `google-cloud/env/prod` | `overload-party-prod-budget` ¥10,000 | `003812b4-407a-4fd4-b00e-78e25ceaaa01` | `Overload Party 月次予算 (prod)` ¥20,000 | `7053ca3c-e3de-41e4-af41-a24a12b23a47` |
| `google-cloud/ops` | `overload-party-ops-budget` ¥200 | `32c57d8b-9262-4be0-b051-4a81adbf701b` | 該当なし | — |

閾値はどれも 50 / 75 / 100 % で揃っている。

リソースアドレスは env が `module.env.module.monitoring.google_billing_budget.monthly`、ops が `module.budget.google_billing_budget.monthly`。

## 手順

### 1. 現物を確かめる

取りかかる前に、表の予算 ID と金額が今も一致することを確かめる。予算はプロジェクトに属さないリソースなので、呼び出しには quota project の指定が要る。

```
curl -s -H "Authorization: Bearer $(gcloud auth print-access-token)" \
  -H "X-Goog-User-Project: overload-party-ops" \
  "https://billingbudgets.googleapis.com/v1/billingAccounts/019A0B-9A103A-B4C602/budgets"
```

### 2. env の 3 root で、terraform が作った予算を消す

dev / stg / prod で順に実行する。`-target` を付けて予算だけを対象にする。付け忘れると root 全体が destroy の対象になる。

```
cd providers/google-cloud/env/dev
terraform init -input=false
terraform destroy -input=false \
  -target='module.env.module.monitoring.google_billing_budget.monthly'
```

消す対象が 1 件だけであることを、実行前の確認プロンプトで確かめる。ops はこの手順を飛ばす。

### 3. 手作りした予算を取り込む

同じアドレスに、表の「残す側」の予算 ID を取り込む。env の 3 root と ops の 4 回行う。

```
terraform import \
  'module.env.module.monitoring.google_billing_budget.monthly' \
  billingAccounts/019A0B-9A103A-B4C602/budgets/e9b42dd0-1ef2-44d8-b68b-f39f45b361aa
```

ops はアドレスが異なる。

```
cd providers/google-cloud/ops
terraform init -input=false
terraform import \
  'module.budget.google_billing_budget.monthly' \
  billingAccounts/019A0B-9A103A-B4C602/budgets/32c57d8b-9262-4be0-b051-4a81adbf701b
```

### 4. 差分が意図した分だけであることを確かめる

```
terraform plan -input=false \
  -target='module.env.module.monitoring.google_billing_budget.monthly'
```

env で出てよい差分は、通知先チャンネル (`all_updates_rule.monitoring_notification_channels`) の追加だけ。手作りした予算は通知先を持たず、請求先アカウントの管理者にだけ通知が届く状態になっている。取り込みでメールと Slack のチャンネルが付く。

ops で出てよい差分は無い。`all_updates_rule` の差分が出る場合は、通知先を持たない予算を API がどう返すかとコードの書き方が食い違っている。その場合は 5 の後にもう一度 plan し、差分が残るなら `ops/modules/budget/main.tf` の `all_updates_rule` の有無を実物に合わせる。

金額・閾値・表示名に差分が出たら、コードか取り込んだ予算 ID のどちらかが誤っている。apply せずに戻る。

### 5. apply する

4 で確かめた差分をそのまま適用する。

```
terraform apply -input=false \
  -target='module.env.module.monitoring.google_billing_budget.monthly'
```

以降は `-target` 無しの通常の apply でよい。

### 6. 予算が 1 プロジェクト 1 件になったことを確かめる

1 と同じ呼び出しで一覧を取り、`Overload Party 月次予算 (dev / stg / prod)` が消えていること、`overload-party-<env>-budget` と `overload-party-ops-budget` が残っていることを確かめる。

## 予算を足すとき

予算はコンソールからも作れるので、terraform に書く前に請求先アカウントの一覧を見て、同じプロジェクトの予算が既にあるかを確かめる。今回の重複はこの確認を飛ばしたために起きた。既にあるなら新規に作らず、`terraform import` で取り込む。
