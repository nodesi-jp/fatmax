# Windows + WSL(Ubuntu)

**ハブは WSL の Ubuntu で動かし、記録するのは Windows 側の Claude Code** という構成です。
画面は Windows のブラウザから `http://127.0.0.1:8787/` で開きます。

**なぜ WSL にハブを置くか。** Windows 版の実行ファイルには署名を付けていないので、
SmartScreen と Smart App Control に止められます。Linux の実行ファイルにはどちらも
効かないので、**常駐させるハブだけ WSL に置くと署名の問題を丸ごと避けられます**。

いま配っているのは `0.1.106` です。

## 前提

- Windows 10/11 + WSL2（`wsl --install`。未導入なら再起動が要ります）
- WSL のディストリビューションが Ubuntu（`wsl -l -v` で確認）
- Windows 側で Claude Code が動いていること —— **記録したいのはそちら**です
- fatmax に認証はありません。LAN 内での利用が前提です

## 全体像

| どこ | 何を入れるか | 役目 |
|---|---|---|
| **WSL Ubuntu** | `fatmax`（apt） | ハブ。記録を溜めて画面を出す |
| **Windows** | `settings.json` の hook + statusLine | Claude Code の動きをハブへ送る |
| **Windows**（任意） | `fatmax.exe` | 好きなマシン名を付ける・ハブが落ちている間ぶんを残す |

Windows と WSL2 は **localhost を共有**します。Windows から `127.0.0.1:8787` を叩けば
WSL の中のハブに届くので、**IP を調べる必要はありません**（WSL2 の IP は再起動で
変わるので、ここに IP を書かないのが肝心です）。

---

# インストール

## 1. WSL Ubuntu にハブを入れる

**WSL の中で**（`wsl` と打って入ったところ）:

```sh
curl -fsSL https://nodesi-jp.github.io/fatmax/KEY.gpg | sudo tee /usr/share/keyrings/fatmax.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/fatmax.gpg] https://nodesi-jp.github.io/fatmax stable main" | sudo tee /etc/apt/sources.list.d/fatmax.list
sudo apt update && sudo apt install fatmax
```

署名済みです。

## 2. ハブを上げる

**入れただけでは動きません。** 上げ方は systemd があるかで変わります。

```sh
systemctl is-system-running        # running / degraded なら systemd が使えます
```

`running` か `degraded` なら:

```sh
sudo systemctl enable --now fatmax-hub
```

エラーになる、または `offline` なら **その WSL では systemd が動いていません**。
有効にするなら `/etc/wsl.conf` に次を書いて、Windows 側で `wsl --shutdown` してから開き直します。

```ini
[boot]
systemd=true
```

有効にしないなら、そのまま動かしても構いません。

```sh
nohup fatmax hub > /tmp/fatmax-hub.log 2>&1 &
```

> **記録の置き場が変わります。** systemd（専用ユーザー）なら `/var/lib/fatmax/fatmax.db`、
> 自分で動かしたなら `~/.fatmax/fatmax.db` です。**あとで消すときに効いてきます。**

## 3. Windows のブラウザで開けることを確かめる

```
http://127.0.0.1:8787/
```

**ここが開けてから 4. へ進んでください。** 4. がこの経路にそのまま乗ります。
開けないときは下の「うまくいかないとき」へ。

## 4. Windows 側に hook を入れる

**Windows の PowerShell で**（管理者である必要はありません）:

```powershell
irm http://127.0.0.1:8787/setup.ps1 | iex
```

`settings.json` に hook と statusLine を足します。**あなた自身の設定は消しません。**

保存先は `-Scope` で選べます（既定は `user`）。**2箇所に入れるとイベントが二重に記録され、
回数もコストも倍になります。** 入っていれば警告が出ます。

```powershell
& ([scriptblock]::Create((irm http://127.0.0.1:8787/setup.ps1))) -Scope local
```

| `-Scope` | 書く先 | 効く範囲 |
|---|---|---|
| `user`（既定） | `$HOME\.claude\settings.json` | 全プロジェクト |
| `project` | `<cwd>\.claude\settings.json` | リポジトリで共有（git に入る） |
| `local` | `<cwd>\.claude\settings.local.json` | このチェックアウトだけ |

`project` / `local` は **PowerShell を開いている場所**に書きます。Claude Code を開いている
フォルダで実行しないと読まれません（それでもファイルは書けるので「成功」と出ます）。

モデル別のトークン内訳も取るなら `-Otel` を足します（反映には Claude Code の再起動が要ります）。

**5. と 6. まで進めてください。** 宛先はウォッチャー1本なので、実行ファイルを置いて
`fatmax watch` を動かすまで、記録はディスクに溜まるだけでハブへは上がりません。

## 5.（任意）Windows 側に実行ファイルを置く

置くと2つ変わります。

- **画面に出る名前を自分で決められる。** 置かない場合は `%COMPUTERNAME%` 固定です
  （cmd.exe の1行ではファイルを読めないため）
- **ハブが落ちている間ぶんが消えない。** 送れなかったものをディスクに溜め、次に送り直します

**Windows の PowerShell で:**

```powershell
mkdir "$HOME\.fatmax\bin" -Force
irm http://127.0.0.1:8787/hub/bin/windows -OutFile "$HOME\.fatmax\bin\fatmax.exe"
& "$HOME\.fatmax\bin\fatmax.exe" --version
```

置き場所は **`%USERPROFILE%\.fatmax\bin\fatmax.exe` でなければいけません。** hook の1行が
この場所を見て、あれば使う・無ければ curl に落ちる、という判断を**毎回**します
（hook を入れ直す必要はありません）。

> **`irm` で落とすこと。** ブラウザで落とすと「Web から来たファイル」の印が付き、
> SmartScreen が止めます。**中身の問題ではありません。** 既に付いてしまったら
> `Unblock-File "$HOME\.fatmax\bin\fatmax.exe"`、あるいは警告画面で「詳細情報」→「実行」です。

名前は**送るたびに読み直される**ので、書き換えるだけで変わります（入れ直しは不要）。

```powershell
"開発機" | Out-File -Encoding ascii "$HOME\.claude\fatmax-host"
```

宛先も一度だけ教えておきます。

```powershell
& "$HOME\.fatmax\bin\fatmax.exe" setup
```

## 6.（さらに任意）ウォッチャーを動かす

**これは必須です。** 宛先はウォッチャー1本（ハブ直はありません）なので、
これを動かすまでハブには1件も上がりません。**消えはしません** —— hook は送る前に
`~/.fatmax/spool` へ置くので、動かせば溜まっていたぶんがまとめて流れます。

動かすと、hook では取れないものも入ります —— **返事を待たずに打ち込んだ指示**と、
**Esc で止めた印**です（どちらも transcript を読まないと分かりません）。

```powershell
& "$HOME\.fatmax\bin\fatmax.exe" watch
```

閉じると止まります。**Windows では自己更新しません**（動いている `.exe` は置き換えられないため）。

## 7. 確認

```powershell
& "$HOME\.fatmax\bin\fatmax.exe" status     # 置いた場合
```

Claude Code を1回動かしてから `http://127.0.0.1:8787/` を開き、その会話が出れば通っています。

---

# 更新（update）

**WSL 側と Windows 側は別々です。両方やってください。**

## WSL のハブ

```sh
sudo apt update && sudo apt install --only-upgrade fatmax
sudo systemctl restart fatmax-hub        # systemd で動かしている場合
```

`nohup` で動かしているなら `pkill -f 'fatmax hub'` してから上げ直します。

**入れ替わるのはファイルだけです。** 動いているプロセスは古い実行ファイルを掴んだままなので、
**再起動するまで版は変わりません**。忘れると `fatmax status` がそう言います。

## Windows の実行ファイル

**落とし直してください。** Windows では自己更新しません（動いている `.exe` は
置き換えられないため）。**先に止めてから**置き換えます。

```powershell
Get-Process fatmax -ErrorAction SilentlyContinue | Stop-Process
irm http://127.0.0.1:8787/hub/bin/windows -OutFile "$HOME\.fatmax\bin\fatmax.exe"
& "$HOME\.fatmax\bin\fatmax.exe" --version
```

hook の1行は場所しか見ていないので、**入れ直す必要はありません。**

## 版は必ず揃えてください

**片方だけ上げた状態を放置しないでください。** ウォッチャーはハブに「どの行が要るか」を
訊きますが、ハブが古くてその口を持っていないと 404 が返り、**1秒ごとに訊き直し続けます**。
1リクエストごとに1接続するので、そのまま**1秒ごとの TCP 接続**になります。

**繋がるのは毎回成功する**ため、ログにエラーは1行も出ません。調べ方は
[INSTALL-ec2.md](INSTALL-ec2.md) の「接続が止まらない・ポートが枯れる（調べ方）」にあります。

```powershell
& "$HOME\.fatmax\bin\fatmax.exe" --version      # Windows 側
irm http://127.0.0.1:8787/healthz               # ハブ側
```

---

# アンインストール（uninstall）

## Windows 側

```powershell
& ([scriptblock]::Create((irm http://127.0.0.1:8787/setup.ps1))) -Uninstall
```

`settings.json` から fatmax の hook と statusLine **だけ**を外します。あなた自身の設定は残ります。
`-Scope` を付けて入れたなら、**外すときも同じ `-Scope`** を付けてください。

実行ファイルを置いたなら、それも消します。

```powershell
Get-Process fatmax -ErrorAction SilentlyContinue | Stop-Process
Remove-Item -Recurse -Force "$HOME\.fatmax"
Remove-Item -Force "$HOME\.claude\fatmax-host" -ErrorAction SilentlyContinue
```

> `$HOME\.fatmax` には**まだ送れていないぶん**（spool）も入っています。先に
> ハブを上げて `fatmax.exe flush` を通してから消すと、取りこぼしません。

## WSL 側（ハブ）

```sh
sudo systemctl disable --now fatmax-hub                # 止めるだけならここまで
sudo apt purge fatmax
sudo rm -f /etc/apt/sources.list.d/fatmax.list /usr/share/keyrings/fatmax.gpg
```

systemd を使わず `nohup` で動かしていたなら、`pkill -f 'fatmax hub'` です。

**記録は消えません。** `purge` でも残します —— 日別の集計を生イベントから積み直しているので、
消すと過去のコストも会話も戻らないためです。消すなら自分で:

```sh
sudo rm -rf /var/lib/fatmax      # systemd（専用ユーザー）で動かしていた場合
rm -rf ~/.fatmax                 # 自分で fatmax hub を動かしていた場合
```

---

## うまくいかないとき

| 症状 | 見るところ |
|---|---|
| Windows のブラウザで `127.0.0.1:8787` が開けない | WSL の中で `curl -s localhost:8787/healthz`。返るなら Windows 側の問題、返らないならハブが上がっていない |
| WSL の中では開けるのに Windows から開けない | ハブが `127.0.0.1` にだけ張り付いている。`ss -tlnp \| grep 8787` が `0.0.0.0:8787` になっているか |
| `wsl --shutdown` のあと届かない | ハブが上がっていません。systemd を使っていないなら `nohup` で上げ直す（自動では上がりません） |
| 画面に出る名前が `%COMPUTERNAME%` のまま | 5. の実行ファイルを置いていない、または置き場所が違う。`%USERPROFILE%\.fatmax\bin\fatmax.exe` 固定です |
| 名前を書き換えたのに変わらない | ファイルが UTF-16 で保存されています。`Out-File -Encoding ascii` で書き直す |
| 回数とコストが倍 | hook が2箇所（user と project など）に入っています。片方を `-Uninstall` |
| 「Windows によって PC が保護されました」 | 署名していない実行ファイルです。`irm` で落とすか `Unblock-File` |
| 実行中に差し込んだ指示・Esc の印が出ない | 6. のウォッチャーが動いていません。hook だけでは取れません |
| 接続が止まらない・ポートが枯れる | 版のズレ。上の「版は必ず揃えてください」 |

**LAN の他のマシンからも画面を見たい場合**は追加の設定が要ります。WSL2 は既定で NAT の
中に居るので、そのままでは届きません。`%USERPROFILE%\.wslconfig` に
`[wsl2]` / `networkingMode=mirrored` と書いて `wsl --shutdown`（Windows 11 22H2 以降）が
一番楽です。それが使えない場合は `netsh interface portproxy` とファイアウォールを開けますが、
**WSL2 の IP は再起動で変わる**ので、その都度張り直すことになります。

---

[README に戻る](README.md)
