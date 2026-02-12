#!/bin/bash
# Auto-generate HANDOVER.md on session stop (lightweight fallback)
# /o-m-cc:handover で生成済みの場合はスキップ
# spec/plan/ にタスクファイルがある場合のみ生成

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  log_debug() { :; }
  log_error() { echo "❌ $1" >&2; }
  to_number() { local v="$1"; [[ "$v" =~ ^[0-9]+$ ]] && echo "$v" || echo "${2:-0}"; }
fi

PLAN_DIR="spec/plan"
HANDOVER_FILE="${PLAN_DIR}/HANDOVER.md"
TASKS_FILE="${PLAN_DIR}/tasks.md"

# spec/plan/ が存在しない場合はスキップ
if [[ ! -d "$PLAN_DIR" ]]; then
  exit 0
fi

# /o-m-cc:handover で既に生成済みならスキップ（リッチ版を優先）
if [[ -f "$HANDOVER_FILE" ]]; then
  log_debug "HANDOVER.md が既に存在するためスキップ"
  exit 0
fi

# tasks.md が存在しない場合はスキップ
if [[ ! -f "$TASKS_FILE" ]]; then
  exit 0
fi

# タスク状態を解析
COMPLETED=$(grep -cE '^\s*-\s*\[x\]' "$TASKS_FILE" 2>/dev/null || true)
COMPLETED=${COMPLETED:-0}
COMPLETED=$((COMPLETED + 0))  # 数値化

TOTAL=$(grep -cE '^\s*-\s*\[[ x]\]' "$TASKS_FILE" 2>/dev/null || true)
TOTAL=${TOTAL:-0}
TOTAL=$((TOTAL + 0))  # 数値化

# 現在のフェーズを検出（未完了タスクがある最初のフェーズ）
CURRENT_PHASE=""
CURRENT_TASK=""
while IFS= read -r line; do
  if echo "$line" | grep -qE '^##\s+Phase'; then
    CURRENT_PHASE=$(echo "$line" | sed 's/^##[[:space:]]*//')
  fi
  if echo "$line" | grep -qE '^\s*-\s*\[ \]'; then
    if [[ -z "$CURRENT_TASK" ]]; then
      CURRENT_TASK=$(echo "$line" | sed 's/^[[:space:]]*-[[:space:]]*\[ \][[:space:]]*//')
    fi
  fi
done < "$TASKS_FILE"

# 進捗率計算
PROGRESS=0
if [[ "$TOTAL" -gt 0 ]]; then
  PROGRESS=$(( (COMPLETED * 100) / TOTAL )) || PROGRESS=0
fi

STATUS="in_progress"
if [[ "$PROGRESS" -eq 100 ]]; then
  STATUS="completed"
fi

# --- 変更ファイル一覧 ---
CHANGED_FILES=""
if command -v jj >/dev/null 2>&1 && [ -d ".jj" ]; then
  CHANGED_FILES=$(jj diff --stat 2>/dev/null | grep -E '^\s' | awk '{print $1}' | head -20)
elif command -v git >/dev/null 2>&1 && [ -d ".git" ]; then
  CHANGED_FILES=$(git diff --name-only HEAD 2>/dev/null | head -20)
fi

# --- 直近のコミット ---
RECENT_COMMITS=""
if command -v jj >/dev/null 2>&1 && [ -d ".jj" ]; then
  RECENT_COMMITS=$(jj log --no-graph -r 'heads(trunk()..@)' -T 'description.first_line() ++ "\n"' 2>/dev/null | head -5)
elif command -v git >/dev/null 2>&1 && [ -d ".git" ]; then
  RECENT_COMMITS=$(git log --oneline -5 2>/dev/null)
fi

# --- HANDOVER.md 生成 ---
{
  echo "# Session Handover"
  echo "> Generated: $(date '+%Y-%m-%d %H:%M') (auto)"
  echo ""
  echo "## 作業サマリー"
  echo "- ステータス: ${STATUS}"
  echo "- 進捗: ${COMPLETED}/${TOTAL} タスク完了 (${PROGRESS}%)"
  if [[ -n "$CURRENT_PHASE" ]]; then
    echo "- 現在のフェーズ: ${CURRENT_PHASE}"
  fi
  if [[ -n "$CURRENT_TASK" ]]; then
    echo "- 次のタスク: ${CURRENT_TASK}"
  fi

  if [[ -n "$CHANGED_FILES" ]]; then
    echo ""
    echo "## 重要ファイルマップ"
    echo "| ファイル | 役割 | 状態 |"
    echo "|----------|------|------|"
    echo "$CHANGED_FILES" | while IFS= read -r f; do
      [[ -n "$f" ]] && echo "| \`${f}\` | 変更あり | 作業中 |"
    done
  fi

  if [[ -n "$RECENT_COMMITS" ]]; then
    echo ""
    echo "## 直近のコミット"
    echo "$RECENT_COMMITS" | while IFS= read -r c; do
      [[ -n "$c" ]] && echo "- ${c}"
    done
  fi

  echo ""
  echo "## ネクストステップ"
  if [[ -n "$CURRENT_TASK" ]]; then
    echo "1. ${CURRENT_TASK}"
  else
    echo "1. tasks.md を確認して次のタスクを開始"
  fi

  echo ""
  echo "## 次のセッションへの申し送り"
  echo "(自動生成のため詳細なし。リッチな引き継ぎには \`/o-m-cc:handover\` を使用してください)"
} > "$HANDOVER_FILE"

exit 0
