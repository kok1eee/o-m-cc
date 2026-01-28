#!/bin/bash
# o-m-cc: Resume session from handoff.yaml on session start

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  # common.sh がない場合のフォールバック
  get_file_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo "0"; }
  log_debug() { :; }
  log_error() { echo "❌ $1" >&2; }
fi

HANDOFF_FILE="spec/plan/handoff.yaml"

# Skip if no handoff file
if [[ ! -f "$HANDOFF_FILE" ]]; then
  log_debug "handoff.yaml が見つかりません、スキップ"
  exit 0
fi

# Check file age (skip if older than 7 days)
file_mtime=$(get_file_mtime "$HANDOFF_FILE")
file_mtime=$(( file_mtime + 0 ))  # 数値化
current_time=$(date +%s)
file_age_days=$(( (current_time - file_mtime) / 86400 ))

if [[ $file_age_days -gt 7 ]]; then
  log_debug "handoff.yaml が7日以上古いためスキップ"
  exit 0
fi

# Display previous session state
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "📋 前回のセッション情報 (spec/plan/handoff.yaml)"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Extract key information using grep/sed (lightweight parsing)
if grep -q "status:" "$HANDOFF_FILE" 2>/dev/null; then
  status=$(grep "^status:" "$HANDOFF_FILE" | head -1 | sed 's/status: *//' | tr -d '"')
  echo "ステータス: $status"
fi

if grep -q "progress:" "$HANDOFF_FILE" 2>/dev/null; then
  percentage=$(grep "percentage:" "$HANDOFF_FILE" | head -1 | sed 's/.*percentage: *//' | tr -d '"' || echo "")
  [[ -n "$percentage" ]] && echo "進捗: $percentage"
fi

if grep -q "current_task:" "$HANDOFF_FILE" 2>/dev/null; then
  echo ""
  echo "現在のタスク:"
  phase=$(grep -A1 "current_task:" "$HANDOFF_FILE" | grep "phase:" | head -1 | sed 's/.*phase: *//' | tr -d '"' || echo "")
  task=$(grep -A2 "current_task:" "$HANDOFF_FILE" | grep "task:" | head -1 | sed 's/.*task: *//' | tr -d '"' || echo "")
  [[ -n "$phase" ]] && echo "  - フェーズ: $phase"
  [[ -n "$task" ]] && echo "  - タスク: $task"
fi

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "💡 続行: 作業内容を説明してください"
echo "💡 リセット: /clear"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
