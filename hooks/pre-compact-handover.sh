#!/bin/bash
# PreCompact hook: compaction 前に失われる文脈を .claude/context.md に退避
# 3層アーキテクチャ:
#   .claude/context.md        — 最新1スナップショット（常にロード）
#   .claude/chronicle.md      — 直近30エントリ（SessionStart で概要表示）
#   .claude/context-archive.md — 全量（読み込まない、VCS で参照）
set -euo pipefail

# CTA ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/cta.sh" ]]; then
  # shellcheck source=lib/cta.sh
  source "${SCRIPT_DIR}/lib/cta.sh"
fi

HOOK_INPUT=$(cat)
TRIGGER=$(echo "$HOOK_INPUT" | jq -r '.trigger // "unknown"')
TRANSCRIPT_PATH=$(echo "$HOOK_INPUT" | jq -r '.transcript_path // empty')

# transcript がなければスキップ
if [[ -z "$TRANSCRIPT_PATH" ]] || [[ ! -f "$TRANSCRIPT_PATH" ]]; then
  exit 0
fi

CONTEXT_FILE=".claude/context.md"
CHRONICLE_FILE=".claude/chronicle.md"
ARCHIVE_FILE=".claude/context-archive.md"
TIMESTAMP=$(date '+%m/%d %H:%M')
MAX_CHRONICLE=30

# --- ディレクトリ確保 ---
mkdir -p .claude

# --- chronicle.md 初期化 ---
if [[ ! -f "$CHRONICLE_FILE" ]]; then
  cat > "$CHRONICLE_FILE" << 'HEADER'
# Chronicle

> context.md のスナップショットを1行に圧縮して蓄積。直近30件を保持。
> 超過分は .claude/context-archive.md に退避（VCS で参照可能）。

HEADER
fi

# --- 1. 既存 Snapshot を chronicle に退避 ---
if [[ -f "$CONTEXT_FILE" ]] && grep -q '^### Snapshot' "$CONTEXT_FILE" 2>/dev/null; then
  SNAP_META=$(grep '^### Snapshot' "$CONTEXT_FILE" | head -1 | sed 's/### Snapshot (\(.*\))/\1/')
  SNAP_INTENT=$(grep '^\*\*Intent:\*\*' "$CONTEXT_FILE" | head -1 | sed 's/\*\*Intent:\*\* //' | cut -c1-80)

  if [[ -n "$SNAP_META" ]] && [[ -n "$SNAP_INTENT" ]]; then
    ENTRY="- [${SNAP_META}] ${SNAP_INTENT}"
    # chronicle.md の先頭（ヘッダーの後）に挿入
    # ヘッダー部分と既存エントリを分離して再構築（空行の有無に依存しない）
    TEMP_FILE=$(mktemp)
    sed '/^- \[/,$d' "$CHRONICLE_FILE" > "$TEMP_FILE"
    echo "$ENTRY" >> "$TEMP_FILE"
    grep '^- \[' "$CHRONICLE_FILE" >> "$TEMP_FILE" || true
    mv "$TEMP_FILE" "$CHRONICLE_FILE"
  fi
fi

# --- 2. chronicle ローテーション → archive ---
CHRONICLE_COUNT=$(grep -c '^- \[' "$CHRONICLE_FILE" 2>/dev/null || true)
CHRONICLE_COUNT=${CHRONICLE_COUNT:-0}

if [[ "$CHRONICLE_COUNT" -gt "$MAX_CHRONICLE" ]]; then
  EXCESS=$((CHRONICLE_COUNT - MAX_CHRONICLE))

  # archive ファイル初期化
  if [[ ! -f "$ARCHIVE_FILE" ]]; then
    cat > "$ARCHIVE_FILE" << 'HEADER'
# Context Archive

> chronicle.md から溢れたエントリの保管庫。時系列順（古い→新しい）。
> 通常は読み込まない。VCS で参照可能。

HEADER
  fi

  # 超過分（末尾の古いエントリ）を archive に追記
  grep '^- \[' "$CHRONICLE_FILE" | tail -"$EXCESS" >> "$ARCHIVE_FILE"

  # chronicle から超過分を削除（末尾の古いエントリを削除）
  TEMP_FILE=$(mktemp)
  awk -v keep="$MAX_CHRONICLE" '
    /^- \[/ { count++ }
    /^- \[/ && count > keep { next }
    { print }
  ' "$CHRONICLE_FILE" > "$TEMP_FILE"
  mv "$TEMP_FILE" "$CHRONICLE_FILE"
fi

# --- 3. 抽出 ---

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

# --- 4. context.md を新しい Snapshot で上書き ---
cat > "$CONTEXT_FILE" << EOF
# Context

> compaction で失われる文脈を保存。compaction summary と合わせて復元に使用。
> Learnings に長期的価値があれば MEMORY.md に反映すること。

### Snapshot ($TIMESTAMP, $TRIGGER)

**Intent:** $INTENT

EOF

if [[ -n "$CHANGED_FILES" ]] && [[ "$FILE_COUNT" -gt 0 ]]; then
  {
    echo "**Outcomes:** $FILE_COUNT files changed"
    echo "$CHANGED_FILES" | while IFS= read -r f; do
      [[ -n "$f" ]] && echo "- \`$f\`"
    done
    echo ""
  } >> "$CONTEXT_FILE"
fi

{
  echo "**Context:**"
  echo ""
  echo "$LAST_CONTEXT"
} >> "$CONTEXT_FILE"

echo "📝 .claude/context.md updated（chronicle: ${CHRONICLE_COUNT} entries）"
emit_cta "Read .claude/context.md" "Learnings があれば MEMORY.md に反映"
exit 0
