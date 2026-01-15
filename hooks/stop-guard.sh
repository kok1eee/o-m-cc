#!/bin/bash
# Sisyphus Stop Guard with Code Review
# DONE検知時にcode-reviewerの結果を確認し、問題があればループ継続

set -euo pipefail

# Read hook input from stdin
HOOK_INPUT=$(cat)

# Get transcript path from hook input
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path' 2>/dev/null || echo "")

if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

# Check if there are any assistant messages
if ! grep -q '"role":"assistant"' "$TRANSCRIPT_PATH" 2>/dev/null; then
  exit 0
fi

# Get last assistant message
LAST_LINE=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | tail -1)
LAST_OUTPUT=$(echo "$LAST_LINE" | jq -r '
  .message.content |
  map(select(.type == "text")) |
  map(.text) |
  join("\n")
' 2>/dev/null || echo "")

# Check for <promise>DONE</promise>
if echo "$LAST_OUTPUT" | grep -q '<promise>DONE</promise>'; then

  # Case 1: Critical issues found - block and require fixes
  if echo "$LAST_OUTPUT" | grep -qiE 'Critical.*あり|🔴.*Critical|必須修正|Critical.*issue|Critical.*problem'; then
    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  🔴 SISYPHUS GUARD: Critical な問題が検出されました"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo "  code-reviewer が Critical な問題を指摘しています。"
    echo "  修正してから再度レビューを実行してください。"
    echo ""
    echo "════════════════════════════════════════════════════════"

    jq -n '{
      "decision": "block",
      "reason": "code-reviewer が Critical な問題を検出しました。問題を修正し、再度 code-reviewer subagent でレビューしてから <promise>DONE</promise> を出力してください。",
      "systemMessage": "🔴 Sisyphus Guard: Critical な問題を修正してください"
    }'
    exit 0
  fi

  # Case 2: Code review completed with no critical issues - allow exit
  if echo "$LAST_OUTPUT" | grep -qiE 'Critical.*なし|Critical.*ありません|🟢|レビュー.*完了.*問題なし|no.*critical|all.*pass'; then
    echo ""
    echo "✅ Sisyphus Guard: code-reviewer完了、Critical なし - 終了を許可"
    exit 0
  fi

  # Case 3: Code review seems done but result unclear
  if echo "$LAST_OUTPUT" | grep -qiE 'code-reviewer|コードレビュー|レビュー結果'; then
    echo ""
    echo "✅ Sisyphus Guard: code-reviewer実行を確認 - 終了を許可"
    exit 0
  fi

  # Case 4: No code review evidence - block and require review
  echo ""
  echo "════════════════════════════════════════════════════════"
  echo "  ⚠️  SISYPHUS GUARD: code-reviewer 未実行"
  echo "════════════════════════════════════════════════════════"
  echo ""
  echo "  <promise>DONE</promise> が検知されましたが、"
  echo "  code-reviewer subagent の実行結果が確認できません。"
  echo ""
  echo "  完了前に以下を実行してください："
  echo "  1. code-reviewer subagent で変更をレビュー"
  echo "  2. Critical な問題がないことを確認"
  echo "  3. 結果を出力してから DONE を宣言"
  echo ""
  echo "════════════════════════════════════════════════════════"

  jq -n '{
    "decision": "block",
    "reason": "code-reviewer subagent で変更をレビューしてください。レビュー結果を出力し、Critical な問題がないことを確認してから <promise>DONE</promise> を出力してください。",
    "systemMessage": "⚠️ Sisyphus Guard: code-reviewer を実行してください"
  }'
  exit 0
fi

# No DONE detected - allow normal exit or let ralph-wiggum handle it
exit 0
