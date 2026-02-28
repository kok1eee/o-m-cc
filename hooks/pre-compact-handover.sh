#!/bin/bash
# PreCompact hook: compaction 前に session state を HANDOVER.md に退避
# セッション内では蓄積型（追記）。セッション開始時にクリアされる前提。
set -euo pipefail

HOOK_INPUT=$(cat)
TRIGGER=$(echo "$HOOK_INPUT" | jq -r '.trigger // "unknown"')
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')
SESSION_ID=$(echo "$HOOK_INPUT" | jq -r '.session_id // "unknown"')

# transcript がなければスキップ
if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

HANDOVER_FILE="HANDOVER.md"
TIMESTAMP=$(date '+%H:%M')
MAX_SNAPSHOTS=10

# --- 蓄積ロジック ---
# 既存の HANDOVER.md がなければヘッダーを作成
if [[ ! -f "$HANDOVER_FILE" ]]; then
  cat > "$HANDOVER_FILE" << 'HEADER'
# Session Handover

> このファイルは PreCompact hook により自動生成されました。
> compaction のたびにスナップショットが追記されます。
> compaction summary と合わせて文脈復元に使用してください。

HEADER
fi

# スナップショット数チェック（MAX_SNAPSHOTS を超えたら古いものを削除）
CURRENT_SNAPSHOTS=$(grep -c '^### Snapshot' "$HANDOVER_FILE" 2>/dev/null || true)
CURRENT_SNAPSHOTS=${CURRENT_SNAPSHOTS:-0}
if [[ "$CURRENT_SNAPSHOTS" -ge "$MAX_SNAPSHOTS" ]]; then
  # 最初のスナップショットを削除（ヘッダーは残す）
  # ヘッダー終了位置（最初の ### Snapshot）から次の ### Snapshot までを削除
  sed -i '' '/^### Snapshot/{N;:a;/\n### Snapshot/!{N;ba};s/^[^\n]*\n//;}' "$HANDOVER_FILE" 2>/dev/null || true
fi

# --- 抽出 ---

# 1. 最初の実質的なユーザーメッセージ（≒ 目標）
FIRST_USER_MSG=$(grep '"role":"user"' "$TRANSCRIPT_PATH" | \
  jq -r '.message.content | if type == "array" then map(select(.type == "text")) | map(.text) | join(" ") else . end' 2>/dev/null | \
  grep -v '^\[Request interrupted' | grep -v '^$' | sed -n '1p' | \
  cut -c1-300 || echo "(抽出失敗)")

# 2. 変更ファイル一覧（Write/Edit ツール使用から抽出）
CHANGED_FILES=$(grep '"tool_use"' "$TRANSCRIPT_PATH" | \
  jq -r 'select(.message.content[]?.name == "Write" or .message.content[]?.name == "Edit") | .message.content[] | select(.type == "tool_use") | .input.file_path // empty' 2>/dev/null | \
  sort -u | head -15 || echo "")

# 3. 最後のテキストを含むアシスタントメッセージ（≒ 現在の状態）
LAST_ASSISTANT=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | \
  jq -r 'select(.message.content | map(select(.type == "text")) | length > 0) | .message.content | map(select(.type == "text")) | map(.text) | join("\n")' 2>/dev/null | \
  tail -c 500 || echo "(抽出失敗)")

# --- スナップショット追記 ---

{
  echo "### Snapshot ($TIMESTAMP, $TRIGGER)"
  echo ""

  echo "**目標:** $FIRST_USER_MSG"
  echo ""

  if [[ -n "$CHANGED_FILES" ]]; then
    echo "**変更ファイル:**"
    echo "$CHANGED_FILES" | while IFS= read -r f; do
      [[ -n "$f" ]] && echo "- \`$f\`"
    done
    echo ""
  fi

  echo "**最後のコンテキスト:**"
  echo ""
  echo "$LAST_ASSISTANT"
  echo ""
  echo "---"
  echo ""
} >> "$HANDOVER_FILE"

echo "📝 Session state → HANDOVER.md（snapshot #$((CURRENT_SNAPSHOTS + 1)) 追記）"
exit 0
