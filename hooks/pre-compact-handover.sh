#!/bin/bash
# PreCompact hook: compaction 前に失われる文脈を CONTEXT.md に退避
# 蓄積型: スナップショットが CONSOLIDATE_THRESHOLD に達するとダイジェストに統合
# Chronicle は MAX_CHRONICLE でローテーション（古い履歴は VCS で参照）
set -euo pipefail

HOOK_INPUT=$(cat)
TRIGGER=$(echo "$HOOK_INPUT" | jq -r '.trigger // "unknown"')
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')

# transcript がなければスキップ
if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

CONTEXT_FILE="CONTEXT.md"
TIMESTAMP=$(date '+%m/%d %H:%M')
CONSOLIDATE_THRESHOLD=5
MAX_CHRONICLE=30

# --- 初期化 ---
if [[ ! -f "$CONTEXT_FILE" ]]; then
  cat > "$CONTEXT_FILE" << 'HEADER'
# Context

> compaction で失われる文脈を保存。compaction summary と合わせて復元に使用。
> このファイルを読んだら、Learnings に長期的価値があれば MEMORY.md に反映すること。

## Chronicle

HEADER
fi

# --- 抽出 ---

# Intent: 最初の実質的なユーザーメッセージ
INTENT=$(grep '"role":"user"' "$TRANSCRIPT_PATH" | \
  jq -r '.message.content | if type == "array" then map(select(.type == "text")) | map(.text) | join(" ") else . end' 2>/dev/null | \
  grep -v '^\[Request interrupted' | grep -v '^$' | sed -n '1p' | \
  cut -c1-200 || echo "(抽出失敗)")

# Outcomes: 変更ファイル一覧
CHANGED_FILES=$(grep '"tool_use"' "$TRANSCRIPT_PATH" | \
  jq -r 'select(.message.content[]?.name == "Write" or .message.content[]?.name == "Edit") | .message.content[] | select(.type == "tool_use") | .input.file_path // empty' 2>/dev/null | \
  sort -u | head -15 || echo "")
FILE_COUNT=$(echo "$CHANGED_FILES" | grep -c '[^[:space:]]' || true)
FILE_COUNT=${FILE_COUNT:-0}

# Context: 最後のテキストを含むアシスタントメッセージ
LAST_CONTEXT=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | \
  jq -r 'select(.message.content | map(select(.type == "text")) | length > 0) | .message.content | map(select(.type == "text")) | map(.text) | join("\n")' 2>/dev/null | \
  tail -c 500 || echo "(抽出失敗)")

# --- 統合チェック ---
CURRENT_SNAPSHOTS=$(grep -c '^### Snapshot' "$CONTEXT_FILE" 2>/dev/null || true)
CURRENT_SNAPSHOTS=${CURRENT_SNAPSHOTS:-0}

if [[ "$CURRENT_SNAPSHOTS" -ge "$CONSOLIDATE_THRESHOLD" ]]; then
  DIGEST_ENTRIES=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^###\ Snapshot\ \((.+)\) ]]; then
      SNAP_TIME="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\*\*Intent:\*\*\ (.+) ]]; then
      SNAP_INTENT="${BASH_REMATCH[1]}"
      SNAP_INTENT_SHORT=$(echo "$SNAP_INTENT" | cut -c1-80)
      DIGEST_ENTRIES="${DIGEST_ENTRIES}- [${SNAP_TIME}] ${SNAP_INTENT_SHORT}
"
    fi
  done < "$CONTEXT_FILE"

  if [[ -n "$DIGEST_ENTRIES" ]]; then
    TEMP_FILE=$(mktemp)
    awk '
      /^### Snapshot/ { skip=1; next }
      /^---$/ && skip { skip=0; next }
      skip { next }
      { print }
    ' "$CONTEXT_FILE" | sed '/^$/N;/^\n$/d' > "$TEMP_FILE"

    printf "%s\n" "$DIGEST_ENTRIES" >> "$TEMP_FILE"
    mv "$TEMP_FILE" "$CONTEXT_FILE"
    CURRENT_SNAPSHOTS=0
  fi
fi

# --- Chronicle ローテーション ---
# MAX_CHRONICLE を超えたら古いエントリを削除（VCS に履歴は残る）
CHRONICLE_COUNT=$(grep -c '^- \[' "$CONTEXT_FILE" 2>/dev/null || true)
CHRONICLE_COUNT=${CHRONICLE_COUNT:-0}
if [[ "$CHRONICLE_COUNT" -gt "$MAX_CHRONICLE" ]]; then
  EXCESS=$((CHRONICLE_COUNT - MAX_CHRONICLE))
  TEMP_FILE=$(mktemp)
  awk -v excess="$EXCESS" '
    /^- \[/ { count++; if (count <= excess) next }
    { print }
  ' "$CONTEXT_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$CONTEXT_FILE"
fi

# --- スナップショット追記 ---
{
  echo "### Snapshot ($TIMESTAMP, $TRIGGER)"
  echo ""
  echo "**Intent:** $INTENT"
  echo ""

  if [[ -n "$CHANGED_FILES" ]] && [[ "$FILE_COUNT" -gt 0 ]]; then
    echo "**Outcomes:** $FILE_COUNT files changed"
    echo "$CHANGED_FILES" | while IFS= read -r f; do
      [[ -n "$f" ]] && echo "- \`$f\`"
    done
    echo ""
  fi

  echo "**Context:**"
  echo ""
  echo "$LAST_CONTEXT"
  echo ""
  echo "---"
  echo ""
} >> "$CONTEXT_FILE"

echo "📝 CONTEXT.md updated（snapshot #$((CURRENT_SNAPSHOTS + 1)), chronicle: $((CHRONICLE_COUNT)) entries）"
echo "💡 CONTEXT.md を Read して、Learnings があれば MEMORY.md に反映してください"
exit 0
