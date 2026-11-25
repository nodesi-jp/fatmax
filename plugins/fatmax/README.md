# fatmax プラグイン

LAN の複数マシンで動く Claude Code を1画面に集める **fatmax** の、Claude Code プラグインです。

- **hook** … Claude Code の動きを、このマシンのウォッチャー（`fatmax watch`、127.0.0.1:8788）へ渡します
- **会話担当エージェント** … `fatmax-room`（トークルーム）・`fatmax-repo`（状況を送る）・`fatmax-resume`（続きを始める）
- **`/fatmax:setup`** … ウォッチャーの実行ファイルを置き、ハブの宛先・指紋・トークンを保存し、ウォッチャーを起こします

## 入れる（macOS / Linux / Windows 共通）

Claude Code で:

```
/plugin marketplace add nodesi-jp/fatmax
/plugin install fatmax@fatmax
/fatmax:setup <ハブの画面の「導入」に出ている1行>
```

Windows は Git for Windows（Git Bash）が要ります（Claude Code が hook を bash で動かすため）。
詳しくは https://nodesi-jp.github.io/fatmax/ を見てください。
