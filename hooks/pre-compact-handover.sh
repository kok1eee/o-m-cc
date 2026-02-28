#!/bin/bash
# PreCompact hook: compaction 前に session state を HANDOVER.md に退避
# 蓄積型: スナップショットが CONSOLIDATE_THRESHOLD に達するとダイジェストに統合
set -euo pipefail

HOOK_INPUT=$(cat)
TRIGGER=$(echo "$HOOK_INPUT" | jq -r '.trigger // "unknown"')
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')

# transcript がなければスキップ
if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

HANDOVER_FILE="HANDOVER.md"
TIMESTAMP=$(date '+%m/%d %H:%M')
CONSOLIDATE_THRESHOLD=5

# --- 初期化 ---
if [[ ! -f "$HANDOVER_FILE" ]]; then
  cat > "$HANDOVER_FILE" << 'HEADER'
# Session Handover

> PreCompact hook により自動生成。compaction summary と合わせて文脈復元に使用。

## これまでの経緯

HEADER
fi

# --- 抽出 ---

# 1. 最初の実質的なユーザーメッセージ（≒ 目標）
FIRST_USER_MSG=$(grep '"role":"user"' "$TRANSCRIPT_PATH" | \
  jq -r '.message.content | if type == "array" then map(select(.type == "text")) | map(.text) | join(" ") else . end' 2>/dev/null | \
  grep -v '^\[Request interrupted' | grep -v '^$' | sed -n '1p' | \
  cut -c1-200 || echo "(抽出失敗)")

# 2. 変更ファイル一覧（Write/Edit ツール使用から抽出）
CHANGED_FILES=$(grep '"tool_use"' "$TRANSCRIPT_PATH" | \
  jq -r 'select(.message.content[]?.name == "Write" or .message.content[]?.name == "Edit") | .message.content[] | select(.type == "tool_use") | .input.file_path // empty' 2>/dev/null | \
  sort -u | head -15 || echo "")
FILE_COUNT=$(echo "$CHANGED_FILES" | grep -c '[^[:space:]]' || true)
FILE_COUNT=${FILE_COUNT:-0}

# 3. 最後のテキストを含むアシスタントメッセージ（≒ 現在の状態）
LAST_ASSISTANT=$(grep '"role":"assistant"' "$TRANSCRIPT_PATH" | \
  jq -r 'select(.message.content | map(select(.type == "text")) | length > 0) | .message.content | map(select(.type == "text")) | map(.text) | join("\n")' 2>/dev/null | \
  tail -c 500 || echo "(抽出失敗)")

# --- 統合チェック ---
# スナップショットが閾値に達したらダイジェストに統合
CURRENT_SNAPSHOTS=$(grep -c '^### Snapshot' "$HANDOVER_FILE" 2>/dev/null || true)
CURRENT_SNAPSHOTS=${CURRENT_SNAPSHOTS:-0}

if [[ "$CURRENT_SNAPSHOTS" -ge "$CONSOLIDATE_THRESHOLD" ]]; then
  # 各スナップショットの「目標」を1行に圧縮してダイジェストに追記
  # Snapshot ブロックから目標行とタイムスタンプを抽出
  DIGEST_ENTRIES=""
  while IFS= read -r line; do
    if [[ "$line" =~ ^###\ Snapshot\ \((.+)\) ]]; then
      SNAP_TIME="${BASH_REMATCH[1]}"
    elif [[ "$line" =~ ^\*\*目標:\*\*\ (.+) ]]; then
      SNAP_GOAL="${BASH_REMATCH[1]}"
      # ファイル数を次の行群からカウント
      SNAP_GOAL_SHORT=$(echo "$SNAP_GOAL" | cut -c1-80)
      DIGEST_ENTRIES="${DIGEST_ENTRIES}- [${SNAP_TIME}] ${SNAP_GOAL_SHORT}
"
    fi
  done < "$HANDOVER_FILE"

  if [[ -n "$DIGEST_ENTRIES" ]]; then
    # 1. スナップショットブロックを全削除したクリーン版を作成
    TEMP_FILE=$(mktemp)
    awk '
      /^### Snapshot/ { skip=1; next }
      /^---$/ && skip { skip=0; next }
      skip { next }
      { print }
    ' "$HANDOVER_FILE" | sed '/^$/N;/^\n$/d' > "$TEMP_FILE"

    # 2. ダイジェストエントリを末尾に追加
    printf "%s\n" "$DIGEST_ENTRIES" >> "$TEMP_FILE"

    mv "$TEMP_FILE" "$HANDOVER_FILE"
    CURRENT_SNAPSHOTS=0
  fi
fi

# --- スナップショット追記 ---
{
  echo "### Snapshot ($TIMESTAMP, $TRIGGER)"
  echo ""
  echo "**目標:** $FIRST_USER_MSG"
  echo ""

  if [[ -n "$CHANGED_FILES" ]] && [[ "$FILE_COUNT" -gt 0 ]]; then
    echo "**変更ファイル ($FILE_COUNT):**"
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

echo "📝 Session state → HANDOVER.md（snapshot #$((CURRENT_SNAPSHOTS + 1))）"
exit 0
