# Windows + WSL(Ubuntu)

**ハブは WSL の Ubuntu で動かし、記録するのは Windows 側の Claude Code** という構成です。
画面は Windows のブラウザから `http://127.0.0.1:8787/` で開きます。

**なぜ WSL にハブを置くか。** Windows 版の実行ファイルには署名を付けていないので、
SmartScreen と Smart App Control に止められます。Linux の実行ファイルにはどちらも
効かないので、**常駐させるハブだけ WSL に置くと、署名の問題がハブには掛かりません**
（Windows 側のウォッチャーは `fatmax.exe` です。入れるときに Web から来た印を外します）。

いま配っているのは `0.1.160` です。

## 前提

- Windows 10/11 + WSL2（`wsl --install`。未導入なら再起動が要ります）
- WSL のディストリビューションが Ubuntu（`wsl -l -v` で確認）
- Windows 側で Claude Code が動いていること —— **記録したいのはそちら**です
- fatmax に認証はありません。LAN 内での利用が前提です

## 全体像

| どこ | 何を入れるか | 役目 |
|---|---|---|
| **WSL Ubuntu** | `fatmax`（apt） | ハブ。記録を溜めて画面を出す |
| **Windows** | `settings.json` の hook + OTel | Claude Code の動きをウォッチャーへ渡す |
| **Windows** | `fatmax.exe`（ウォッチャー） | ハブへ送る。ハブが落ちている間ぶんを溜めて送り直す |

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

## 4. Windows 側に入れる

**[Windows で入れる](INSTALL-windows.md) の一式**を使います。宛先は `127.0.0.1` です
（Windows と WSL2 は localhost を共有するので、IP を調べる必要がありません）。

**Windows の PowerShell で**（管理者である必要はありません）:

```powershell
cd $env:TEMP
irm https://nodesi-jp.github.io/fatmax/windows/fatmax-windows.zip -OutFile fatmax-windows.zip
Expand-Archive fatmax-windows.zip . -Force
.\fatmax-windows\install.cmd -Hub http://127.0.0.1:8787
```

`fatmax.exe` を `%USERPROFILE%\.fatmax\bin\` に置き、hook と OTel を入れ、ウォッチャーを裏で動かします。
**ウォッチャーを動かさないと、記録はハブへ上がりません**（宛先はウォッチャー1本です。溜まるだけで消えはしません）。
終わったら **Claude Code を開き直してください**（OTel の設定は起動時にしか読まれません）。

hook の保存先を `-Scope` で選びたい・ウォッチャーがサインアウトで止まったとき・名前の付け方は
[Windows で入れる](INSTALL-windows.md) にあります。

## 5. 確認

```powershell
& "$HOME\.fatmax\bin\fatmax.exe" status
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

## Windows 側

**4. と同じ手順をもう一度**叩きます。Windows では自分で上がりません（動いている `.exe` は
置き換えられないため）。`install.cmd` が動いているウォッチャーを止めてから置き換え、もう一度動かします。

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
| 画面にこのマシンが出ない | ウォッチャーが動いていない。`& "$HOME\.fatmax\bin\fatmax.exe" status` で確かめる |
| 名前を書き換えたのに変わらない | ファイルが UTF-16 で保存されています。`Out-File -Encoding ascii` で書き直す |
| 回数とコストが倍 | hook が2箇所（user と project など）に入っています。片方を `-Uninstall` |
| 「Windows によって PC が保護されました」 | 署名していない実行ファイルです。`irm` で落とすか `Unblock-File` |
| 実行中に差し込んだ指示・Esc の印が出ない | ウォッチャーが動いていません。hook だけでは取れません |
| 接続が止まらない・ポートが枯れる | 版のズレ。上の「版は必ず揃えてください」 |

**LAN の他のマシンからも画面を見たい場合**は追加の設定が要ります。WSL2 は既定で NAT の
中に居るので、そのままでは届きません。`%USERPROFILE%\.wslconfig` に
`[wsl2]` / `networkingMode=mirrored` と書いて `wsl --shutdown`（Windows 11 22H2 以降）が
一番楽です。それが使えない場合は `netsh interface portproxy` とファイアウォールを開けますが、
**WSL2 の IP は再起動で変わる**ので、その都度張り直すことになります。

---

[README に戻る](README.md)
