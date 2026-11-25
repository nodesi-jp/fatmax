#!/usr/bin/env bash
# fatmax の hook（プラグイン版）。Claude Code が bash で動かす（Windows も Git Bash）。
# **何も出さず、必ず 0 で終わる**（hook は async。出したものは Claude Code が読み、失敗は誰も見ない）。
# OS ごとの違いはここに閉じ込める —— settings.json に OS 依存の1行を書かない（Windows の cmd.exe の形が
# 1件も届かなかった件の反省）。宛先はこのマシンのウォッチャー（127.0.0.1:8788）だけ。
ev="$1"
# 一発（fatmax hook）を探す。Windows に置くのは fatmax.exe
R="$HOME/.fatmax/bin/fatmax"; [ -x "$R" ] || R="$R.exe"
[ -x "$R" ] || R=$(command -v fatmax 2>/dev/null) || R=""
if [ -n "$R" ]; then
  # Git Bash は / で始まる引数を書き換える（MSYS のパス変換）。いまは / で始まる引数は無いが、念のため止める
  MSYS_NO_PATHCONV=1 "$R" hook --event "$ev" >/dev/null 2>&1
else
  # 実行ファイルが無いマシン: curl でウォッチャーへ（本文はいったんファイルに落とす。curl は繋がらなくても stdin を読み切る）
  H=$(head -n1 "$HOME/.claude/fatmax-host" 2>/dev/null)
  F=$(mktemp 2>/dev/null) || exit 0
  cat >"$F"
  curl -sS -X POST --max-time 1 -H 'Content-Type: application/json' -H "X-Fatmax-Host: ${H:-$(hostname)}" \
    --data-binary @"$F" "http://127.0.0.1:8788/ingest?event=$ev" >/dev/null 2>&1
  rm -f "$F"
fi
exit 0
