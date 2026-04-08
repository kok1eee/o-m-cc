#!/bin/bash
# UserPromptSubmit: context.md の Intent を sessionTitle として設定
# - Intent が見つからなければ何もしない
# TODO: 将来的に session_name の respect policy を検討（ユーザーの /rename を尊重するか）
set -euo pipefail

INPUT=$(cat)

# cwd 取得（複数プロジェクトにまたがる場合は cwd 優先）
CWD=$(echo "$INPUT" | jq -r '.cwd // empty' 2>/dev/null)
[[ -z "$CWD" ]] && CWD="$PWD"

CONTEXT_FILE="${CWD}/.claude/context.md"
if [[ ! -f "$CONTEXT_FILE" ]]; then
  exit 0
fi

# Intent 抽出: `**Intent:** <本文>` の本文部分
INTENT=$(grep -m1 '^\*\*Intent:\*\*' "$CONTEXT_FILE" 2>/dev/null \
  | sed -e 's/^\*\*Intent:\*\*[[:space:]]*//' \
  | tr -d '\r')

if [[ -z "$INTENT" ]]; then
  exit 0
fi

# 80 文字で切り詰め（サイドバー・タブ名の表示余裕）
# 日本語対応のため文字数ベース
if [[ ${#INTENT} -gt 80 ]]; then
  INTENT="${INTENT:0:77}..."
fi

# JSON 出力
jq -n --arg title "$INTENT" '{
  hookSpecificOutput: {
    hookEventName: "UserPromptSubmit",
    sessionTitle: $title
  }
}'
