# Windows で入れる（試験版）

**Windows で動いている Claude Code を、LAN にあるハブへ繋ぐ**手順です。いま配っているのは `0.1.169` です。

> **試験版です。実機の Windows ではまだ確かめていません。** スクリプトが読めて動くところまでは
> PowerShell 7 で確かめてあります。うまく動かないときは、下の「うまくいかないとき」を見てください。

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
3. hook と OTel を入れる（ハブが配っている `setup.ps1` を `fatmax.exe fetch` で取る。ユーザ全体の `settings.json`）。
   **取れなければ、ここで止まります**（届かない・指紋かトークンが違う）
4. ウォッチャーを裏で動かす（ログは `%USERPROFILE%\.fatmax\watch.log`）

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

**サインアウト・再起動で止まります**（自分では立ち上がりません）。止まったら:

```powershell
Start-Process "$HOME\.fatmax\bin\fatmax.exe" -ArgumentList watch -WindowStyle Hidden
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
& ([scriptblock]::Create((& "$HOME\.fatmax\bin\fatmax.exe" fetch /setup.ps1 | Out-String))) -Uninstall
Remove-Item -Recurse -Force "$HOME\.fatmax"
```

`settings.json` から fatmax が入れたものだけを外します。あなた自身の設定は残ります。
最後の行で、まだハブへ送っていない記録（`spool`）も消えます。

## Windows ではできないこと

- **画面からの返信と、トークルームへ「本体で参加」は使えません**（`--replies` が macOS / Linux だけのため）
- **トークルームのエージェント（`fatmax-room`）は入りません。** `setup.ps1` はエージェントの定義を配らないので、
  「エージェントで参加」も、このマシンでは試していません

## うまくいかないとき

- **「ハブから取れません」で止まる** —— ハブの IP・ポートと、ハブ側のファイアウォールを確かめてください。
  `Test-NetConnection <ハブの IP> -Port 8787` の `TcpTestSucceeded` が `True` なら届いています。
  届いているのに止まるなら、指紋かトークンが違います（`fatmax.exe setup` の出力に「知らないハブです」
  「トークンが通りません」のどちらかが出ています）
- **「Windows によって PC が保護されました」** —— 署名していないためです。「詳細情報」→「実行」で進めるか、
  上の `irm` で落とし直してください（`install.ps1` は置いた `fatmax.exe` の印を外しています）
- **「このシステムではスクリプトの実行が無効」** —— `install.ps1` を直に動かしています。`install.cmd` から動かしてください
- **文字化けして途中で止まる** —— `install.ps1` を開いて保存し直すと壊れます（BOM 付き UTF-8 のままにする必要があります）。落とし直してください
- **ハブの画面にこのマシンが出ない** —— `& "$HOME\.fatmax\bin\fatmax.exe" status` の `⚠` / `✗` の行に理由が出ます。
  ウォッチャーが止まっていたら、上の `Start-Process` の行で動かしてください

---

[README に戻る](README.md) ／ [詳しい説明（install）](INSTALL.md)
