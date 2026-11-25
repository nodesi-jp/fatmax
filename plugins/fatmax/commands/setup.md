---
description: このマシンを fatmax のハブに繋ぐ（ウォッチャーの実行ファイルを置き、宛先・指紋・トークンを保存し、ウォッチャーを起こす）
argument-hint: ハブの画面の「導入」に出ている1行（貼らなければ聞きます）
---

このマシンを fatmax のハブに繋いでください。hook と会話担当エージェントは、このプラグイン（fatmax@fatmax）が
もう持っています。あなたがやるのは **ウォッチャー（fatmax の実行ファイル）を置いて、ハブの宛先・指紋・トークンを
保存し、ウォッチャーを人から見える形で起こす** ことです。最後に「5. 報告」の形で返してください。

渡されたもの: $ARGUMENTS

## 守ること

- **sudo は使わない。** 書き込むのはホームの下だけ
- **トークンを報告や説明に書かない**（指紋は書いてよい）
- **失敗したら推測で進めない。** 出たメッセージをそのまま報告して止まる
- **settings.json を手で編集しない。** 下の道具が fatmax の行だけを扱う

## 1. 宛先・指紋・トークンを決める

- 上の「渡されたもの」に、ハブの画面の「導入」の1行（`curl … --pinnedpubkey 'sha256//…' 'https://<ハブ>:8787/setup.sh?t=<トークン>' | sh`）か、
  Claude に貼る1文（`…/install.md?t=…`）があれば、そこから **ハブ（`https://<IP>:<ポート>`）・指紋（`sha256//…`）・トークン（`t=` の値）** を取る
- 無ければ、前に入れた値を見る: `~/.fatmax/hub`（宛先）と `~/.fatmax/known_hubs`（1行に「指紋 トークン 宛先」）。
  あれば「前の値を使いますか」と人に聞く
- それも無ければ、人に3つを聞く（ハブの画面の「導入」に出ています。ハブのマシンなら `fatmax token`）

## 2. OS を調べる

`uname -s` が `Darwin` なら macOS、`Linux` なら Linux、`MINGW…` / `MSYS…` なら Windows（Git Bash）。

## 3-A. macOS / Linux

```sh
curl -fsSL -k --pinnedpubkey '<指紋>' '<ハブ>/setup.sh?t=<トークン>' | sh -s -- --plugin
```

実行ファイル（パッケージで入っていなければ `~/.fatmax/bin/fatmax`）を置き、宛先・指紋・トークンを保存し、
OTel の設定を入れます。**`--plugin` を必ず付ける**（settings.json の古い fatmax の hook を外し、新しく書かない。
付けないとプラグインの hook と2組並んで、全部が2回届きます）。

ウォッチャーを起こす（もう動いていて版が同じなら何もしない: `curl -s --max-time 2 http://127.0.0.1:8788/version`）。
**あなたのシェルの中で前に置いて動かさない**（コマンドが終わらず、セッションを閉じると止まる）:

- macOS: `osascript -e 'tell application "Terminal" to do script "fatmax watch || ~/.fatmax/bin/fatmax watch"'`
- Linux: 人に「別の端末で `fatmax watch` を動かしたままにしてください」と頼む（tmux があれば `tmux new -d -s fatmax 'fatmax watch'`）

## 3-B. Windows

次の中身を一時ファイル（例 `$TEMP/fatmax-setup.ps1`）に書き、`powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$TEMP/fatmax-setup.ps1"` で流す
（`-Command '…'` で包むと引用が入れ子になって壊れます。中身は ASCII だけなので BOM は要りません）:

```powershell
[Console]::OutputEncoding = [Text.Encoding]::UTF8
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
$z = Join-Path $env:TEMP 'fatmax-windows.zip'
Invoke-RestMethod 'https://nodesi-jp.github.io/fatmax/windows/fatmax-windows.zip' -OutFile $z
Expand-Archive $z $env:TEMP -Force
& (Join-Path $env:TEMP 'fatmax-windows\install.ps1') -Hub '<ハブ>' -Pin '<指紋>' -Token '<トークン>' -Plugin
```

`-Plugin` を必ず付ける（理由は 3-A と同じ）。install.ps1 が実行ファイルを置き、宛先・指紋・トークンを保存し、
OTel の設定を入れ、**ウォッチャーを別の窓で起こします**（動いていれば止めてから入れ替える）。

## 4. 確かめる

```sh
fatmax status                      # macOS / Linux（無ければ ~/.fatmax/bin/fatmax status）
~/.fatmax/bin/fatmax.exe status    # Windows の Git Bash（& から始めない）
```

見るのは: ハブと版が一致しているか／ウォッチャーが動いているか。「通った数 hook 0 件」はまだ正常です。

## 5. 報告（この形で）

```
fatmax: ✓ 繋がりました          （だめなら ✗ 繋がっていません: 理由を1行）
  版          このマシン 0.1.N ／ ハブ 0.1.N（一致 / 不一致）
  ウォッチャー  ✓ 動いています（窓 / 端末 / tmux）  または  人に起動を頼んだ
  次          Claude Code を開き直して1回やりとりしたら、fatmax status の「通った数 hook」が 1 以上か見てください
```

Claude Code を開き直すのは、OTel の設定が起動したときにしか読まれないためです。
