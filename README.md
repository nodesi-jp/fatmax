# fatmax

**Claude Code を並列で回すと、ボトルネックは人間になる。**

複数台・複数セッションを回していると、**回答待ちのセッションを見逃します**。
気づいたときには、1本が 40 分止まっていた。数秒だけ他のセッションに割り込んで答えていれば、
とっくに終わっていたのに——ということがよく起きます。

1ターン 30 分待ちの間に休憩していても、ちょっと他のことをしていても、
fatmax が**気づかせます**。人間の無駄時間をゼロに近づけるための工夫で、
**脳みそを「判断」に集中させる**ための道具です。

![複数のPCとDockerコンテナのセッションが1画面に集まる図。中央はfatmaxの実際の画面](img/overview.png)

複数の PC（Mac / Windows）でも、その中で動く Docker コンテナでも、
**セッションが何個あっても1画面**に集まります。上の図の中央は実際の画面です。

- **止まっているセッションが分かる。** 画面を見ていなくても、音で気づけます
- **会話がそのまま読める。** どのマシンのセッションでも、質問と選んだ答え、
  承認した計画、実行中に差し込んだ指示まで

---

## タイムライン

**人間が介入すべきところで、ちゃんと介入できていたか。** 入力待ちを放置していなかったか。
その日に動いたセッションを1本1行で同じ時間軸に並べるので、**どこで止まっていたか**が見えます。

![その日に動いた7セッションを1本1行で並べた帯](img/timeline.png)

赤が許可待ち、灰が入力待ちです。**待ちは詰めずに実時刻の幅のまま**置いてあります
（1日で知りたいのは動いていた時間より、止まっていた時間）。

> シェルが起動しっぱなしのときなども入力待ちと同じ扱いで、
> **メインが動いていない時間はフリー状態として計測されます。**

---

## コスト

日別やモデル別のコストを洗い出します。マシン別・案件別・セッション別でも見られます。
今日の合計が決めた金額を超えたら知らせます。

![日別・モデル別・マシン別のコストが出ている画面](img/cost.png)

> **API 利用換算での集計です。正確ではありません。** 取得漏れもあります。
> 正確に知りたい方は、このツールを当てにしないでください。

---

## install

入れる先で手順が変わります。**集約するのは1台だけ**で、他のマシンは繋ぐだけです。
配っているのは Linux（amd64 / arm64）と macOS（Apple Silicon）です。

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
