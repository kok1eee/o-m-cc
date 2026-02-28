#!/bin/bash
# PreCompact hook: compaction 前に session state を HANDOVER.md に退避
set -euo pipefail

HOOK_INPUT=$(cat)
TRIGGER=$(echo "$HOOK_INPUT" | jq -r '.trigger // "unknown"')
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')

# transcript がなければスキップ
if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

HANDOVER_FILE="HANDOVER.md"

# 1. 最初の実質的なユーザーメッセージ（≒ 目標）を抽出
# セッション再開メッセージ等を除外し、最初の意味のあるメッセージを取得
FIRST_USER_MSG=$(grep '"role":"user"' "$TRANSCRIPT_PATH" | \
  jq -r '.message.content | if type == "array" then map(select(.type == "text")) | map(.text) | join(" ") else . end' 2>/dev/null | \
  grep -v '^\[Request interrupted' | grep -v '^$' | sed -n '1p' | \
  cut -c1-500 || echo "(抽出失敗)")

# 2. 変更ファイル一覧（Write/Edit ツール使用から抽出）
CHANGED_FILES=$(grep '"tool_use"' "$TRANSCRIPT_PATH" | \
  jq -r 'select(.message.content[]?.name == "Write" or .message.content[]?.name == "Edit") | .message.content[] | select(.type == "tool_use") | .input.file_path // empty' 2>/dev/null | \
  sort -u | head -20 || echo "")

# 3. 最後のテキストを含むアシスタントメッセージ（≒ 現在の状態）
# tool_use のみのメッセージをスキップし、テキストを含む最後のメッセージを取得
LAST_ASSISTANT=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | \
  jq -r 'select(.message.content | map(select(.type == "text")) | length > 0) | .message.content | map(select(.type == "text")) | map(.text) | join("\n")' 2>/dev/null | \
  tail -c 1000 || echo "(抽出失敗)")

# 4. HANDOVER.md 生成
cat > "$HANDOVER_FILE" << 'HEADER'
# Session Handover

> このファイルは PreCompact hook により自動生成されました。
> セッション状態の引き継ぎ用です。次のセッション開始時に読み込まれます。

HEADER

echo "## 目標" >> "$HANDOVER_FILE"
echo "" >> "$HANDOVER_FILE"
echo "$FIRST_USER_MSG" >> "$HANDOVER_FILE"
echo "" >> "$HANDOVER_FILE"

if [[ -n "$CHANGED_FILES" ]]; then
  echo "## 変更ファイル" >> "$HANDOVER_FILE"
  echo "" >> "$HANDOVER_FILE"
  echo "$CHANGED_FILES" | while IFS= read -r f; do
    [[ -n "$f" ]] && echo "- \`$f\`" >> "$HANDOVER_FILE"
  done
  echo "" >> "$HANDOVER_FILE"
fi

echo "## 最後のコンテキスト" >> "$HANDOVER_FILE"
echo "" >> "$HANDOVER_FILE"
echo "$LAST_ASSISTANT" >> "$HANDOVER_FILE"
echo "" >> "$HANDOVER_FILE"

echo "📝 Session state → HANDOVER.md（compaction 前に自動保存）"
exit 0
