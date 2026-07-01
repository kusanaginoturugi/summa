# Handoff

## 2026-07-01 勘定科目ロック解除

- 年度繰越成功時に `accounts.is_lock` は全件 `false` になる。
- 既存本番データの解除は `bin/rails accounts:unlock_all` を実行する。
- `accounts:unlock_all` は対象件数を標準出力に表示するだけで、ロック済み以外の勘定科目は変更しない。
