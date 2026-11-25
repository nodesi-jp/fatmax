# Windows で入れる（試験版）

**Windows で動いている Claude Code を、LAN にあるハブへ繋ぐ**手順です。いま配っているのは `0.1.180` です。

> **試験版です。** 入れる・入れ直す・外すは PowerShell 7 で確かめてあります。`install.cmd` が使う
> Windows PowerShell 5.1 は文字コードの扱いが 7 と違うので、その違いには合わせてありますが、
> 実機で最後まで通ったことはまだありません。うまく動かないときは、下の「うまくいかないとき」を見てください。

> **0.1.172 より前に入れた人へ。hook が1件も届いていません。** 前の版は hook の1行を cmd.exe の書き方で
> 入れていましたが、Windows の Claude Code は hook を Git Bash か PowerShell で動かすので、構文として通らず
> 1件も届いていませんでした（transcript と OTel だけが届くので、**ハブの画面のセッション一覧にこのマシンが出ません**）。
> 下の「1. 一式を落として入れる」をもう一度叩いてください。入れ直すと前の形は外れます。

> **0.1.169 より前に入れた（入れ直した）人へ。** 前の版は、入れるときに `settings.json` の
> **文字列の配列を壊していました**（`"allow": ["Bash(…)"]` が `{"Length": 17}` に、空の配列が `null` に
> なる）。許可の設定（`permissions`）を書いていた人は、それが効かなくなっています。
> 下の「[前の版で壊れた settings.json を戻す](#前の版で壊れた-settingsjson-を戻す)」で確かめてください。

Windows に入れるのは **見たいマシン**の役目だけです。**ハブ**（画面と記録を集める1台）は別に要ります。

- ハブを Windows で動かしたい → **[Windows + WSL(Ubuntu)](INSTALL-wsl.md)**、または Docker Desktop で **[Docker で動かす](INSTALL-docker.md)**
- ハブを Linux で動かす → **[apt で入れる](INSTALL-apt.md)** ／ **[dnf で入れる](INSTALL-dnf.md)**

要るもの:

- Windows 10 / 11（x86_64）
- Windows 側で Claude Code が動いていること
- ハブが LAN のどこかで動いていて、その IP が分かること
- ハブの**指紋とトークン**（ハブの画面の「導入」に出ています。ハブのマシンでは `fatmax token`）

## 1. 一式を落として入れる

**PowerShell で**（管理者である必要はありません）:

```powershell
cd $env:TEMP
irm https://nodesi-jp.github.io/fatmax/windows/fatmax-windows.zip -OutFile fatmax-windows.zip
Expand-Archive fatmax-windows.zip . -Force
.\fatmax-windows\install.cmd
```

**ハブのアドレス・指紋・トークンを順に聞かれます。** アドレスは `192.168.0.10:8787` のように、
ハブの IP とポートを入れてください。指紋（`sha256//…`）とトークンはハブの画面の「導入」に出ています。
聞かれたくないときは、最後の行に渡します。

```powershell
.\fatmax-windows\install.cmd -Hub https://192.168.0.10:8787 -Pin '<指紋>' -Token '<トークン>'
```

通信は TLS で暗号化され、ハブへの接続はトークンで認証されます。ハブの証明書はハブが自分で作ったものなので、
`fatmax.exe` は**名前ではなく指紋で**照合します（PowerShell の `irm` ではこの照合ができないので、
ハブから取るものは全部 `fatmax.exe` が取ります）。

一式の中身は3つです。

| ファイル | 中身 |
|---|---|
| `fatmax.exe` | 実行ファイル（ハブ・ウォッチャー共通の1本） |
| `install.cmd` | ダブルクリックで `install.ps1` を動かす（その回だけ実行ポリシーを外す） |
| `install.ps1` | 入れる本体 |

`install.cmd` がやることは次のとおりです。

1. `fatmax.exe` を `%USERPROFILE%\.fatmax\bin\` に置く（hook はここを見ます。場所は変えられません）
2. ハブの宛先・指紋・トークンを保存する（`%USERPROFILE%\.fatmax\hub` と `known_hubs`）
3. hook と OTel と会話担当エージェント（fatmax-room など）を入れる（ハブが配っている `setup.ps1` を `fatmax.exe fetch` で取る。ユーザ全体の `settings.json` と `.claude\agents\`）。
   **取れなければ、ここで止まります**（届かない・指紋かトークンが違う）。
   hook の1行の形は、Claude Code が hook を動かすシェルに合わせます ——
   **Git Bash があれば sh の形、無ければ PowerShell の形**（`hook は … の形で入れます` と出ます）
4. ウォッチャーを**別の窓で**動かす（版・宛先・ハブへ届くかがその窓に出ます。**窓を閉じると止まります**）

終わったら **Claude Code を開き直してください**（OTel の設定は起動時にしか読まれません）。

<details>
<summary>ブラウザで落としたい場合</summary>

https://nodesi-jp.github.io/fatmax/windows/fatmax-windows.zip を落とし、**展開する前に** zip を右クリック →「プロパティ」→
下の「許可する」にチェックを入れてから展開します。展開したフォルダの `install.cmd` をダブルクリックしてください。

ブラウザで落としたものには「Web から来たファイル」の印が付き、そのままだと
「Windows によって PC が保護されました」で止まります。署名していないためで、中身の問題ではありません。
PowerShell の `irm` で落とせば、この印は付きません。

ハッシュは https://nodesi-jp.github.io/fatmax/windows/SHA256SUMS にあります（`Get-FileHash fatmax-windows.zip` で比べられます）。
</details>

## 2. 確かめる

```powershell
& "$HOME\.fatmax\bin\fatmax.exe" status
```

Claude Code を1回動かしてからハブの画面（`https://<ハブの IP>:8787/`）を開き、その会話が出れば通っています
（最初の1回はトークンを入れます。証明書はハブが自分で作ったものなので、ブラウザは一度警告を出します）。

## ウォッチャーについて

**ウォッチャーを動かさないと、記録はハブへ上がりません。** 消えはしません ——
`%USERPROFILE%\.fatmax\spool` に溜まっていて、動かせばまとめて流れます。

**窓を閉じると止まります。サインアウト・再起動でも止まります**（自分では立ち上がりません）。止まったら:

```powershell
Start-Process "$HOME\.fatmax\bin\fatmax.exe" -ArgumentList watch
```

サインインのたびに動かしたいなら、この1行をタスク スケジューラに登録してください（fatmax は自分では登録しません）。

画面に出る名前は、何もしなければコンピュータ名です。変えるなら（送るたびに読み直すので、再起動は要りません）:

```powershell
Set-Content "$HOME\.claude\fatmax-host" '開発機-Win'
```

## 新しい版に上げる

**Windows では自分で上がりません**（動いている `.exe` は置き換えられないため）。
**1. と同じ手順をもう一度**叩いてください。`install.cmd` が動いているウォッチャーを止めてから
置き換え、もう一度動かします。hook は入れ直しになりますが、二重にはなりません。

ハブと版を揃えてください（片方だけ古いと、欠けた機能が黙って動きません）。

## 外す

```powershell
Get-Process fatmax -ErrorAction SilentlyContinue | Stop-Process
[Console]::OutputEncoding = [Text.Encoding]::UTF8   # ハブから取る setup.ps1 の日本語を化けさせない
& ([scriptblock]::Create((& "$HOME\.fatmax\bin\fatmax.exe" fetch /setup.ps1 | Out-String))) -Uninstall
Remove-Item -Recurse -Force "$HOME\.fatmax"
```

`settings.json` から fatmax が入れたものだけを外します。あなた自身の設定は残ります。
最後の行で、まだハブへ送っていない記録（`spool`）も消えます。

## 前の版で壊れた settings.json を戻す

0.1.169 より前の版で入れた（入れ直した）ことがあるなら、まず壊れているかを見ます。

```powershell
Select-String -Path "$HOME\.claude\settings.json" -Pattern '"Length":|:\s*null'
```

**何も出なければ壊れていません。** 出たら、入れる前の控え（`settings.json.fleet-backup`）も同じように見ます。

```powershell
Select-String -Path "$HOME\.claude\settings.json.fleet-backup" -Pattern '"Length":|:\s*null'
```

- **控えから何も出ない** —— 控えが入れる前の中身です。戻してから、新しい版で入れ直してください
  （fatmax の設定は入れ直しで付きます）

  ```powershell
  Copy-Item "$HOME\.claude\settings.json.fleet-backup" "$HOME\.claude\settings.json" -Force
  ```

  そのあと「1. 一式を落として入れる」をもう一度。
- **控えからも出る** —— 前の版で2回以上入れたため、控えも壊れた中身で上書きされています。
  壊れた値（`{"Length": 17}` など）からは元の文字列を取り戻せないので、`Select-String` が指した行を
  手で書き直してください（`{"Length": …}` は元の配列、`null` は `[]`）。書き直したら入れ直します

## Windows ではできないこと

- **画面からの返信と、トークルームへ「本体で参加」は使えません**（`--replies` が macOS / Linux だけのため）
- トークルームの「エージェントで参加」は、install.cmd が置くエージェント定義（`%USERPROFILE%\.claude\agents\fatmax-room.md`）で
  入れます。**実機ではまだ確かめていません**（エージェントは curl でウォッチャーと話すので、Git Bash が要ります）

## うまくいかないとき

- **ハブの画面のセッション一覧にこのマシンが出ない（通知タブに「hook が1件も通っていません」）** ——
  `settings.json` の hook が動いていません。`& "$HOME\.fatmax\bin\fatmax.exe" status` の hook の行を見てください。
  「cmd.exe の形で入っています」なら 0.1.172 より前の一式なので、落とし直して入れ直してください。
  形は合っているのに届かないなら、Claude Code の見立てと違うシェルの形が入っています。
  Git for Windows を入れているなら `-Shell bash`、入れていないなら `-Shell powershell` を付けて入れ直してください
  （`.\fatmax-windows\install.cmd -Shell bash`）

- **「ハブから取れません」で止まる** —— ハブの IP・ポートと、ハブ側のファイアウォールを確かめてください。
  `Test-NetConnection <ハブの IP> -Port 8787` の `TcpTestSucceeded` が `True` なら届いています。
  届いているのに止まるなら、指紋かトークンが違います（`fatmax.exe setup` の出力に「知らないハブです」
  「トークンが通りません」のどちらかが出ています）
- **「Windows によって PC が保護されました」** —— 署名していないためです。「詳細情報」→「実行」で進めるか、
  上の `irm` で落とし直してください（`install.ps1` は置いた `fatmax.exe` の印を外しています）
- **「このシステムではスクリプトの実行が無効」** —— `install.ps1` を直に動かしています。`install.cmd` から動かしてください
- **「代入式が無効です」で止まる**（`[string]$Hub = ''` の行を指している） —— 0.1.167 の一式です
  （`install.ps1` の先頭に BOM が2つ付いていて、PowerShell が `param(...)` を読めませんでした）。落とし直してください
- **文字化けして途中で止まる** —— `install.ps1` を開いて保存し直すと壊れます（BOM 付き UTF-8 のままにする必要があります）。落とし直してください
- **ハブの画面にこのマシンが出ない** —— `& "$HOME\.fatmax\bin\fatmax.exe" status` の `⚠` / `✗` の行に理由が出ます。
  ウォッチャーが止まっていたら、上の `Start-Process` の行で動かしてください

---

[README に戻る](README.md) ／ [詳しい説明（install）](INSTALL.md)
