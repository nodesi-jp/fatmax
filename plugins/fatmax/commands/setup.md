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
**動いていて版が違うなら、先に止める**（`pkill -f 'fatmax watch'`。口 8788 は1つしか持てないので、止めないと新しいほうが起きられない）。
**あなたのシェルの中で前に置いて動かさない**（コマンドが終わらず、セッションを閉じると止まる）:

起こすのは **`~/.fatmax/bin/fatmax` があればそれ、無ければ `fatmax`**（以下 `<W>`）。hook も先にこちらを使い、setup.sh が
ハブと同じ版にしてある。PATH の `fatmax` はパッケージの古い版のことがある。

- macOS: `osascript -e 'tell application "Terminal" to do script "<W> watch"'`
- Linux で tmux があれば: `tmux new -d -s fatmax '<W> watch'`
- それ以外（Linux・コンテナで tmux が無い）は人に頼む。**頼むときは、説明より先に、この1行だけを出す**:

  ```
  ▶ 別の端末で起動してください（その端末は開いたままに）:  <W> watch
  ```

  理由や補足は書かない（読む人が探すのは叩くコマンドだけ）。出したら、**起きるまで自分で待つ**（最長 2 分）:

  ```sh
  for i in $(seq 1 60); do curl -s --max-time 1 http://127.0.0.1:8788/version >/dev/null && { echo 起きました; break; }; sleep 2; done
  ```

  起きたら 4. へ進む。2 分で起きなければ、同じ1行をもう一度出して終わる（「起動したら /fatmax:setup をもう一度」と添える）
- コンテナの中（`/.dockerenv` がある）で `~/.claude/fatmax-host` が無ければ、**名前を付けるよう人に頼む**
  （`echo '<好きな名前>' > ~/.claude/fatmax-host`）。名前は勝手に決めない。付けないと hostname（コンテナの ID）が使われ、
  作り直すたびに別のマシンとして出る

## 3-B. Windows（ウォッチャーは WSL の中で動かす）

Windows では **fatmax.exe を使いません**。署名の無い .exe は Windows のスマート アプリ コントロールに止められるため、
**ウォッチャーは WSL（Linux）の中で Linux 版を動かします**。このプラグインの hook は `127.0.0.1:8788` へ curl で送るので、
WSL のウォッチャーがそのまま受けます（WSL が localhost で受けている口は Windows からも届きます）。

以下はあなたのシェル（Git Bash）から流します。`wsl.exe` に渡す引数は Git Bash に書き換えられないよう、
**`MSYS_NO_PATHCONV=1` を付けて**ください。

1. **WSL があるか。** `MSYS_NO_PATHCONV=1 wsl.exe -l -q` で配布（Ubuntu など）が1つ以上出るか見る。
   無ければ**止めて人に頼む**（管理者の PowerShell で `wsl --install -d Ubuntu`、再起動が要ります）
2. **Windows 側の古いウォッチャーを止めて、fatmax.exe を外す**（8788 の取り合いを避け、hook が止められる .exe に頼らないため）:
   ```sh
   powershell.exe -NoProfile -Command "Get-Process fatmax -ErrorAction SilentlyContinue | Stop-Process -Force"
   [ -f ~/.fatmax/bin/fatmax.exe ] && mv ~/.fatmax/bin/fatmax.exe ~/.fatmax/bin/fatmax.exe.off
   ```
3. **WSL の中に入れる**（実行ファイル・宛先・指紋・トークン。sudo は使わず `~/.fatmax/bin` に置かれます）:
   ```sh
   MSYS_NO_PATHCONV=1 wsl.exe -e bash -lc "curl -fsSL -k --pinnedpubkey '<指紋>' '<ハブ>/setup.sh?t=<トークン>' | sh -s -- --plugin"
   ```
4. **画面に出る名前を Windows の名前に揃える**（揃えないと WSL の名前で別のマシンとして出ます）:
   ```sh
   MSYS_NO_PATHCONV=1 wsl.exe -e bash -lc "mkdir -p ~/.claude && echo '$COMPUTERNAME' > ~/.claude/fatmax-host"
   ```
5. **Windows 側の settings.json を整える**（古い fatmax の hook を外し、OTel の設定だけ入れる。宛先は同じ 127.0.0.1:8788）。
   ハブの setup.ps1 を WSL の fatmax で取って、BOM を付けたファイルにしてから `-Plugin` で流します:
   ```sh
   S="$TEMP/fatmax-setup-hub.ps1"
   printf '\357\273\277' > "$S"
   MSYS_NO_PATHCONV=1 wsl.exe -e bash -lc 'F=~/.fatmax/bin/fatmax; [ -x "$F" ] || F=fatmax; "$F" fetch /setup.ps1' >> "$S"
   powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$S" -Plugin
   ```
6. **WSL のウォッチャーを窓で起こす**。もう動いていて版が同じなら何もしない。版が違えば先に止める
   （`MSYS_NO_PATHCONV=1 wsl.exe -e pkill -f 'fatmax watch'`）。transcript は Windows 側の置き場を読ませます:
   ```sh
   WP=$(MSYS_NO_PATHCONV=1 wsl.exe wslpath -u "$USERPROFILE" | tr -d '\r')
   MSYS_NO_PATHCONV=1 cmd.exe /c start "fatmax watch (WSL)" wsl.exe -e bash -lc "F=~/.fatmax/bin/fatmax; [ -x \$F ] || F=fatmax; \$F watch --projects $WP/.claude/projects"
   ```
   窓が1つ開いて、版・宛先・「ハブへ届きます」が出ます。**この窓を閉じるとウォッチャーが止まります。**
7. **Windows から届くか**: `curl -s --max-time 3 http://127.0.0.1:8788/version` に版が返れば、hook は WSL のウォッチャーに届きます

## 4. 確かめる

```sh
<W> status                         # macOS / Linux（<W> は 3-A で決めたもの）
MSYS_NO_PATHCONV=1 wsl.exe -e bash -lc 'F=~/.fatmax/bin/fatmax; [ -x "$F" ] || F=fatmax; "$F" status'    # Windows（WSL の中のウォッチャー）
```

見るのは: ハブと版が一致しているか／ウォッチャーが動いているか。「通った数 hook 0 件」はまだ正常です。

## 5. 報告（この形で）

```
fatmax: ✓ 繋がりました          （だめなら ✗ 繋がっていません: 理由を1行）
  版          このマシン 0.1.N ／ ハブ 0.1.N（一致 / 不一致）
  ウォッチャー  ✓ 動いています（窓 / 端末 / tmux / WSL の窓）
  次          Claude Code を開き直して1回やりとりしたら、<W> status の「通った数 hook」が 1 以上か見てください
```

- **ウォッチャーが起きていなければ、報告の最初の行を `▶ 別の端末で起動してください（その端末は開いたままに）:  <W> watch` にする**
  （「✓ 繋がりました」から始めない。動いていないのに繋がったように読める）
- 「次」の行は、初めて入れたとき（setup.sh を流したとき）だけ。Claude Code を開き直すのは、OTel の設定が起動したときにしか読まれないため
- 報告のあとに長い説明を足さない。指紋・宛先は聞かれたら答える
