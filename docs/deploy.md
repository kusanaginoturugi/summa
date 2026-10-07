# デプロイ構成

`main` への push で CI の全ジョブが成功すると、`.github/workflows/ci.yml` の `deploy` ジョブが本番へデプロイする。
本番サーバーの SSH ポートはインターネットに公開しない。GitHub Actions の runner は Tailscale の tailnet に一時参加して接続する。

## 接続経路

1. `tailscale/github-action@v3` が OAuth client で runner を tailnet に参加させる。runner には `tag:ci` が付き、ジョブ終了後に自動で消える。
2. runner は CI 専用鍵で `admin@showway-t4g.tailb46b1.ts.net` の `65522` 番へ SSH する。このポートはアプリが動く nspawn コンテナの sshd に届く。
3. コンテナ内の `/home/admin/summa` で `scripts/deploy.sh` を実行する。

EC2 ホスト本体の `22` 番は Tailscale SSH が受けるが、CI はこれを使わない。

## GitHub Secrets

| 名前 | 内容 |
| --- | --- |
| `TS_OAUTH_CLIENT_ID` | Tailscale OAuth client の ID |
| `TS_OAUTH_SECRET` | Tailscale OAuth client の secret |
| `EC2_SSH_KEY` | CI 専用 SSH 秘密鍵（ed25519、コメント `summa-ci`） |

登録・更新は `gh secret set` で行う。値は後から読み出せないので、同じ名前で登録し直すと上書きになる。

```sh
# 対話で入力する（値は画面に表示されない）
gh secret set TS_OAUTH_CLIENT_ID -R kusanaginoturugi/summa
gh secret set TS_OAUTH_SECRET -R kusanaginoturugi/summa

# 複数行の値（SSH 秘密鍵など）はファイルから入れる
gh secret set EC2_SSH_KEY -R kusanaginoturugi/summa < 秘密鍵

# 登録済みの名前を確認する
gh secret list -R kusanaginoturugi/summa
```

`--body` で値を直接渡すとシェルの履歴に残るので使わない。

## Tailscale 側の設定

- OAuth client: Settings → Trust credentials。スコープは `Auth Keys` の Write のみ、タグは `tag:ci`。
- ポリシーファイルの `tagOwners` に `tag:ci` と `tag:server` を定義している。
- EC2 ホストには `tag:server` が付き、Tailscale SSH が有効（`tailscale set --ssh`）。
- `ssh` ルールは `autogroup:admin` → `tag:server`（ユーザー `admin`, `root`）を `accept`。管理者が本体へ入るためのもので、CI 用ではない。
- `acls` は全許可のままなので、`tag:ci` からコンテナの `65522` 番へ届く。`acls` を絞る場合は `tag:ci` → `tag:server:65522` を許可すること。

## 運用メモ

- CI 専用鍵の公開鍵は、コンテナの `admin` の `~/.ssh/authorized_keys` に登録してある。
- 鍵を入れ替えるときは、新しい鍵ペアを作って公開鍵をコンテナに追記し、`gh secret set EC2_SSH_KEY < 秘密鍵` で登録してから、古い公開鍵を `authorized_keys` から消す。
- runner は毎回まっさらなので、ホスト鍵は `StrictHostKeyChecking=accept-new` で受け入れている。接続先ノードの正当性は Tailscale が担保する。
- EC2 本体の Tailscale SSH を無効化するときは、`sudo tailscale set --ssh=false` を先に実行してから `ssh` ルールを消す。逆順だと本体へ入れなくなる。
- `tailscale set --ssh` を有効にすると、Tailscale 経由で入っている SSH セッションは切断される。
