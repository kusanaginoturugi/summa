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

## 2026-07-01

- CSV取込画面に、科目表に存在しない科目コードを持つ取込ルールの検出表示を追加。
- 無効な取込ルールを一括削除する `DELETE /bank_imports/invalid_import_rules` を追加。
- `ImportRule.match_for` が存在しない科目・ロック中科目のルールを使わないよう変更。
- 勘定科目一覧の `科目` / `明細` / `保存` / `削除` ボタンサイズを `account-row-action` で統一。
- `bin/rails test` が成功。

## 2026-07-01

- 科目別入力に `from_month` / `to_month` の月単位フィルタを追加。
- 科目別入力から詳細へ遷移した後、更新・削除時に表示期間条件を保持して戻るよう変更。
- `VouchersControllerTest` に期間フィルタと削除後リダイレクトのテストを追加。
- `bin/rails test test/controllers/vouchers_controller_test.rb` と `bin/rails test` が成功。
