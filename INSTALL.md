# install — fatmax の入れ方

**入れるのは集約する1台だけ**です。見たいマシンには何も置きません（→ [見たいマシンを繋ぐ](#見たいマシンを繋ぐ)）。
いま配っているのは `0.1.127` です。外し方は [アンインストール](#アンインストールuninstall) にあります。

**動くのは macOS / Linux（WSL を含む）です。**

> **Claude Code を Docker コンテナで動かしている場合**は、入れる場所と繋ぎ方が変わります。
> → **[コンテナ1つで完結](INSTALL-container.md)**（ハブを起動するだけ）
> ／ **[複数 EC2 × 複数コンテナ](INSTALL-ec2.md)**（手元の WSL にハブ、各コンテナにウォッチャー）

## Ubuntu / Debian

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

記録は `~/.fatmax/fatmax.db`（コンテナの中）で、**作り直すと消えます**。残すなら
**ワークスペースの中**を指してください（`--db "$PWD/.fatmax/fatmax.db"` をその直下で）。
マウントされているのは `/workspaces/<フォルダ名>` **だけ**で、その隣の `/workspaces/.fatmax` は
コンテナの中です。画面を見るには 8787 をホストへ転送します
（devcontainer なら PORTS タブ、素の docker なら `-p 8787:8787`）。
</details>

## Amazon Linux 2023 / Fedora / RHEL（dnf）

```sh
sudo curl -fsSL https://nodesi-jp.github.io/fatmax/dnf/fatmax.repo -o /etc/yum.repos.d/fatmax.repo
sudo dnf install fatmax
sudo systemctl enable --now fatmax-hub
```

CPU（x86_64 / aarch64）は dnf が選びます。署名済みです。
**入れただけでは動きません。**最後の1行で上げます。

> **既に入っているマシンは `dnf install` では上がりません。** 新しい版がリポジトリに
> あっても `Package fatmax-0.1.37-1.x86_64 is already installed. / Nothing to do. / Complete!`
> と出て**成功したように見えて終わります**（実測）。更新は `sudo dnf upgrade fatmax`。
> `apt install` は上げてくれるので、ここだけ勝手が違います。

## その他の Linux（パッケージを使わない場合）

**実行ファイルを1つ置くだけ**です。musl 静的リンクなので、ディストリを選びません。
`apt` も `dnf` も使わない場合や、システムに何も入れたくない場合はこちらです。

**先に CPU を確かめてください。** 落とすファイルがこれで決まります。

```sh
uname -m        # x86_64 → 下のまま  /  aarch64 → ファイル名を fatmax-linux-aarch64 に
```

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/bin/fatmax-linux-x86_64 -o /usr/local/bin/fatmax
chmod +x /usr/local/bin/fatmax
fatmax --version        # ← ここで確かめる
```

**`fatmax --version` を飛ばさないでください。** 落とすファイルを取り違えても
`curl` は成功するので、**動かないファイルが置かれたことに気付けません**
（実測: `Exec format error`。しかも `PATH` の上に残るので、以後ずっと邪魔をします）。
版が出れば、そのまま `fatmax hub` で上がります。

## macOS（Apple Silicon）

**上とは別のファイル**です。書き先が同じなので、取り違えると上書きされます。

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/bin/fatmax-macos-arm64 -o /usr/local/bin/fatmax
chmod +x /usr/local/bin/fatmax
fatmax --version
```

## 落とすファイルの一覧

| 入れる先 | CPU（`uname -m`） | ファイル名 |
|---|---|---|
| Linux | `x86_64` | `fatmax-linux-x86_64` |
| Linux | `aarch64` | `fatmax-linux-aarch64` |
| macOS | `arm64` | `fatmax-macos-arm64` |

<details>
<summary>「開発元を確認できません」と出たら / 中身を確かめたい</summary>

署名していないためで、中身の問題ではありません。`xattr -d com.apple.quarantine /usr/local/bin/fatmax` で外せます。

ハッシュは https://nodesi-jp.github.io/fatmax/bin/SHA256SUMS にあります（**この経路には署名が掛かりません**。
署名が要るなら apt を使ってください）。
</details>

## 次に —— 見たいマシンを繋ぐ

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

これが**そのマシンを繋ぐ一式**です ── hook を入れ、実行ファイルを置き、ハブの宛先を保存します。

> **`setup.sh` と `fatmax setup` は別物です。**
>
> | | 何をするか | いつ |
> |---|---|---|
> | `curl …/setup.sh \| sh` | 繋ぐ一式（hook ＋ 実行ファイル ＋ 宛先） | 初回 |
> | `fatmax setup` | **宛先だけ**決め直す（`~/.fatmax/hub`） | ハブが引っ越したとき |
>
> 以前は宛先が hook の1行に焼かれていたので、引っ越すたびに `setup.sh` の入れ直しが
> 要りました。いまは `fatmax setup` だけで済みます。

## ハブの宛先を教える

見たいマシンに実行ファイルがある場合（apt / dnf で入れた、または下の手順で置いた）、
**そのマシンがどのハブへ送るかを1箇所で決めます**。

```sh
fatmax setup
```

選択肢が出ます。

```
  1) http://127.0.0.1:8787              このマシンでハブが動いている
  2) http://host.docker.internal:8787   コンテナの中から、ホスト側のハブへ
  3) 自分で入力する
```

聞かれたくないときは `fatmax setup --hub http://<ハブの IP>:8787`、
いま何が入っているかは `fatmax setup --show` です。

保存先は **`~/.fatmax/hub` の1行**だけ。**毎回読み直す**ので、ハブが引っ越したら
この1行を書き換えるだけで済みます（入れ直しは要りません）。

> **2番目が要る理由。** コンテナは**自分の `127.0.0.1` を持っています**。そこを指すと
> 自分自身を見に行って届きません。ホスト側のハブへは `host.docker.internal` です。

## ウォッチャー（旧・ウォッチャー）

**起動する必要はありません。** hook が必要なときに起こします。

置くと2つ増えます ── **ハブが落ちている間の記録をディスクに溜めて後から送る**のと、
**実行中に差し込んだ指示・Esc で止めた印**（`~/.claude/projects` を読んで拾う）。
**1台に1つ**です。

### 手で動かす・止める

```sh
fatmax watch          # 宛先は ~/.fatmax/hub から読む
fatmax status         # 動いているか・届いているか
fatmax flush          # 溜まっているぶんを今すぐ送る（ハブを直した直後に）
```

`fatmax relay` は古い呼び名として動きます（settings.json や unit に焼かれているため）。

### ログイン時にも上げたい

**使っていない間も「繋がっている」と言い切りたいとき**だけです。普段は要りません
（使っていない間は止まっているのが正常で、次の hook が起こします）。

```sh
fatmax watch --keep      # macOS は LaunchAgent、Linux は systemd --user に登録
fatmax watch --no-keep   # やめる
```

**apt / dnf で入れたマシンは unit が同梱されている**ので、そちらを使ってください
（`--keep` は重ねないよう断ります）。

```sh
sudoedit /etc/fatmax/relay.conf              # HUB=http://<ハブの IP>:8787
systemctl --user enable --now fatmax-relay
loginctl enable-linger "$USER"               # ログアウトで止めないため
```

あなたのユーザーで動かすのは、`~/.claude/projects` を読むためです。

### パッケージの無いマシン（コンテナなど）

`setup.sh` が実行ファイルも置きます（`~/.fatmax/bin/fatmax`）。手で落とすなら:

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/bin/fatmax-linux-x86_64 -o ~/.fatmax/bin/fatmax   # arm64 は …-aarch64
chmod +x ~/.fatmax/bin/fatmax
~/.fatmax/bin/fatmax setup --hub http://<ハブの IP>:8787
```

CPU は `uname -m` で分かります（`x86_64` / `aarch64`）。
コンテナの作り方（`--add-host`）や、EC2 から手元のハブへ SSH で繋ぐ手順は
**[複数 EC2 × 複数コンテナ](INSTALL-ec2.md)** にあります。

> **ハブからは落とせません。** 以前はハブが各プラットフォームの実行ファイルを内蔵して
> `/relay/bin/…` で配っていましたが、**やめました**（ハブが 10MB → 4.7MB）。
> いまの `/relay/bin/…` はハブの隣にファイルがあるときだけ応え、apt で入れたハブでは 404 です。
> 配る場所をここ1つに寄せてあるので、版がズレる余地もありません。

### 動いているか

```sh
curl -s http://127.0.0.1:8788/version     # ウォッチャーは 8788 で待ち受けます
fatmax status
```

## そのマシンの「実行中に差し込んだ指示」も見たい場合

返事を待たずに打ち込んだ指示は hook が発火しないので、`~/.claude/projects` を読んで補っています。
**条件は1つだけ**——それを読むプロセスが**あなたのユーザーで動いていること**です。

**サービスにする必要はありません。** 端末で動かせば、それで読めます。

```sh
fatmax hub      # 1台で完結するなら、これだけ
fatmax watch    # 複数マシンを見るなら、そのマシンでウォッチャーを（宛先は fatmax setup で）
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

## 新しい版に上げる

```sh
sudo apt update && sudo apt install --only-upgrade fatmax   # Debian / Ubuntu
sudo dnf upgrade --refresh fatmax                           # dnf 系（install では上がりません）

sudo systemctl restart fatmax-hub          # ハブを system で動かしている場合
systemctl --user restart fatmax-hub        # あなたのユーザで動かしている場合
systemctl --user restart fatmax-relay      # ウォッチャーを unit で入れている場合

fatmax status
```

**入れ替わるのはファイルだけです。** 動いているプロセスは古い実行ファイルを掴んだままなので、
**自分で再起動するまで版は変わりません**（入れた瞬間に勝手に上げ下げしない、という方針のためです）。

再起動を忘れると `fatmax status` がこう言います。**出なければ入れ替わっています。**

```
⚠ 動いているのは 0.1.17 (…)。手元の実行ファイルは 0.1.127 (…)（再起動していません）
```

`systemctl status fatmax-hub` に版は出ません（`Description` は固定の文字列です）。
再起動した直後なら起動ログの1行目に出るので、その下の journal に見えます。
確実に見るなら `fatmax status` か `curl -s localhost:8787/healthz` です。

設定（`/etc/fatmax/hub.conf`・`/etc/fatmax/relay.conf`）と記録（`/var/lib/fatmax/fatmax.db`）は
**更新で上書きされません**。

### ハブとウォッチャーの版は揃えてください（揃っていないと1秒ごとに繋ぎ直します）

**片方だけ上げた状態を放置しないでください。** ウォッチャーはハブに「どの行が要るか」を
訊きますが、ハブが古くてその口を持っていないと 404 が返り、**1秒ごとに訊き直し続けます**。
1リクエストごとに1接続するので、そのまま**1秒ごとの TCP 接続**になります。

**繋がるのは毎回成功する**ため、ログにはエラーが1行も出ません。SSH トンネルやプロキシを
挟んでいると、そこで**一時ポートを使い切ってマシンごと止まる**ことがあります。

再発したときの手順は、症状が出やすい EC2 側の案内にまとめてあります
（[INSTALL-ec2.md](INSTALL-ec2.md) の「接続が止まらない・ポートが枯れる（調べ方）」）。
手短には、繋いでいる相手で切り分けます。

```sh
ss -tanp 'dport = :8787' | awk '{print $1, $6}' | sort | uniq -c | sort -rn | head
pkill -f 'fatmax watch'      # 止めて静かになるならウォッチャー側

fatmax --version                          # ウォッチャー側
curl -s http://127.0.0.1:8787/healthz     # ハブ側
```

0.1.127 以降は、①古い名前でも訊き直す ②空振りしたら間隔を倍にする（1秒 → 最大60秒）
の2つが入っているので、版がズレてもこの輪には入りません。**それでも両側を揃えてください。**

## アンインストール（uninstall）

**見たいマシン**（繋いだだけのマシン）:

```sh
curl -fsSL http://<ハブの IP>:8787/setup.sh | sh -s -- --uninstall
```

`settings.json` から fatmax の hook と statusLine だけを外します。あなた自身の設定は残ります。

**集約する1台**:

```sh
sudo systemctl disable --now fatmax-hub      # 止めるだけならここまで
systemctl --user disable --now fatmax-relay  # ウォッチャーを unit で入れていたら（各自で）
sudo apt purge fatmax                        # dnf 系なら sudo dnf remove fatmax
```

**記録は消えません。** `purge` でも残します——日別の集計を生イベントから積み直しているので、
消すと過去のコストも会話も戻らないためです。消すなら自分で:

```sh
sudo rm -rf /var/lib/fatmax
```

---

[README に戻る](README.md)
