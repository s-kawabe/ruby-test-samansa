# 実装タスク一覧

PR 単位で切り出したタスク一覧。各 PR は TDD（Red → Green → Refactor → Commit）サイクルで進める。

## 要件・設計との対応（MECE チェック）

| 区分 | 内容 | 主担当 PR |
|---|---|---|
| 仮開始・Webhook 先着時の降格防止 | requirements 仮開始 / design §3 | PR3 |
| PURCHASE / RENEW / CANCEL の状態更新 | requirements 本開始・更新・解約 | PR5 |
| Webhook 冪等性（同一通知の再送） | requirements 非機能・design §4 | PR4（受信）+ PR5（処理側の安全策は任意） |
| 分析可能性（課金・通貨・日時の保持） | requirements 非機能・design ペイロード | PR2（スキーマ） |
| 非同期処理 | requirements 非機能・design シーケンス | PR1（Redis 等）+ PR4 + PR5 |
| 仮開始・解約後の視聴判定 | requirements 仮開始・解約シナリオ | PR6 |
| 拡張性（他ストア・プラン） | requirements 技術的制約 | PR2（モデル境界）+ PR7（説明） |

**重複しがちな境界（意図的な切り分け）**

- **PR4** … HTTP での受付・永続化・キュー投入・即時 200 のみ。ビジネス状態の更新はしない。
- **PR5** … サブスクリプション本体の更新・イベント記録・Webhook 先着で active 作成を含む。
- **PR6** … 読み取り専用 API。期限切れは DB ステータスではなく日時比較で導出（design §2 の expired 相当）。

---

## 実施順序

```
PR1（セットアップ）
  └→ PR2（DB設計）
       ├→ PR3（仮開始API）
       └→ PR4（Webhook受信）
            └→ PR5（ジョブ処理）
                 └→ PR6（視聴権限API）
                      └→ PR7（README）
```

---

## PR1: Rails プロジェクト初期セットアップ

- `rails new . --api --database=postgresql`
- Gemfile に `rspec-rails`, `factory_bot_rails`, `sidekiq`, `shoulda-matchers` を追加
- `database.yml` の環境変数化
- Sidekiq 用に Redis をローカル／CI で起動できるようにする（`docker-compose` やサービスコンテナ等。方針は README に一言）
- GitHub Actions の CI 設定（`bundle exec rspec`、Redis が必要なら起動）

---

## PR2: DB マイグレーション & モデル定義

- スキーマ詳細は [design.md](./design.md) の「データベーススキーマ」節に従う
- `subscriptions`（`store` 列を含む。既定 `apple`）
- `webhook_logs`（`notification_type`, `processing_status`, `raw_payload` 等）
- `subscription_events`（`payload_snapshot` は任意）
- 各モデルのバリデーション・インデックス設計
- `status` の状態遷移ルール（`provisional` / `active` / `cancelled`）
- 他ストア Webhook を足しやすいよう、ストア種別や外部 ID を拡張しやすい列・命名を検討する（必須実装ではなく設計余地として）

---

## PR3: `POST /api/v1/subscriptions`（仮開始API）

- `SubscriptionsController#create`
- `transaction_id` をキーに Upsert（既に `active` なら `provisional` に戻さない）
- 正常系・異常系・重複リクエストのテスト

---

## PR4: `POST /api/v1/webhooks/apple`（Webhook受信 + 冪等性）

- `Webhooks::AppleController#create`
- `webhook_logs` への INSERT と `notification_uuid` 重複チェック
- `AppleWebhookProcessorJob` へのエンキュー
- 200 即時返却（ジョブは非同期）
- 重複送信テスト（同じ `notification_uuid` の再送でスキップされること）

---

## PR5: `AppleWebhookProcessorJob`（非同期処理）

- PURCHASE → 仮開始レコードがあれば `active` へ遷移し `expires_date` をセット。なければ `active` で新規作成（design §3 Webhook 先着）
- RENEW → `expires_date` を延長（同一 `transaction_id` で既存を特定）
- CANCEL → `cancelled` に遷移（`expires_date` は変更しない）
- 各処理後に `subscription_events` へイベント記録
- `webhook_logs.status` を `processed` に更新
- 各 type ごとのテスト

---

## PR6: `GET /api/v1/users/:user_id/subscription`（視聴権限確認API）

- `expired` バッチは作らず動的判定で代替（`expires_date` と現在時刻の比較。design.md §2 の expired 相当）
- 判定ロジック：`status IN ('active', 'cancelled') AND expires_date > NOW()`
- レスポンス：`{ viewable: bool, status: string, expires_at: datetime }`（design.md に準拠）
- `provisional` は視聴不可、`active` / `cancelled` かつ期限内は可、期限切れ後は不可のテスト

---

## PR7: README 設計ドキュメント整備

- 設計の概要（全体アーキテクチャ、Webhook 非同期処理の理由）
- 工夫したポイント（冪等性・Webhook 先着ケース・動的視聴判定）
- requirements / design に書いていない判断（例: Webhook 先着・冪等性の意図）は README に短く記載
