# 仕様書

## API インターフェース

### クライアント → サーバ（決済完了直後）

`POST /api/v1/subscriptions`

```json
{
  "user_id": "string",
  "transaction_id": "string",
  "product_id": "string"
}
```

| フィールド | 説明 |
|---|---|
| user_id | ユーザー識別子（今回はパラメータで受け取る、検証不要） |
| transaction_id | サブスクリプションを一意に識別する ID。自動更新されても同じ値 |
| product_id | サブスクリプションプランの ID（例: com.samansa.subscription.monthly） |

### Apple → サーバ（Webhook）

`POST /api/v1/webhooks/apple`

```json
{
  "notification_uuid": "string",
  "type": "PURCHASE | RENEW | CANCEL",
  "transaction_id": "string",
  "product_id": "string",
  "amount": "3.9",
  "currency": "USD",
  "purchase_date": "2025-10-01T12:00:00Z",
  "expires_date": "2025-11-01T12:00:00Z"
}
```

| フィールド | 説明 |
|---|---|
| notification_uuid | 通知ごとに一意の値（冪等性チェックに使用） |
| type | PURCHASE: 新規購入 / RENEW: 自動更新 / CANCEL: 解約 |
| transaction_id | サブスクリプションを一意に識別する ID |
| product_id | サブスクリプションプランの ID |
| amount / currency | 課金金額と通貨 |
| purchase_date | 現在のサブスクリプション期間の開始日時 |
| expires_date | 次回更新またはサブスクリプション終了日時 |

### サーバ → クライアント（視聴権限確認）

`GET /api/v1/users/:user_id/subscription`

```json
{
  "viewable": true,
  "status": "active",
  "expires_at": "2025-11-01T12:00:00Z"
}
```

| フィールド | 説明 |
|---|---|
| viewable | 視聴可否（`status IN ('active', 'cancelled') AND expires_date > NOW()`） |
| status | サブスクリプションの現在ステータス |
| expires_at | 有効期限（`cancelled` の場合は視聴可能期限） |

---

## データベーススキーマ

RDBMS は PostgreSQL を想定する。時刻はすべて `timestamptz`（UTC 保存）とする。

### ER 概要

```mermaid
erDiagram
  subscriptions ||--o{ subscription_events : has

  subscriptions {
    bigint id PK
    string user_id
    string transaction_id UK
    string product_id
    string store
    string status
    timestamptz purchase_date
    timestamptz expires_date
    decimal amount
    string currency
    timestamptz created_at
    timestamptz updated_at
  }

  subscription_events {
    bigint id PK
    bigint subscription_id FK
    string event_type
    timestamptz occurred_at
    jsonb payload_snapshot
    timestamptz created_at
  }

  webhook_logs {
    bigint id PK
    string notification_uuid UK
    string notification_type
    string transaction_id
    jsonb raw_payload
    string processing_status
    text error_message
    timestamptz created_at
    timestamptz updated_at
  }
```

### `subscriptions`

サブスクリプションの現在状態を表す。同一 `transaction_id` はアプリ内で一意（自動更新でも不変）。

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| `id` | `bigint` | NO | 主キー |
| `user_id` | `string` | NO | ユーザー識別子（API の `user_id` と同一） |
| `transaction_id` | `string` | NO | Apple 課金トランザクション ID（一意） |
| `product_id` | `string` | NO | プラン ID |
| `store` | `string` | NO | 課金ストア。既定値 `apple`（将来の Google Play 等の判別用） |
| `status` | `string` | NO | `provisional` / `active` / `cancelled` |
| `purchase_date` | `timestamptz` | YES | 現在の課金期間の開始（Webhook で更新） |
| `expires_date` | `timestamptz` | YES | 次回更新日または終了日時 |
| `amount` | `decimal(12, 4)` | YES | 直近通知の課金額（分析用） |
| `currency` | `string(3)` | YES | ISO 4217（例: USD） |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**インデックス**

- `UNIQUE (transaction_id)`
- `INDEX (user_id)` — 視聴権限 API でのユーザー単位取得用

**備考**

- `expired` は DB に持たない。`expires_date` と現在時刻の比較で導出する（状態遷移図の `expired` は論理状態）。

### `webhook_logs`

受信した Apple Webhook の受付・冪等性・処理状態を記録する。`notification_uuid` で重複受信を検知する。

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| `id` | `bigint` | NO | 主キー |
| `notification_uuid` | `string` | NO | 通知ごとに一意（冪等キー） |
| `notification_type` | `string` | NO | `PURCHASE` / `RENEW` / `CANCEL`（JSON の `type` に対応） |
| `transaction_id` | `string` | YES | ペイロードから抽出。トラブルシュート用 |
| `raw_payload` | `jsonb` | NO | 受信ボディのスナップショット |
| `processing_status` | `string` | NO | 例: `pending` / `processed` / `failed` |
| `error_message` | `text` | YES | ジョブ失敗時のメッセージ |
| `created_at` | `timestamptz` | NO | |
| `updated_at` | `timestamptz` | NO | |

**インデックス**

- `UNIQUE (notification_uuid)`

### `subscription_events`

課金ライフサイクルのイベント履歴（分析・監査用）。`subscriptions` の現在値と併せて時系列を再構成できる。

| カラム | 型 | NULL | 説明 |
|---|---|---|---|
| `id` | `bigint` | NO | 主キー |
| `subscription_id` | `bigint` | NO | `subscriptions.id` への外部キー |
| `event_type` | `string` | NO | `PURCHASE` / `RENEW` / `CANCEL` |
| `occurred_at` | `timestamptz` | NO | イベント発生時刻（通常は Webhook の解釈時刻） |
| `payload_snapshot` | `jsonb` | YES | 当該通知の主要フィールドのコピー（任意。分析のしやすさ用） |
| `created_at` | `timestamptz` | NO | |

**インデックス**

- `INDEX (subscription_id, occurred_at)`

---

## 1. 全体シーケンス（正常系）

```mermaid
sequenceDiagram
    actor User as ユーザー（アプリ）
    participant Apple as Apple IAP
    participant API as Rails API
    participant DB as Database
    participant Queue as Job Queue (Sidekiq)
    participant Worker as Background Worker

    Note over User, Apple: ① アプリ内課金フロー
    User->>Apple: サブスクリプション購入
    Apple-->>User: 決済完了 + transaction_id

    Note over User, DB: ② 仮開始（クライアント → サーバ）
    User->>API: POST /api/v1/subscriptions<br/>{ user_id, transaction_id, product_id }
    API->>DB: subscriptions を provisional で Upsert
    API-->>User: 201 Created<br/>{ status: "provisional" }

    Note over User: 仮開始中は視聴不可

    Note over Apple, Worker: ③ Webhook受信（Apple → サーバ）
    Apple->>API: POST /api/v1/webhooks/apple<br/>{ notification_uuid, type: PURCHASE, ... }
    API->>DB: webhook_logs に保存（重複チェック）
    API->>Queue: AppleWebhookProcessorJob をエンキュー
    API-->>Apple: 200 OK（即時返却）

    Queue->>Worker: ジョブ実行
    Worker->>DB: subscriptions を active に更新<br/>expires_date をセット
    Worker->>DB: subscription_events に PURCHASE を追記
    Worker->>DB: webhook_logs.status を processed に更新

    Note over User: ✅ 視聴可能になる

    Note over Apple, Worker: ④ 自動更新（RENEW）
    Apple->>API: POST /api/v1/webhooks/apple<br/>{ type: RENEW, transaction_id, expires_date(新) }
    API->>DB: webhook_logs に保存（重複チェック）
    API->>Queue: エンキュー
    API-->>Apple: 200 OK
    Worker->>DB: subscriptions.expires_date を延長
    Worker->>DB: subscription_events に RENEW を追記

    Note over Apple, Worker: ⑤ 解約（CANCEL）
    Apple->>API: POST /api/v1/webhooks/apple<br/>{ type: CANCEL, transaction_id }
    API->>DB: webhook_logs に保存（重複チェック）
    API->>Queue: エンキュー
    API-->>Apple: 200 OK
    Worker->>DB: subscriptions.status を cancelled に更新
    Worker->>DB: subscription_events に CANCEL を追記

    Note over User: ⚠️ expires_date まで視聴可能<br/>期限切れ後は視聴不可
```

---

## 2. 状態遷移図

```mermaid
stateDiagram-v2
    [*] --> provisional: クライアントAPI受信<br/>POST /api/v1/subscriptions

    provisional --> active: Webhook PURCHASE
    active --> active: Webhook RENEW<br/>（expires_date 延長）
    active --> cancelled: Webhook CANCEL

    cancelled --> expired: expires_date 経過

    note right of provisional
        視聴不可
    end note

    note right of active
        視聴可能
        expires_date > NOW()
    end note

    note right of cancelled
        expires_date まで視聴可能
        status=cancelled かつ expires_date > NOW()
    end note

    note right of expired
        視聴不可
    end note
```

---

## 3. Webhook競合ケース（順序逆転）

> Webhookがクライアント通知より先に届いた場合の安全な処理フロー

```mermaid
sequenceDiagram
    actor User as ユーザー（アプリ）
    participant Apple as Apple
    participant API as Rails API
    participant DB as Database

    Note over Apple, DB: Webhookが先に到達するケース

    Apple->>API: POST /api/v1/webhooks/apple<br/>{ type: PURCHASE, transaction_id: "txn_abc" }
    API->>DB: subscriptions を active で Upsert<br/>（レコードなければ新規作成）
    API-->>Apple: 200 OK

    Note over User, DB: 後からクライアント通知が到達

    User->>API: POST /api/v1/subscriptions<br/>{ transaction_id: "txn_abc", ... }
    API->>DB: find_or_initialize_by(transaction_id)<br/>→ 既に active → provisional に戻さない
    API-->>User: 201 Created / 200 OK<br/>{ status: "active" }
```

---

## 4. 冪等性保証フロー（Webhook重複受信）

```mermaid
sequenceDiagram
    participant Apple as Apple
    participant API as Rails API
    participant DB as Database

    Apple->>API: POST /api/v1/webhooks/apple<br/>{ notification_uuid: "uuid-001", type: PURCHASE }
    API->>DB: webhook_logs で notification_uuid チェック
    DB-->>API: 未処理（レコードなし）
    API->>DB: webhook_logs に INSERT
    API-->>Apple: 200 OK
    Note over DB: 通常処理で subscriptions 更新

    Note over Apple: ネットワーク障害等でリトライ

    Apple->>API: POST /api/v1/webhooks/apple<br/>{ notification_uuid: "uuid-001", type: PURCHASE }（再送）
    API->>DB: webhook_logs で notification_uuid チェック
    DB-->>API: 処理済み（レコードあり）
    API-->>Apple: 200 OK（スキップ）
    Note over DB: subscriptions は変更しない
```
