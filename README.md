# fatmax

複数マシンで動く Claude Code の状態・会話・コストを1画面に集めるダッシュボード。LAN 専用。

置いてあるのはバイナリと索引だけです。**Linux は amd64 / arm64、macOS は Apple Silicon**。

---

## install

入れる先で手順が変わります。**集約するのは1台だけ**で、他のマシンは繋ぐだけです。

### Ubuntu / Debian（apt）

CPU は apt が自動で選びます。

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/KEY.gpg | sudo tee /usr/share/keyrings/fatmax.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/fatmax.gpg] https://nodesi-jp.github.io/fatmax stable main" | sudo tee /etc/apt/sources.list.d/fatmax.list
sudo apt update
sudo apt install fatmax
```

署名済みです。

`fatmax-hub` が systemd のサービスとして起動し、`http://<そのマシンの IP>:8787/` が開きます。

```sh
systemctl status fatmax-hub
```

### コンテナ（root・sudo も systemd も無い）

`sudo` は要りません（もう root なので）。**サービスにもならない**ので、自分で起動します。

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/KEY.gpg -o /usr/share/keyrings/fatmax.gpg
echo "deb [signed-by=/usr/share/keyrings/fatmax.gpg] https://nodesi-jp.github.io/fatmax stable main" > /etc/apt/sources.list.d/fatmax.list
apt update && apt install -y fatmax

nohup fatmax hub > /tmp/fatmax-hub.log 2>&1 &
```

記録は既定で `~/.fatmax/fatmax.db`（コンテナの中）です。**作り直すと消えます。**
残すならマウント先を指してください（例 `--db /workspaces/.fatmax/fatmax.db`）。

画面を見るには、そのコンテナの 8787 をホストへ転送する必要があります
（VS Code の devcontainer なら PORTS タブ、素の docker なら `-p 8787:8787`）。

### macOS（Apple Silicon）

パッケージはありません。実行ファイルを1つ置くだけです。

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/bin/fatmax-macos-arm64 -o /usr/local/bin/fatmax
chmod +x /usr/local/bin/fatmax
fatmax hub
```

初回は「開発元を確認できません」と出ます。**署名していないため**で、中身の問題ではありません。
`xattr -d com.apple.quarantine /usr/local/bin/fatmax` で外せます。

### dnf 系（Amazon Linux / Fedora / RHEL）ほか

**.rpm はまだありません。** 実行ファイルは musl 静的リンクなので、置けばそのまま動きます。

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/bin/fatmax-linux-x86_64 -o /usr/local/bin/fatmax   # arm64 は fatmax-linux-aarch64
chmod +x /usr/local/bin/fatmax
fatmax hub
```

`https://nodesi-jp.github.io/fatmax/bin/SHA256SUMS` にハッシュを置いてあります（この経路には署名が掛かりません）。
systemd で常駐させたい場合は、unit を自分で書いてください。

---

## 見たいマシンを繋ぐ

**繋ぐ側には何も置きません。** そのマシンで1回だけ:

```sh
curl -fsSL http://<ハブの IP>:8787/setup.sh | sh
```

`~/.claude/settings.json` に1行入るだけです（`--uninstall` で抜けます）。
そのユーザーの**全プロジェクト**で効きます。**このあと Claude Code を再起動してください。**

## そのマシンの「実行中に差し込んだ指示」も見たい場合

hook では取れないぶんで、`~/.claude/projects` を読む必要があります。読めるのは
**あなたのユーザーで動くプロセス**だけなので、次のどちらかにしてください。

```sh
# 1台で完結するなら —— ハブを自分のユーザーで動かす
sudo systemctl disable --now fatmax-hub
systemctl --user enable --now fatmax-hub

# 複数マシンを見るなら —— そのマシンに中継を置く
sudoedit /etc/fatmax/relay.conf          # HUB=http://<ハブの IP>:8787
systemctl --user enable --now fatmax-relay

loginctl enable-linger "$USER"           # どちらもログアウト後に止めないため
```

既定の `fatmax-hub`（system サービス）は専用ユーザーで動くのでホームを読めません。
この機能だけが出ないだけで、会話・許可待ち・コストは通常どおり記録されます。

## 確認

```sh
fatmax status
```

動いているか・届いているか・読めているかが出ます。`⚠` や `✗` なら、その下に理由と直し方が付きます。

## 知っておくこと

- **認証はありません。** LAN の外に出さないでください
- 集めるのは**会話の本文**・ツールの実行記録・トークンとコスト・マシン名です。
  見られたくない会話があるマシンには入れないでください
- 記録は `/var/lib/fatmax/fatmax.db` に残ります（アンインストールしても消しません）

---

https://github.com/nodesi-jp/fatmax

Claude および Claude Code は Anthropic の商標です。本ソフトウェアは Anthropic とは無関係の
第三者製ツールで、Anthropic による承認・提供を受けたものではありません。
