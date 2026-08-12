# コンテナ1つで完結（amd64 / dnf 系）

Claude Code を **Docker コンテナ1つ**で動かしていて、そのコンテナだけ見る場合の手順です。
**ハブを起動するだけ**で、中継（リレー）も手元の準備も要りません。

**CPU は amd64（x86_64）**、コンテナは **dnf 系**（Amazon Linux / Fedora / RHEL）を前提に
書いてあります。いま配っているのは `0.1.17` です。
やめ方は [アンインストール](#アンインストール) にあります。

- 複数の EC2 に散らばったコンテナを1画面に集めたい → **[複数 EC2 × 複数コンテナ](INSTALL-ec2.md)**
- コンテナを使わない一般的な入れ方 → **[install](INSTALL.md)**

## 前提

**VS Code の Dev Containers 拡張でコンテナの中を開いて開発できていること。**
Claude Code もそのコンテナの中で動いている状態から始めます。

以下のコマンドは**すべてコンテナの中のターミナル**（VS Code のターミナル）で叩きます。
手元に置くものは1つもありません。

---

```mermaid
flowchart LR
  subgraph C["コンテナ (amd64 / dnf)"]
    CC["Claude Code"]
    H["fatmax hub<br/>:8787"]
    T[("~/.claude/projects")]
    DB[("~/.fatmax/fatmax.db")]
    CC -->|"hook 127.0.0.1:8787"| H
    H -.->|読む| T
    H --> DB
  end
  BR["ブラウザ<br/>localhost:8787"] -->|"PORTS で転送"| H
```

**リレーは要りません。** hook はハブへ直接届き、実行中に差し込んだ指示（`~/.claude/projects`）も
同じコンテナなのでハブ自身が読めます。**Claude Code と同じユーザーで動かす**のが条件です。

## 1. 実行ファイルを置く

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/bin/fatmax-linux-x86_64 -o /usr/local/bin/fatmax
chmod +x /usr/local/bin/fatmax
```

## 2. 画面に出る名前を決める

`~/.claude/fatmax-host` の**1行目がそのまま画面に出ます。** 好きな名前にしてください。

```sh
mkdir -p ~/.claude && echo 'dev-1' > ~/.claude/fatmax-host
```

**必ず置いてください。** dnf 系のイメージには `hostname` コマンドが入っていないので、
無いと**名前が空のまま**画面に並びます（実測: `amazonlinux:2023`）。

**あとから書き換えてもかまいません。** 送るたびに読み直すので、
ハブや Claude Code の再起動は要りません。次のイベントから新しい名前になります。

```sh
echo 'api-dev' > ~/.claude/fatmax-host     # いつでも
```

## 3. ハブを起動する

```sh
nohup fatmax hub > /tmp/fatmax-hub.log 2>&1 &
```

記録は `~/.fatmax/fatmax.db` です。**コンテナを作り直すと消えます。**
残すならマウントした場所を指してください。

```sh
nohup fatmax hub --db /workspaces/.fatmax/fatmax.db > /tmp/fatmax-hub.log 2>&1 &
```

## 4. hook を入れる

**Claude Code を開いているディレクトリで**実行します。

```sh
curl -fsSL http://127.0.0.1:8787/setup.sh | sh
```

`~/.claude/settings.json` に hook と statusLine が入るだけで、置くファイルはありません。
**このあと Claude Code を再起動してください。**

- **2箇所に入れないこと。** user と project の両方にあると足し算で読まれ、
  **全イベントが2回届いて回数もコストも倍**になります

## 5. 画面を開く

**VS Code の PORTS タブ**（ターミナルの隣）に `8787` が出ています。
3. でハブが待ち受けを始めた時点で、Dev Containers が**自動で転送**します。

その行の**🌐 をクリックするだけ**です。手元のブラウザで `http://localhost:8787/` が開きます。

- 出ていなければ「ポートの転送」で `8787` を足します
- 毎回確実に出したいなら `devcontainer.json` に `"forwardPorts": [8787]`

**コンテナを作り直す必要はありません。**

## 6. 確認

```sh
fatmax status
```

こう出れば成立です。

```
✓ ハブ        動いています  http://127.0.0.1:8787
－ 中継        動いていません（hook はハブへ直接飛びます）
✓ hook        入っています（ユーザ全体）
✓ transcript  読めています（実行中に差し込んだ指示も出ます）
```

`－ 中継` は**このパターンでは正常**です。要らないので。

## コンテナを作り直したとき

**Dev Containers: Rebuild Container** をすると `/usr/local/bin/fatmax` も記録も消えるので、
**1. から**やり直しになります。毎回やりたくないなら `devcontainer.json` に入れておきます。

```json
"postStartCommand": "sh -c 'mkdir -p ~/.claude && echo dev-1 > ~/.claude/fatmax-host && curl -fsSL https://nodesi-jp.github.io/fatmax/bin/fatmax-linux-x86_64 -o /tmp/fatmax && chmod +x /tmp/fatmax && (nohup /tmp/fatmax hub >/tmp/fatmax-hub.log 2>&1 &)'"
```

> **`postCreateCommand` ではなく `postStartCommand`。** postCreate は作った1回だけなので、
> コンテナを止めて開き直すとハブが上がりません。

---

## うまくいかないとき

| 症状 | 見るところ |
|---|---|
| 画面に名前が出ない・空になる | `~/.claude/fatmax-host` が無い。**dnf 系には `hostname` コマンドがありません** |
| 画面が開けない | VS Code の PORTS に `8787` が無い。または 3. のハブが上がっていない |
| 昨日まで届いていたのに止まった | コンテナの IP が変わって、hook に焼かれた宛先が古い。`setup.sh` を叩き直す |
| 回数とコストが倍 | hook が2箇所（user と project）に入っています。片方を `--uninstall` |
| 実行中に差し込んだ指示が出ない | `fatmax status` の `⚠ ~/.claude/projects が読めません`。**Claude Code と同じユーザー**でハブを動かす |

---

## アンインストール

**コンテナを捨てるだけなら何もしなくて構いません**（中にしか置いていないので）。
`~/.claude` をマウントしている・使い続ける場合は:

```sh
curl -fsSL http://127.0.0.1:8787/setup.sh | sh -s -- --uninstall
pkill -f 'fatmax hub' || true
rm -f /usr/local/bin/fatmax ~/.claude/fatmax-host
```

`--local` で入れたなら、**入れたディレクトリで** `sh -s -- --uninstall --local` です
（外す場所も入れたときと同じ指定で選びます）。fatmax が書いた hook と statusLine
だけを外すので、あなた自身の設定は残ります。

記録を消すなら `rm -rf ~/.fatmax`（`--db` で場所を変えたならそちら）。
**残したいなら消さないでください** —— 日別の集計を生イベントから積み直しているので、
消すと過去のコストも会話も戻りません。

---

[README に戻る](README.md)
