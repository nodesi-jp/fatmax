# fatmax

複数マシンで動く Claude Code の状態・会話・コストを1画面に集めるダッシュボード。LAN 専用。

置いてあるのはバイナリと索引だけです（ソースは含みません）。**amd64 のみ**。

---

## 入れる

集約する1台で:

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/KEY.gpg | sudo tee /usr/share/keyrings/fatmax.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/fatmax.gpg] https://nodesi-jp.github.io/fatmax stable main" | sudo tee /etc/apt/sources.list.d/fatmax.list
sudo apt update
sudo apt install fatmax
```

署名済みです。

`http://<そのマシンの IP>:8787/` が開きます。

```sh
systemctl status fatmax-hub
```

## 見たいマシンを繋ぐ

**繋ぐ側には何も置きません。** そのマシンで1回だけ:

```sh
curl -fsSL http://<ハブの IP>:8787/setup.sh | sh
```

`~/.claude/settings.json` に1行入るだけです（`--uninstall` で抜けます）。

## そのマシンの「実行中に差し込んだ指示」も見たい場合

hook では取れないぶんで、`~/.claude/projects` を読む必要があります。読めるのは
**あなたのユーザで動くプロセス**だけなので、次のどちらかにしてください。

```sh
# 1台で完結するなら —— ハブを自分のユーザで動かす
sudo systemctl disable --now fatmax-hub
systemctl --user enable --now fatmax-hub

# 複数マシンを見るなら —— そのマシンに中継を置く
sudoedit /etc/fatmax/relay.conf          # HUB=http://<ハブの IP>:8787
systemctl --user enable --now fatmax-relay

loginctl enable-linger "$USER"           # どちらもログアウト後に止めないため
```

既定の `fatmax-hub`（system サービス）は専用ユーザで動くのでホームを読めません。
この機能だけが出ないだけで、会話・許可待ち・コストは通常どおり記録されます。

## 知っておくこと

- **認証はありません。** LAN の外に出さないでください
- 集めるのは**会話の本文**・ツールの実行記録・トークンとコスト・マシン名です。
  見られたくない会話があるマシンには入れないでください
- 記録は `/var/lib/fatmax/fatmax.db` に残ります（アンインストールしても消しません）

---

https://github.com/nodesi-jp/fatmax

Claude および Claude Code は Anthropic の商標です。本ソフトウェアは Anthropic とは無関係の
第三者製ツールで、Anthropic による承認・提供を受けたものではありません。
