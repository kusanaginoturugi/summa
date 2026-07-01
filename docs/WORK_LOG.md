# Work Log

## 2026-07-01

- `FiscalYearRolloverService#execute!` で繰越伝票保存後に全勘定科目の `is_lock` を解除するよう変更。
- `accounts:unlock_all` Rake task を追加。
- `FiscalYearRolloverServiceTest` を追加し、ロック済み科目を含む繰越後に全ロックが解除されることを確認。
- `bin/rails test test/services/fiscal_year_rollover_service_test.rb` と `bin/rails test` が成功。

## 2026-07-01

- 科目別入力の金額ラベルを `費用` から `入出金額` に変更。
- 入出金額ヘッダへ、正の金額は残高増・負の金額は残高減であることを示す tooltip を追加。
- `bin/rails test` が成功。
