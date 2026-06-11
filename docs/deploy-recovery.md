# デプロイ障害の復旧記録

## 作業計画

- GitHub Actions の失敗ログから原因を特定する。
- デプロイスクリプトを最小変更で修正する。
- shell 構文と差分を確認して `main` へ反映する。

## 作業記録

- 2026-06-11: mise の Ruby 実行ファイルを `PATH` に追加していたため、`bundle` が見つからずデプロイが終了コード 127 で失敗していた。
- `PATH` へ mise の shims ディレクトリを追加するよう修正した。

## 引き継ぎ

- 本番の Ruby と Bundler は `/home/admin/.local/share/mise/shims` 経由で実行する。
- デプロイ後は `summa.service` の再起動と active 状態を GitHub Actions で確認する。
