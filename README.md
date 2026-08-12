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

### エージェントを起こせているか

同じタイムラインを**セッション単位**で見ると、サブエージェントが1本ずつ別の行になります。

![サブエージェントが3本並列で走っているセッションのタイムライン](img/agents.png)

紫がサブエージェントです。`並列ピーク` が同時に走った本数、`Claude 稼働` が
**100% を超えていれば並列で回せている**ということです（上の例は 176%）。

エージェントに投げられているかを見たいのは、そこに**3つの得**があるからです。

- **本体の文脈を減らさない。** 中身は別の文脈で処理され、返ってくるのは結果だけです。
  実測: サブエージェントが **284万トークン**使ったターンで、本体の文脈残は
  **81% → 80%**（減ったのは 1%）
- **モデルと effort を分けられる。** 実測の内訳は、本体が `opus-5 / high` の裏で
  サブエージェントが `sonnet-4-6 / high`・`opus-4-8 / xhigh`・`opus-4-8 / low`・`haiku-4-5`。
  調べものは小さいモデルへ、難しい判断だけ `xhigh` へ、と振り分けられます
- **並列で走る。** 上の例では3本が同時に動いています

**1本も紫が出ないなら、全部メインの文脈で順番に処理しています。**
同じ仕事でも、本体の文脈が早く細くなり、モデルも選べていません。

---

## コスト

日別やモデル別のコストを洗い出します。マシン別・案件別・セッション別でも見られます。
今日の合計が決めた金額を超えたら知らせます。

![日別・モデル別・マシン別のコストが出ている画面](img/cost.png)

> **API 利用換算での集計です。正確ではありません。** 取得漏れもあります。
> 正確に知りたい方は、このツールを当てにしないでください。

---

## install

**入れるのは集約する1台だけ**です。見たいマシンには何も置きません（→ [見たいマシンを繋ぐ](#見たいマシンを繋ぐ)）。
いま配っているのは `0.1.17` です。

### Ubuntu / Debian

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/KEY.gpg | sudo tee /usr/share/keyrings/fatmax.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/fatmax.gpg] https://nodesi-jp.github.io/fatmax stable main" | sudo tee /etc/apt/sources.list.d/fatmax.list
sudo apt update && sudo apt install fatmax
sudo systemctl enable --now fatmax-hub
```

CPU（amd64 / arm64）は apt が選びます。署名済みです。
**入れただけでは動きません。**最後の1行で上げます。`http://<このマシンの IP>:8787/` が開きます。

> **上げるのは1台だけ**です。認証が無いので、入れた全台で上げると待ち受けがそのぶん増えます。

<details>
<summary>root のコンテナ（sudo も systemd も無い場合）</summary>

`sudo` を外し、最後の1行の代わりに自分で起動します。

```sh
nohup fatmax hub > /tmp/fatmax-hub.log 2>&1 &
```

記録は `~/.fatmax/fatmax.db`（コンテナの中）で、**作り直すと消えます**。残すならマウント先を
指してください（`--db /workspaces/.fatmax/fatmax.db`）。画面を見るには 8787 をホストへ転送します
（devcontainer なら PORTS タブ、素の docker なら `-p 8787:8787`）。
</details>

### macOS / その他の Linux

**実行ファイルを1つ置くだけ**です（`.rpm` はまだありません）。

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/bin/fatmax-macos-arm64 -o /usr/local/bin/fatmax
chmod +x /usr/local/bin/fatmax
fatmax hub
```

| 入れる先 | ファイル名 |
|---|---|
| macOS（Apple Silicon） | `fatmax-macos-arm64` |
| Linux x86_64 | `fatmax-linux-x86_64` |
| Linux arm64 | `fatmax-linux-aarch64` |

<details>
<summary>「開発元を確認できません」と出たら / 中身を確かめたい</summary>

署名していないためで、中身の問題ではありません。`xattr -d com.apple.quarantine /usr/local/bin/fatmax` で外せます。

ハッシュは https://nodesi-jp.github.io/fatmax/bin/SHA256SUMS にあります（**この経路には署名が掛かりません**。
署名が要るなら apt を使ってください）。
</details>

### 次に —— 見たいマシンを繋ぐ

ハブが上がったら、**見たいマシンそれぞれで1回だけ**叩きます。ハブの IP を入れてください。

```sh
curl -fsSL http://192.168.0.19:8787/setup.sh | sh
```

置くものはありません。`settings.json` に hook と statusLine が入るだけです
（詳しくは [見たいマシンを繋ぐ](#見たいマシンを繋ぐ)）。

---

## 見たいマシンを繋ぐ

**繋ぐ側には何も置きません。** そのマシンで1回だけ:

```sh
curl -fsSL http://<ハブの IP>:8787/setup.sh | sh
```

`~/.claude/settings.json` に1行入るだけです（`--uninstall` で抜けます）。
そのユーザーの**全プロジェクト**で効きます。**このあと Claude Code を再起動してください。**

## 中継（リレー）を起動する

**任意です。入れなくても動きます。** 置くと、hook の宛先が localhost 固定になり、
ハブが落ちている間の記録も溜めて後から送ります。**1台に1つ**です。

### apt で入れたマシン

```sh
sudoedit /etc/fatmax/relay.conf              # HUB=http://<ハブの IP>:8787 に書き換える
systemctl --user enable --now fatmax-relay
loginctl enable-linger "$USER"               # ログアウトで止めないため
```

**`HUB=` の書き換えを飛ばさないでください。** 既定は `http://127.0.0.1:8787`（自分自身）なので、
ハブが別のマシンなら**何も届かないのに起動だけ成功します**。一番よくある事故です。

あなたのユーザーで動かすのは、`~/.claude/projects` を読むためです（実行中に差し込んだ指示は
hook では取れません）。

### コンテナなど、パッケージを使わないマシン

**実行ファイルはここから落とします**（ハブからではありません。理由は下）。

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/bin/fatmax-linux-x86_64 -o /tmp/fatmax   # arm64 は fatmax-linux-aarch64
chmod +x /tmp/fatmax
nohup /tmp/fatmax relay --hub http://<ハブの IP>:8787 > /tmp/fatmax.log 2>&1 &
```

Docker Desktop の中からホストのハブを見るなら、`<ハブの IP>` は `host.docker.internal` です。
CPU は `uname -m` で分かります（`x86_64` / `aarch64`）。

**`relay` を省けません。** 実行ファイルは1個（`hub` / `relay` / `status`）で、役目を書かないと
`不明な役目: --hub` で止まります。**黙ってハブとして起動しません**——中継のつもりのマシンで
8787 が開くと、原因の分からない二重記録になるためです。

`/tmp` にしてあるのは、置き場所を決めさせるとそこで手が止まるからです。引き換えに再起動で消えます。
`/tmp` が `noexec` の環境では `Permission denied` になるので、`$HOME` の下に置いてください。

> **ハブからは落とせません。** 以前はハブが各プラットフォームの実行ファイルを内蔵して
> `/relay/bin/…` で配っていましたが、**やめました**（ハブが 10MB → 4.7MB）。
> いまの `/relay/bin/…` はハブの隣にファイルがあるときだけ応え、apt で入れたハブでは 404 です。
> 配る場所をここ1つに寄せてあるので、版がズレる余地もありません。

### 動いているか

```sh
curl -s http://127.0.0.1:8788/version     # 中継は 8788 で待ち受けます
fatmax status
```

## そのマシンの「実行中に差し込んだ指示」も見たい場合

返事を待たずに打ち込んだ指示は hook が発火しないので、`~/.claude/projects` を読んで補っています。
**条件は1つだけ**——それを読むプロセスが**あなたのユーザーで動いていること**です。

**サービスにする必要はありません。** 端末で動かせば、それで読めます。

```sh
fatmax hub                                   # 1台で完結するなら、これだけ
fatmax relay --hub http://<ハブの IP>:8787   # 複数マシンを見るなら、そのマシンで中継を
```

サービスにするのは「ログアウトしても動き続けてほしい」ときだけです。

```sh
sudo systemctl disable --now fatmax-hub      # apt が入れた system 版を止めて
systemctl --user enable --now fatmax-hub     # 自分のユーザーで上げ直す
loginctl enable-linger "$USER"
```

apt が入れる `fatmax-hub` は**専用ユーザー**で動くので、あなたのホームを読めません。
**この補完が出ないだけ**で、会話・許可待ち・コストは通常どおり記録されます。

## 確認

```sh
fatmax status
```

動いているか・届いているか・読めているかが出ます。`⚠` や `✗` なら、その下に理由と直し方が付きます。

## やめる

**見たいマシン**（繋いだだけのマシン）:

```sh
curl -fsSL http://<ハブの IP>:8787/setup.sh | sh -s -- --uninstall
```

`settings.json` から fatmax の hook と statusLine だけを外します。あなた自身の設定は残ります。

**集約する1台**:

```sh
sudo systemctl disable --now fatmax-hub      # 止めるだけならここまで
systemctl --user disable --now fatmax-relay  # 中継を置いていたら（user サービスなので各自で）
sudo apt purge fatmax
```

**記録は消えません。** `purge` でも残します——日別の集計を生イベントから積み直しているので、
消すと過去のコストも会話も戻らないためです。消すなら自分で:

```sh
sudo rm -rf /var/lib/fatmax
```

## 知っておくこと

- **認証はありません。** LAN の外に出さないでください
- 集めるのは**会話の本文**・ツールの実行記録・トークンとコスト・マシン名です。
  見られたくない会話があるマシンには入れないでください
- 記録の置き場は入れ方で変わります。apt（system サービス）なら `/var/lib/fatmax/fatmax.db`、
  実行ファイルを自分で動かしたなら `~/.fatmax/fatmax.db`

---

https://github.com/nodesi-jp/fatmax

Claude および Claude Code は Anthropic の商標です。本ソフトウェアは Anthropic とは無関係の
第三者製ツールで、Anthropic による承認・提供を受けたものではありません。
