#!/usr/bin/env bash
# fatmax の hook（プラグイン版）。Claude Code が bash で動かす（Windows も Git Bash）。
# **何も出さず、必ず 0 で終わる**（hook は async。出したものは Claude Code が読み、失敗は誰も見ない）。
# OS ごとの違いはここに閉じ込める —— settings.json に OS 依存の1行を書かない。
# 宛先はこのマシンのウォッチャー（127.0.0.1:8788）だけ。Windows は WSL の中のウォッチャーが受ける
# （WSL が localhost で受けている口は、Windows からもそのまま届く）。
ev="$1"
F=$(mktemp 2>/dev/null) || exit 0
cat >"$F"
# 一発（fatmax hook）があればそちら。Windows に置くのは fatmax.exe
R="$HOME/.fatmax/bin/fatmax"; [ -x "$R" ] || R="$R.exe"
[ -x "$R" ] || R=$(command -v fatmax 2>/dev/null) || R=""
# **起動できなければ curl に落ちる。** Windows のスマート アプリ コントロールは署名の無い .exe を止める
# （止められても hook には何も言わない）。一発は起動さえすれば必ず 0 で終わるので、0 でない＝起動できなかった
if [ -n "$R" ] && MSYS_NO_PATHCONV=1 "$R" hook --event "$ev" <"$F" >/dev/null 2>&1; then
  rm -f "$F"; exit 0
fi
H=$(head -n1 "$HOME/.claude/fatmax-host" 2>/dev/null)
curl -sS -X POST --max-time 1 -H 'Content-Type: application/json' -H "X-Fatmax-Host: ${H:-$(hostname)}" \
  --data-binary @"$F" "http://127.0.0.1:8788/ingest?event=$ev" >/dev/null 2>&1
rm -f "$F"
exit 0
