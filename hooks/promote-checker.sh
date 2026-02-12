#!/bin/bash
# Promote Checker - HANDOVER.md 書き込み後に VCS 履歴から繰り返しパターンを検出
# Stop hook として generate-handover.sh の後に実行

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  log_debug() { :; }
  log_error() { echo "❌ $1" >&2; }
fi

HANDOVER_FILE="spec/plan/HANDOVER.md"

# HANDOVER.md がなければスキップ
if [[ ! -f "$HANDOVER_FILE" ]]; then
  log_debug "promote-checker: HANDOVER.md not found, skipping"
  exit 0
fi

# VCS コマンドを判定
VCS_CMD=""
if command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
  VCS_CMD="jj"
elif command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  VCS_CMD="git"
fi

# VCS がなければスキップ
if [[ -z "$VCS_CMD" ]]; then
  log_debug "promote-checker: no VCS found, skipping"
  exit 0
fi

# HANDOVER.md の VCS 履歴を取得（最新を除く過去の diff）
HISTORY=""
if [[ "$VCS_CMD" == "jj" ]]; then
  HISTORY=$(jj log -p --no-graph -- "$HANDOVER_FILE" 2>/dev/null | head -500 || echo "")
elif [[ "$VCS_CMD" == "git" ]]; then
  HISTORY=$(git log -p --skip=1 -- "$HANDOVER_FILE" 2>/dev/null | head -500 || echo "")
fi

# 履歴がなければスキップ（初回 or 履歴が浅い）
if [[ -z "$HISTORY" ]]; then
  log_debug "promote-checker: no VCS history for HANDOVER.md, skipping"
  exit 0
fi

# 現在の HANDOVER.md から「教訓と注意点」セクションのキーワードを抽出
GOTCHAS=$(sed -n '/^## 教訓/,/^## /{ /^## 教訓/d; /^## /d; p; }' "$HANDOVER_FILE" 2>/dev/null || echo "")

if [[ -z "$GOTCHAS" ]]; then
  log_debug "promote-checker: no gotchas section found, skipping"
  exit 0
fi

# 各行からキーワードを抽出して履歴と照合
RECURRING=()

while IFS= read -r line; do
  # 空行やマークダウン記号だけの行はスキップ
  line=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*//' | xargs)
  [[ -z "$line" ]] && continue
  [[ ${#line} -lt 5 ]] && continue

  # 行の先頭20文字をキーワードとして使用（長すぎるとマッチしにくい）
  KEYWORD="${line:0:30}"

  # 履歴内にキーワードが存在するか
  if echo "$HISTORY" | grep -qiF "$KEYWORD" 2>/dev/null; then
    RECURRING+=("$line")
  fi
done <<< "$GOTCHAS"

# 繰り返しパターンがなければ何も出力しない
if [[ ${#RECURRING[@]} -eq 0 ]]; then
  log_debug "promote-checker: no recurring patterns found"
  exit 0
fi

# 繰り返しパターンを検出 → systemMessage で promote を提案
PATTERNS=""
for item in "${RECURRING[@]}"; do
  # 最初の3件まで
  if [[ $(echo "$PATTERNS" | wc -l) -ge 3 ]]; then
    break
  fi
  if [[ -n "$PATTERNS" ]]; then
    PATTERNS+="、"
  fi
  # 40文字で切り詰め
  if [[ ${#item} -gt 40 ]]; then
    PATTERNS+="${item:0:40}…"
  else
    PATTERNS+="$item"
  fi
done

log_debug "promote-checker: recurring patterns found: $PATTERNS"

jq -n --arg patterns "$PATTERNS" '{
  "systemMessage": ("🔁 繰り返しパターン検出（HANDOVER.md 履歴）: " + $patterns + " — `/o-m-cc:promote` でスキル昇格を検討してください。")
}'

exit 0
