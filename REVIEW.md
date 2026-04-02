# コードレビュー: Summa（青色申告用軽量経理入力アプリ）

レビュー日: 2026-04-02  
レビュー対象: `/home/onoue/src/summa`  
使用技術: Ruby 3.4.7 / Rails 8.1.1 / SQLite3 / Hotwire (Turbo + Stimulus)

---

## 総合評価

**良好（実用レベルに達している）**

青色申告向け個人・小規模事業者を対象とした経理アプリとして、必要な機能が過不足なくまとまっています。複式簿記の原則（借貸一致）を徹底し、CSVインポート・年度繰越・科目ロックなど実務上の要件も押さえています。Rails 8 のベストプラクティス（Hotwire, Form Object, Service Object）を適切に活用しており、全体的な設計は水準以上です。

以下に改善を推奨する点を重要度別に整理します。

---

## 高優先度（バグ・データ整合性リスク）

### 1. 伝票番号生成の競合状態（`Voucher#default_number`）

**ファイル:** `app/models/voucher.rb:55-60`

```ruby
def default_number
  date_str = (recorded_on || Date.current).strftime("%Y%m%d")
  last = Voucher.where("voucher_number LIKE ?", "#{date_str}-%").order(:voucher_number).last
  next_seq = last&.voucher_number.to_s.split("-").last.to_i + 1
  format("%<date>s-%<seq>03d", date: date_str, seq: [next_seq, 1].max)
end
```

**問題:** 複数リクエストが同時に実行された場合、同じ伝票番号が生成される可能性があります（TOCTOU競合）。DB側の `UNIQUE` 制約により保存は失敗しますが、ユーザーには「伝票番号が重複しています」という不親切なエラーが表示されます。

**改善案:** `begin...rescue ActiveRecord::RecordNotUnique` でリトライするか、採番専用テーブル（`counters`）を使ったアトミックな採番にする。

---

### 2. `import_rules` テーブルに UNIQUE 制約がない

**ファイル:** `db/schema.rb:59`, `app/models/import_rule.rb:32`

```ruby
rule = find_or_initialize_by(keyword: keyword, direction: direction)
```

`(keyword, direction)` にインデックスはあるが UNIQUE 制約がなく、並行リクエストで同一キーワードのルールが重複して作成されうる。

**改善案:** マイグレーションで `add_index :import_rules, [:keyword, :direction], unique: true` を追加する。

---

### 3. プレビュー→確定インポート時の `rows` JSON 改ざんリスク

**ファイル:** `app/forms/bank_csv_import_form.rb:278`

```ruby
def build_rows
  return JSON.parse(rows).map(&:symbolize_keys) if rows.present?
  ...
end
```

プレビュー画面でパース済みの行データを JSON として hidden フィールドに埋め込み、確定時に再利用する設計です。ユーザーがブラウザの開発者ツールで JSON を書き換えることで、任意の日付・金額・科目コードで伝票を作成できます。

**改善案:** サーバーセッションまたは一時テーブルにパース結果を保存し、クライアントには参照キーのみ渡す。または確定時に必ずファイルから再パースする。

---

## 中優先度（パフォーマンス・設計上の問題）

### 4. N+1クエリ: `expand_account_codes`（子科目展開）

**ファイル:** `app/controllers/vouchers_controller.rb:358-369`

```ruby
def expand_account_codes(code)
  queue = [code]
  while queue.any?
    current = queue.shift
    children = Account.where(parent_code: current).pluck(:code)  # ループ内DB呼出
    ...
  end
end
```

科目の階層が深いほどDBクエリが増加します。

**改善案:** 再帰CTE（`WITH RECURSIVE`）を使うか、全科目を1回ロードしてメモリ上でツリー展開する。

---

### 5. N+1クエリ: `VoucherLine#sync_account_name`

**ファイル:** `app/models/voucher_line.rb:31-35`

```ruby
def sync_account_name
  self.account_master = Account.find_by(code: account_code)
  self.account = account_master&.name
end
```

`before_validation` で毎回 `Account.find_by` を呼ぶため、1つの伝票に n 行あると n 回のDBクエリが発生します。コントローラーで `load_accounts` してキャッシュを持っているにもかかわらず、モデル側は独自にクエリします。

**改善案:** `Account.where(code: voucher_lines.map(&:account_code)).index_by(&:code)` でバッチロードするか、`account_master` のキャッシュを利用する。

---

### 6. N+1クエリ: `QuickVoucherForm` のバリデーション

**ファイル:** `app/forms/quick_voucher_form.rb:68-91`

`account_exists`, `counter_account_exists`, `account_unlocked`, `counter_account_unlocked` の4メソッドがそれぞれ `Account.find_by` を呼び出すため、同じコードを最大4回クエリします。

**改善案:** バリデーション前に科目を2回だけロードして使い回す。

---

### 7. `register_monthly` のメモリ上グルーピング

**ファイル:** `app/controllers/vouchers_controller.rb:102-115`

Ruby 側で月別に集計していますが、SQL の `GROUP BY DATE_TRUNC('month', ...)` 相当の処理で済みます。データ量が増えると全行をメモリに展開するため非効率です（個人利用なら実害は小さい）。

---

### 8. `BankCsvImportForm#column_exists?` でスキーマ照会

**ファイル:** `app/forms/bank_csv_import_form.rb:134-136`

```ruby
def column_exists?(table, column)
  ActiveRecord::Base.connection.column_exists?(table, column)
end
```

保存のたびにスキーマキャッシュを問い合わせています。これは古いマイグレーション対応の名残と思われますが、本番コードに残すべきではありません。当該カラムは schema.rb に存在するので、このチェックは不要です。

---

## 低優先度（コード品質・設計の改善余地）

### 9. 死んだコード: `retried_encoding = false`

**ファイル:** `app/forms/bank_csv_import_form.rb:48`

```ruby
retried_encoding = false  # 宣言のみ、使用されない
```

---

### 10. `parse_only` の可視性制御が不自然

**ファイル:** `app/forms/bank_csv_import_form.rb:328`

```ruby
# private セクションで定義した後に:
public :parse_only
```

`parse_only` を最初から public セクションに定義する方がシンプルです。

---

### 11. 孤立したルート `update_counterpart`

**ファイル:** `config/routes.rb:28-30`

```ruby
resources :voucher_lines, only: [] do
  patch :update_counterpart, on: :member
end
```

`VoucherLinesController` および `update_counterpart` アクションが存在しない（削除済みか未実装）。ルートだけが残っている状態です。

---

### 12. `Voucher#blank_line?` が `:account`（名前）を参照

**ファイル:** `app/models/voucher.rb:62-64`

```ruby
def blank_line?(attrs)
  attrs.slice(:account, :debit_amount, :credit_amount, :note).values.all?(&:blank?)
end
```

ユーザーは `:account_code` を入力しますが、チェック対象が `:account`（名前）になっています。`sync_account_name` が `before_validation` で動くため実質的に問題は出ませんが、意図が明確でなく混乱を招きます。

---

### 13. 会計年度が1月〜12月固定

**ファイル:** `app/models/voucher.rb:3-8`, `app/services/fiscal_year_rollover_service.rb:161-165`

```ruby
where(recorded_on: Date.new(y, 1, 1)..Date.new(y, 12, 31))
```

日本では4月〜3月の事業年度を採用している個人事業主も少なくありません。現状では対応不可能な設計になっています。README や UI に「暦年（1/1〜12/31）のみ対応」と明記することを推奨します。

---

### 14. `FiscalYearRolloverService#opening_voucher_exists?` の重複チェックが脆弱

**ファイル:** `app/services/fiscal_year_rollover_service.rb:147-150`

```ruby
def opening_voucher_exists?
  Voucher.where(recorded_on: opening_date)
         .where("description LIKE ?", "#{opening_marker}%")
         .exists?
end
```

摘要文字列のパターンマッチで重複を判定しています。ユーザーが同じ日付・同じ摘要の伝票を手動作成した場合に誤検知します。`app_settings` に「繰越済み年度」を記録する方が確実です。

---

## 特に良い点（参考として残す設計）

- **借貸バランス検証**: `Voucher#balanced_entries` でモデルレベルの整合性保証
- **科目ロック機能**: 年度繰越後の誤編集を防ぐ仕組みが Voucher・VoucherLine の両レイヤーで実装されている
- **CSV文字コード自動判別**: BOM検出→NKF→UTF-8有効性の3段階フォールバックで実用的
- **インポートルール自動学習**: 伝票作成時に `ImportRule.record_from_voucher` を呼ぶことで次回取込の精度が上がる
- **Form Object の適切な活用**: `BankCsvImportForm`, `QuickVoucherForm` でコントローラーを薄く保てている
- **Service Object**: `FiscalYearRolloverService` の責務分離が明確
- **BigDecimal**: 金融計算に `to_d` を一貫して使用しており浮動小数点誤差なし
- **日本語銀行CSV対応**: 全角マイナス記号の多バリアント・年号日付形式など実務上の細部に対応

---

## テスト状況

**テストがほぼゼロ**（スケルトンのみ）です。最低限、以下のテストを追加することを推奨します。

| 優先度 | テスト対象 |
|--------|-----------|
| 高 | `Voucher` モデルのバリデーション（借貸不一致・ロック科目） |
| 高 | `BankCsvImportForm` の金額・日付パース（多様なフォーマット） |
| 高 | `FiscalYearRolloverService` の繰越計算 |
| 中 | `ImportRule.match_for` のルールマッチング |
| 中 | `VouchersController` の index フィルタリング |
| 低 | `AccountRegisterEntryForm` / `AccountRegisterLineUpdateForm` |

---

## まとめ

| カテゴリ | 件数 |
|----------|------|
| 高優先度（バグ・リスク） | 3件 |
| 中優先度（パフォーマンス・設計） | 5件 |
| 低優先度（コード品質） | 6件 |
| 良い設計として残すべき点 | 8点 |

個人〜小規模利用を前提にすれば、高優先度の3件（特に `rows` JSON改ざんと競合状態）に対処すれば実用上の安全性は確保できます。テストの追加が今後の保守性向上に最も効果的な投資になります。
