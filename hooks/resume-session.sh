#!/bin/bash
# o-m-cc: Resume session from HANDOVER.md on session start

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

HANDOVER_FILE="plan/HANDOVER.md"

# ファイルの鮮度チェック（max_days 以内か）
check_file_age() {
  local file="$1"
  local max_days="${2:-7}"
  local file_mtime
  file_mtime=$(get_file_mtime "$file")
  file_mtime=$(( file_mtime + 0 ))  # 数値化
  local current_time
  current_time=$(date +%s)
  local file_age_days=$(( (current_time - file_mtime) / 86400 ))
  [[ $file_age_days -le $max_days ]]
}

# --- HANDOVER.md（リッチ引き継ぎ書）を優先チェック ---
# 意思決定ログや教訓は長期間有効なため 30 日
if [[ -f "$HANDOVER_FILE" ]] && check_file_age "$HANDOVER_FILE" 30; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "📝 前回の引き継ぎ書あり (plan/HANDOVER.md)"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""

  # 作業サマリーセクションを抽出して表示
  if grep -q "## 作業サマリー" "$HANDOVER_FILE" 2>/dev/null; then
    echo "【作業サマリー】"
    sed -n '/^## 作業サマリー/,/^## /p' "$HANDOVER_FILE" | grep -E '^\s*-' | head -5
    echo ""
  fi

  # ネクストステップを抽出して表示
  if grep -q "## ネクストステップ" "$HANDOVER_FILE" 2>/dev/null; then
    echo "【ネクストステップ】"
    sed -n '/^## ネクストステップ/,/^## /p' "$HANDOVER_FILE" | grep -E '^\s*[0-9]+\.' | head -5
    echo ""
  fi

  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "💡 詳細: plan/HANDOVER.md を読んでください"
  echo "💡 続行: 作業内容を説明してください"
  echo "💡 リセット: /clear"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  exit 0
fi

# HANDOVER.md が見つからない場合
log_debug "HANDOVER.md が見つかりません、スキップ"
exit 0
