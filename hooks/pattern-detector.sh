#!/bin/bash
# Pattern Detector - 重複パターン検出 hook
# PostToolUse (Write|Edit) で実行
# learned/ への書き込みを検知し、同一タグの重複を検出して promote 提案を注入

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  log_debug() { :; }
  log_error() { echo "❌ $1" >&2; }
fi

LEARNED_DIR="spec/standards/learned"

# learned/ が存在しなければスキップ
if [[ ! -d "$LEARNED_DIR" ]]; then
  exit 0
fi

# Read hook input from stdin
HOOK_INPUT=$(cat)

# tool_input.file_path を取得
FILE_PATH=$(echo "$HOOK_INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

log_debug "pattern-detector: file_path=$FILE_PATH"

# learned/ 以外のファイルは即スキップ
if [[ "$FILE_PATH" != *"spec/standards/learned/"* ]]; then
  exit 0
fi

# README.md への書き込みはスキップ
if [[ "$FILE_PATH" == *"/README.md" ]]; then
  exit 0
fi

# 書き込み内容から **タグ**: 行を抽出
# Write の場合は tool_input.content、Edit の場合は tool_input.new_string
CONTENT=$(echo "$HOOK_INPUT" | jq -r '.tool_input.content // .tool_input.new_string // ""' 2>/dev/null || echo "")

if [[ -z "$CONTENT" ]]; then
  exit 0
fi

# タグを抽出（**タグ**: value の形式）
TAGS=$(echo "$CONTENT" | grep -oP '(?<=\*\*タグ\*\*:\s).*' 2>/dev/null || echo "")

if [[ -z "$TAGS" ]]; then
  exit 0
fi

log_debug "pattern-detector: tags=$TAGS"

# タグをカンマ区切りで分割し、各タグで重複チェック
DUPLICATE_TAGS=()
DUPLICATE_COUNTS=()

# タグ文字列からキーワードを抽出（カンマ区切り、空白トリム）
IFS=',' read -ra TAG_ARRAY <<< "$TAGS"

for tag in "${TAG_ARRAY[@]}"; do
  tag=$(echo "$tag" | xargs)  # 空白トリム
  [[ -z "$tag" ]] && continue
  [[ "$tag" == "review-discovered" ]] && continue  # メタタグはスキップ

  # learned/ 内の全ファイルでタグの出現回数をカウント
  COUNT=0
  COUNT=$(grep -rl "$tag" "$LEARNED_DIR"/ 2>/dev/null | grep -v README.md | wc -l || echo "0")
  COUNT=$((COUNT + 0))  # 数値化

  log_debug "pattern-detector: tag=$tag count=$COUNT"

  # 2回以上出現 = 重複（今回の書き込みを含むため2以上）
  if [[ "$COUNT" -ge 2 ]]; then
    DUPLICATE_TAGS+=("$tag")
    DUPLICATE_COUNTS+=("$COUNT")
  fi
done

# 重複なし → exit 0
if [[ ${#DUPLICATE_TAGS[@]} -eq 0 ]]; then
  exit 0
fi

# 重複あり → systemMessage で promote 提案を注入
TAGS_INFO=""
for i in "${!DUPLICATE_TAGS[@]}"; do
  if [[ -n "$TAGS_INFO" ]]; then
    TAGS_INFO+=", "
  fi
  TAGS_INFO+="${DUPLICATE_TAGS[$i]}(${DUPLICATE_COUNTS[$i]}回)"
done

log_debug "pattern-detector: duplicates found: $TAGS_INFO"

jq -n --arg tags "$TAGS_INFO" '{
  "systemMessage": ("🔁 重複パターン検出: " + $tags + " — `/o-m-cc:promote` でスキル昇格を検討してください。")
}'

exit 0
