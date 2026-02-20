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

HANDOVER_FILE="plan/HANDOVER.md"
HAS_JQ=false
command -v jq >/dev/null 2>&1 && HAS_JQ=true

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

# グローバル skill-candidates.md に追記（クロスプロジェクト蓄積）
SKILL_CANDIDATES="$HOME/.claude/skill-candidates.md"
PROJECT_NAME=$(basename "$(pwd)")
TODAY=$(date +%Y-%m-%d)

# ディレクトリ確保
mkdir -p "$(dirname "$SKILL_CANDIDATES")"

# 追記
{
  echo ""
  echo "### ${TODAY} ${PROJECT_NAME}"
  for item in "${RECURRING[@]}"; do
    echo "- ${item}"
  done
} >> "$SKILL_CANDIDATES"

log_debug "promote-checker: appended ${#RECURRING[@]} patterns to $SKILL_CANDIDATES"

# skill-candidates.md の既存内容を読み取り（クロスプロジェクト文脈）
CANDIDATES_CONTEXT=""
if [[ -f "$SKILL_CANDIDATES" ]]; then
  CANDIDATES_CONTEXT=$(tail -50 "$SKILL_CANDIDATES" 2>/dev/null || echo "")
fi

PROMOTE_MSG="🔁 繰り返しパターン検出 — 自動スキル昇格を実行してください。\n\n検出パターン: ${PATTERNS}\nプロジェクト: ${PROJECT_NAME}\n\n以下の手順で自動昇格:\n1. 上記パターンと ~/.claude/skill-candidates.md の履歴を分析\n2. 複数プロジェクトで出現 → グローバルルール（~/.claude/CLAUDE.md）\n   単一プロジェクトで頻出 → プロジェクトルール（CLAUDE.md）\n3. 既存ルールと重複しないか確認してからスキルを作成"

if $HAS_JQ; then
  jq -n --arg msg "$PROMOTE_MSG" '{ "systemMessage": $msg }'
else
  echo "{\"systemMessage\": \"$(echo "$PROMOTE_MSG" | sed 's/"/\\"/g')\"}"
fi

exit 0
