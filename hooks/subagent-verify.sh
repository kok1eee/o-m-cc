#!/bin/bash
# SubagentStop: サブエージェント完了時の軽量品質チェック。
# ブロックしない（常に exit 0）。問題を検出したら hookSpecificOutput.additionalContext で
# Claude にフィードバックする（v2.1.163+）。
#
# 旧実装は警告を stderr に出していたが、SubagentStop hook が exit 0 のとき stderr は
# user に見えるだけで Claude には届かない＝再 spawn できる立場の Claude が検出結果を
# 受け取れず Sensor が機能していなかった。additionalContext なら actionable feedback として
# Claude に渡り、turn も継続する（hook error 扱いされない）。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true

# Headless モードではスキップ
if is_headless; then
  cat > /dev/null
  exit 0
fi

HOOK_INPUT=$(cat)

if ! check_command jq; then
  exit 0
fi

# サブエージェントの情報取得
AGENT_TYPE=$(echo "$HOOK_INPUT" | jq -r '.agent_type // empty' 2>/dev/null || echo "")
LAST_MSG=$(echo "$HOOK_INPUT" | jq -r '.last_assistant_message // empty' 2>/dev/null || echo "")

# メインエージェントはスキップ（Stop hook の管轄）
if [[ -z "$AGENT_TYPE" || "$AGENT_TYPE" == "main" ]]; then
  exit 0
fi

# --- 軽量チェック: 検出した警告を WARNINGS に貯める ---
WARNINGS=()

# 1. エラーパターンの検出
if echo "$LAST_MSG" | grep -qiE 'Error:|FAILED|panic:|Traceback|CRITICAL' 2>/dev/null; then
  WARNINGS+=("出力にエラーパターン（Error/FAILED/panic/Traceback/CRITICAL）を検出")
fi

# 2. 極端に短い出力の警告
#    （系統A = 応答ストリーミング異常で空 thinking + tool_use 欠落になると、
#     subagent 出力が極端に短い/壊れた形で現れる。その検出も兼ねる）
MSG_LEN=${#LAST_MSG}
if [[ $MSG_LEN -lt 20 && $MSG_LEN -gt 0 ]]; then
  WARNINGS+=("出力が極端に短い（${MSG_LEN}文字）。応答ストリーミング異常（空 thinking / tool_use 欠落）の可能性")
fi

# 警告が無ければ何も出さない（exit 0 = サイレント）
if [[ ${#WARNINGS[@]} -eq 0 ]]; then
  exit 0
fi

# additionalContext で Claude にフィードバック（turn 継続・hook error 扱いされない）
CONTEXT="⚠️ [o-m-cc subagent-verify] サブエージェント '${AGENT_TYPE}' の出力に問題の兆候:"
for w in "${WARNINGS[@]}"; do
  CONTEXT="${CONTEXT}"$'\n'"  - ${w}"
done
CONTEXT="${CONTEXT}"$'\n'"→ この結果を鵜呑みにせず、必要なら subagent を再 spawn するか出力を検証してください。"

jq -cn --arg ctx "$CONTEXT" \
  '{hookSpecificOutput: {hookEventName: "SubagentStop", additionalContext: $ctx}}'
exit 0
