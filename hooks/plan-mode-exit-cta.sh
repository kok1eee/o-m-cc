#!/bin/bash
# PostToolUse(ExitPlanMode): plan 完了時に /o-m-cc:sisyphus で実装を促す CTA
# stderr に出力 → Claude が次ターンで判断
set -euo pipefail

HOOK_INPUT=$(cat)

# ExitPlanMode の plan_file_path を取得（Claude Code built-in plan file）
PLAN_FILE=$(echo "$HOOK_INPUT" | jq -r '.tool_response.plan_file_path // empty' 2>/dev/null)

# plan が存在しないなら何もしない
if [[ -z "$PLAN_FILE" ]] || [[ ! -f "$PLAN_FILE" ]]; then
  exit 0
fi

PLAN_LINES=$(wc -l < "$PLAN_FILE" 2>/dev/null | tr -d ' ')
PLAN_LINES=${PLAN_LINES:-0}

# 小さすぎる plan（5行未満）は CTA 不要
if [[ "$PLAN_LINES" -lt 5 ]]; then
  exit 0
fi

# 既に o-m-cc の plan/ ドキュメントがある場合は、sisyphus が既に動いている可能性
# （二重実行を避けるため CTA 省略）
if [[ -f "plan/requirements.md" ]] && [[ -f "plan/design.md" ]]; then
  exit 0
fi

echo "" >&2
echo "📋 Plan が作成されました (${PLAN_LINES} 行)。" >&2
echo "   実装は Skill ツールで /o-m-cc:sisyphus を起動すると、" >&2
echo "   要件→設計→タスク分解→実装→品質ゲートまで自動で進みます。" >&2
echo "" >&2

exit 0
