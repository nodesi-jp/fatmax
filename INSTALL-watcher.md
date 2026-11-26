# ウォッチャーを入れる（見たいマシン）

**見たいマシンそれぞれに、ウォッチャーを1つ入れます。** このページはそれだけの手順です
（macOS / Linux / コンテナ / Windows 共通）。いま配っているのは `0.1.184` です。

- ハブ（画面と記録を集める1台）がまだ無い → 先に **[Docker で動かす](INSTALL-docker.md)** か **[apt](INSTALL-apt.md)** ／ **[dnf](INSTALL-dnf.md)** でハブを立てます
- 用意するのは **ハブの画面の「導入」に出ている1行**だけです（ハブのマシンなら `fatmax token` にも出ます）

## 入れる

そのマシンの **Claude Code で4行**打ちます。

```
/plugin marketplace add nodesi-jp/fatmax#plugin
/plugin install fatmax@fatmax
/reload-plugins
/fatmax:setup <ハブの画面の「導入」に出ている1行>
```

- **`/reload-plugins` を飛ばすと `/fatmax:setup` が Unknown command になります**
- **1行目の `#plugin` を落とさないでください。** 無いと配っている実行ファイルごと（200MB）取り込むことになり、遅い回線では
  `Unable to create '…/shallow.lock': No such file or directory` で止まります（Claude Code の取り込みが 2 分で切れるため）。
  前に `#plugin` 無しで足して動いているマシンは、そのままで構いません
- `/fatmax:setup` が、ウォッチャー（fatmax の実行ファイル）を置き、ハブの宛先・指紋・トークンを保存し、ウォッチャーを起こします。
  hook と会話担当エージェントはプラグインが持っています
- 終わったら **Claude Code を開き直してください**（OTel の設定は起動したときにしか読まれません）

### OS ごとの違い

| | 先にやること | ウォッチャーの起こし方 |
|---|---|---|
| **macOS** | なし | Terminal の窓が1つ開きます |
| **Linux** | なし | 「▶ 別の端末で起動してください: `~/.fatmax/bin/fatmax watch`」と出ます。端末をもう1つ開いて叩き、開いたままにします（起きたかは `/fatmax:setup` が待って確かめます） |
| **コンテナ** | **名前を付ける**: `echo 'dev-linux' > ~/.claude/fatmax-host` | Linux と同じ。VS Code ならターミナルをもう1つ開きます |
| **Windows** | **Git for Windows（Git Bash）と WSL（Ubuntu など）** | WSL の窓が1つ開きます（中で Linux 版が動きます） |

- **コンテナで名前を付けないと**、hostname（コンテナの ID）が使われ、作り直すたびに別のマシンとして出ます
- **コンテナを作り直す（Rebuild）と、入れたものは全部消えます。** もう一度4行を打ちます
- コンテナからハブへ届かないとき（ハブが別のネットワークにある）は **[複数 EC2 × 複数コンテナ](INSTALL-ec2.md)** の SSH で繋ぐ手順
- **Windows は fatmax.exe を使いません。** 署名の無い .exe は Windows のスマート アプリ コントロールに止められるため、
  ウォッチャーは WSL の中で動かします。WSL が無ければ、管理者の PowerShell で `wsl --install -d Ubuntu`（再起動が要ります）。
  前に fatmax.exe で入れていたら、`/fatmax:setup` がそれを止めて外します
- **前に `setup.sh` の1行で入れたマシンも、そのまま4行で大丈夫です。** settings.json の古い fatmax の hook は外します
  （2組並ぶと全部が2回届くため）

## 入ったか確かめる

Claude Code を開き直して1回やりとりしてから:

```sh
~/.fatmax/bin/fatmax status     # パッケージ（apt / dnf）だけで入れたマシンは fatmax status。Windows は WSL の中で叩く
```

- **「通った数 hook」が 1 以上**なら届いています。ハブの画面の一覧にもそのマシンが出ます
- 0 のままなら、Claude Code を開き直していないか、ウォッチャーが止まっています

## マシンを再起動したら

**ウォッチャーは自動では起きません。** 止まっている間の記録は `~/.fatmax/spool` に溜まるだけで、消えはしません
（起こせばまとめて流れます）。起こし直すのは Claude Code で:

```
/fatmax:setup
```

1行を貼らなくても、前に入れた宛先・指紋・トークンを使うか聞いてきます。macOS / Linux なら端末で `~/.fatmax/bin/fatmax watch` を叩くだけでも同じです。

## 上げる

```
/plugin update fatmax@fatmax
/reload-plugins
/fatmax:setup
```

ウォッチャーの実行ファイルも、ハブと同じ版に上がります（動いている古いウォッチャーは止めて起こし直します）。
**ハブとウォッチャーの版は揃えてください**（片方だけ古いと、欠けた機能が黙って動きません）。
apt / dnf のパッケージで入れたマシンは、パッケージのほうを上げます（`sudo apt install fatmax` ／ `sudo dnf upgrade --refresh fatmax`）。

## 外す

1. ウォッチャーの窓（端末）を閉じる
2. settings.json から fatmax が入れた設定（OTel）を外す。ハブの「導入」の1行の最後の `| sh` を `| sh -s -- --uninstall` にして叩きます
3. Claude Code で `/plugin uninstall fatmax@fatmax`
4. 置いたファイルを消す: `rm -rf ~/.fatmax`（まだハブへ送っていない記録も消えます）

Windows は 2. と 4. を Git Bash で次のようにします（ハブの setup.ps1 を WSL の fatmax で取って流します）:

```sh
S="$TEMP/fatmax-setup-hub.ps1"; printf '\357\273\277' > "$S"
MSYS_NO_PATHCONV=1 wsl.exe -e bash -lc 'F=$(command -v fatmax || echo ~/.fatmax/bin/fatmax); "$F" fetch /setup.ps1' >> "$S"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$S" -Uninstall      # Windows 側の settings.json
MSYS_NO_PATHCONV=1 wsl.exe -e bash -lc 'rm -rf ~/.fatmax'                     # WSL 側のウォッチャー
rm -rf ~/.fatmax                                                                # Windows 側の残り
```

あなた自身の設定・hook は残ります。

## プラグインを使わない場合

`setup.sh` の1行で、settings.json に hook を直接入れる道も残してあります → **[見たいマシンを繋ぐ](INSTALL.md#見たいマシンを繋ぐ)**。
プラグインと両方入れると全部が2回届くので、どちらか1つにしてください。
