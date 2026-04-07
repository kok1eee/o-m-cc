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
EVENT=$(echo "$HOOK_INPUT" | jq -r '.hook_event_name // "unknown"')
if [[ "$EVENT" == "SessionEnd" ]]; then
  TRIGGER=$(echo "$HOOK_INPUT" | jq -r '.source // "end"')
else
  TRIGGER=$(echo "$HOOK_INPUT" | jq -r '.trigger // "unknown"')
fi
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

# 全ユーザーメッセージを一度だけ抽出（Intent + Next で共有）
# 抽出: jq select でトップレベル user メッセージのみ取得（grep 経由だと nested role:user に誤マッチする）
#       改行をスペースに変換し、メッセージごとに1行にする
# フィルタ: ノイズを除外して「人間の実際の発話」だけを残す
#   - [Request interrupted]: 中断メッセージ
#   - ⏺ を含む行: Claude の出力マーカー（pasted content）
#   - <system-reminder>, <command-name>, <local-command->: システム生成
#   - "This session is being continued": compaction サマリ
#   - "Caveat: The messages below": local command 実行のキャベアット
#   - 10文字未満: 短すぎる（"yes" 等）
#   - 500文字超: 長すぎる（pasted log/changelog 等）
ALL_USER_MSGS=$(jq -r 'select(.type? == "user" and (.message?.content?)) | .message.content | if type == "array" then map(select(.type? == "text")) | map(.text? // "") | join(" ") else . end | gsub("\n"; " ") | gsub("\r"; " ")' "$TRANSCRIPT_PATH" 2>/dev/null | \
  grep -v '^\[Request interrupted' | \
  grep -v '⏺' | \
  grep -v '<system-reminder>' | \
  grep -v '<command-name>' | \
  grep -v '<local-command-' | \
  grep -v 'This session is being continued' | \
  grep -v 'Caveat: The messages below' | \
  awk 'length >= 10 && length <= 500' | \
  grep -v '^$' || true)

# Intent: 最初の実質的なユーザーメッセージ
INTENT=$(echo "$ALL_USER_MSGS" | sed -n '1p' | cut -c1-200)
INTENT=${INTENT:-"(抽出失敗)"}

# Next: セッション終盤のユーザーメッセージ（次の方向性）
LAST_MSGS=$(echo "$ALL_USER_MSGS" | tail -3)
# Intent と完全一致する1行だけなら重複なので空にする
if [[ "$(echo "$LAST_MSGS" | grep -c '[^[:space:]]')" -eq 1 ]]; then
  LAST_FIRST=$(echo "$LAST_MSGS" | head -1 | cut -c1-200)
  [[ "$LAST_FIRST" == "$INTENT" ]] && LAST_MSGS=""
fi

# Changed Files: Write/Edit で変更されたファイル一覧
CHANGED_FILES=$(grep '"tool_use"' "$TRANSCRIPT_PATH" | \
  jq -r 'select(.message.content[]?.name == "Write" or .message.content[]?.name == "Edit") | .message.content[] | select(.type == "tool_use") | .input.file_path // empty' 2>/dev/null | \
  sort -u | head -15 || echo "")
FILE_COUNT=$(echo "$CHANGED_FILES" | grep -c '[^[:space:]]' || true)
FILE_COUNT=${FILE_COUNT:-0}

# --- 4. context.md を新しい Snapshot で上書き ---
# 3セクションのみ: Intent + Outcomes + Changed Files
# 学びは MEMORY.md、タスクは TaskList、設定は CLAUDE.md の責務
cat > "$CONTEXT_FILE" << EOF
# Context

> セッション間の引き継ぎ情報。学びは MEMORY.md、タスクは TaskList、設定は CLAUDE.md。

### Snapshot ($TIMESTAMP, $TRIGGER)

**Intent:** $INTENT

EOF

# Next セクション
if [[ -n "$LAST_MSGS" ]] && echo "$LAST_MSGS" | grep -q '[^[:space:]]'; then
  {
    echo "**Next:**"
    echo "$LAST_MSGS" | while IFS= read -r msg; do
      [[ -n "$msg" ]] && echo "- $(echo "$msg" | cut -c1-120)"
    done
    echo ""
  } >> "$CONTEXT_FILE"
fi

if [[ -n "$CHANGED_FILES" ]] && [[ "$FILE_COUNT" -gt 0 ]]; then
  {
    echo "**Outcomes:** $FILE_COUNT files changed"
    echo ""
    echo "**Changed Files:**"
    echo "$CHANGED_FILES" | while IFS= read -r f; do
      [[ -n "$f" ]] && echo "- \`$f\`"
    done
    echo ""
  } >> "$CONTEXT_FILE"
fi

echo "📝 .claude/context.md updated（chronicle: ${CHRONICLE_COUNT} entries）"

# PreCompact 時のみ: スキル進化の CTA を出す
# SessionEnd では モデルが動けないのでスキップ
if [[ "$EVENT" != "SessionEnd" ]]; then
  EVOLVE_MARKER=".claude/evolve-done"
  if [[ ! -f "$EVOLVE_MARKER" ]]; then
    echo ""
    echo "🧬 Skill ツールで o-m-cc:evolve を実行してください（スキルの自己進化）。" >&2
    exit 2
  fi
fi

exit 0
