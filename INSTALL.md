# install — fatmax の入れ方

**入れるのは集約する1台だけ**です。見たいマシンには何も置きません（→ [見たいマシンを繋ぐ](#見たいマシンを繋ぐ)）。
いま配っているのは `0.1.37` です。外し方は [アンインストール](#アンインストールuninstall) にあります。

**動くのは macOS / Linux（WSL を含む）です。**

> **Claude Code を Docker コンテナで動かしている場合**は、入れる場所と繋ぎ方が変わります。
> → **[コンテナ1つで完結](INSTALL-container.md)**（ハブを起動するだけ）
> ／ **[複数 EC2 × 複数コンテナ](INSTALL-ec2.md)**（手元の WSL にハブ、各コンテナに中継）

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

コンテナの作り方（`--add-host`）や、EC2 から手元のハブへ SSH で繋ぐところまで含めた手順は
**[複数 EC2 × 複数コンテナ](INSTALL-ec2.md)** にあります。

`relay` は省けます（`fatmax --hub URL` でも中継として動きます）。`--hub` を取るのは中継だけなので、
役目が一意に決まるためです。**逆は許しません**——役目も `--hub` も無いと `不明な役目` で止まります。
中継のつもりのマシンで 8787 が開くと、原因の分からない二重記録になるためです。

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

## 新しい版に上げる

```sh
sudo apt update && sudo apt install --only-upgrade fatmax   # dnf 系は sudo dnf upgrade fatmax

sudo systemctl restart fatmax-hub          # ハブを system で動かしている場合
systemctl --user restart fatmax-hub        # あなたのユーザで動かしている場合
systemctl --user restart fatmax-relay      # 中継を入れている場合

fatmax status
```

**入れ替わるのはファイルだけです。** 動いているプロセスは古い実行ファイルを掴んだままなので、
**自分で再起動するまで版は変わりません**（入れた瞬間に勝手に上げ下げしない、という方針のためです）。

再起動を忘れると `fatmax status` がこう言います。**出なければ入れ替わっています。**

```
⚠ 動いているのは 0.1.17 (…)。手元の実行ファイルは 0.1.37 (…)（再起動していません）
```

`systemctl status fatmax-hub` に版は出ません（`Description` は固定の文字列です）。
再起動した直後なら起動ログの1行目に出るので、その下の journal に見えます。
確実に見るなら `fatmax status` か `curl -s localhost:8787/healthz` です。

設定（`/etc/fatmax/hub.conf`・`/etc/fatmax/relay.conf`）と記録（`/var/lib/fatmax/fatmax.db`）は
**更新で上書きされません**。

## アンインストール（uninstall）

**見たいマシン**（繋いだだけのマシン）:

```sh
curl -fsSL http://<ハブの IP>:8787/setup.sh | sh -s -- --uninstall
```

`settings.json` から fatmax の hook と statusLine だけを外します。あなた自身の設定は残ります。

**集約する1台**:

```sh
sudo systemctl disable --now fatmax-hub      # 止めるだけならここまで
systemctl --user disable --now fatmax-relay  # 中継を置いていたら（user サービスなので各自で）
sudo apt purge fatmax                        # dnf 系なら sudo dnf remove fatmax
```

**記録は消えません。** `purge` でも残します——日別の集計を生イベントから積み直しているので、
消すと過去のコストも会話も戻らないためです。消すなら自分で:

```sh
sudo rm -rf /var/lib/fatmax
```

---

[README に戻る](README.md)
