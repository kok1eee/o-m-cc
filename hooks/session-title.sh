#!/bin/bash
# SessionStart: セッションタイトルを設定（複数ウィンドウ / cmux / 跨マシン handoff での
# 識別性向上、v2.1.152+ の hookSpecificOutput.sessionTitle）。
#
# 既存の digest hook（session-resume.sh 等）はプレーンテキストで banner を出している。
# それらを壊さないよう、本 hook は sessionTitle だけを JSON で出す専用 hook として独立させる
# （additionalContext は出さない＝他 hook の表示に干渉しない）。
set -euo pipefail

cat > /dev/null  # stdin を消費

# Headless（claude -p）ではタイトル不要
if [[ "${CLAUDE_NON_INTERACTIVE:-}" = "1" ]]; then
  exit 0
fi

# jq が無ければ何もしない（既存 hook と同じく optional 動作）
command -v jq >/dev/null 2>&1 || exit 0

# repo 名を基本タイトルにする（jj → git → cwd）
ROOT=""
if command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
  ROOT=$(jj root 2>/dev/null || true)
elif command -v git >/dev/null 2>&1 && git rev-parse --show-toplevel >/dev/null 2>&1; then
  ROOT=$(git rev-parse --show-toplevel 2>/dev/null || true)
fi
[[ -z "$ROOT" ]] && ROOT="$PWD"
TITLE=$(basename "$ROOT")

# journal.md に最新エントリ見出しがあれば付加（handoff 後の識別性向上）
JOURNAL="$ROOT/.claude/journal.md"
if [[ -f "$JOURNAL" ]]; then
  HEADING=$(grep -m1 '^## ' "$JOURNAL" 2>/dev/null | sed 's/^##[[:space:]]*//' | cut -c1-40 || true)
  [[ -n "$HEADING" ]] && TITLE="${TITLE}: ${HEADING}"
fi

jq -cn --arg t "$TITLE" \
  '{hookSpecificOutput: {hookEventName: "SessionStart", sessionTitle: $t}}'
exit 0
