#!/bin/bash
# Auto-suggest code review after N file edits
# PostToolUse (Write|Edit) で実行
# 一定回数の編集後にレビューを提案

set -euo pipefail

COUNTER_FILE="spec/.edit-counter"
REVIEW_THRESHOLD="${SISYPHUS_REVIEW_THRESHOLD:-15}"

# Read hook input
HOOK_INPUT=$(cat)

# カウンターファイルを初期化
if [[ ! -f "$COUNTER_FILE" ]]; then
  mkdir -p "$(dirname "$COUNTER_FILE")"
  echo "0" > "$COUNTER_FILE"
fi

# カウントをインクリメント
CURRENT=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
NEXT=$((CURRENT + 1))
echo "$NEXT" > "$COUNTER_FILE"

# しきい値に達したらリマインダー出力
if [[ $NEXT -eq $REVIEW_THRESHOLD ]]; then
  echo ""
  echo "💡 ${NEXT} ファイル編集済み - code-reviewer の実行を検討してください"
  echo ""
  # リセット（次のしきい値まで黙る）
  echo "0" > "$COUNTER_FILE"
fi

exit 0
