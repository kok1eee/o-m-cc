#!/bin/bash
# o-m-cc エージェント Memory ダイジェスト
# SessionStart で実行し、サブエージェントの学びをメインセッションに表示
# memory ファイルがなければ何も出力せず終了

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true

# Read hook input
HOOK_INPUT=$(cat)

# サブエージェント memory ディレクトリ
AGENT_MEMORY_DIR=".claude/agent-memory"

# memory ファイルを収集
MEMORY_FILES=()

if [[ -d "$AGENT_MEMORY_DIR" ]]; then
  while IFS= read -r -d '' f; do
    MEMORY_FILES+=("$f")
  done < <(find "$AGENT_MEMORY_DIR" -name "MEMORY.md" -print0 2>/dev/null)
fi

# memory がなければ何も表示しない
if [[ ${#MEMORY_FILES[@]} -eq 0 ]]; then
  exit 0
fi

# ダイジェスト出力
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧠 エージェント Memory ダイジェスト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

for f in "${MEMORY_FILES[@]}"; do
  # エージェント名を抽出 (o-m-cc-code-reviewer → code-reviewer)
  agent_dir=$(basename "$(dirname "$f")")
  agent_name="${agent_dir#o-m-cc-}"

  # ファイルの行数
  line_count=$(wc -l < "$f" 2>/dev/null | tr -d ' ')

  # 最終更新日
  mtime=$(get_file_mtime "$f" 2>/dev/null || echo "0")
  if [[ "$mtime" != "0" ]]; then
    case "$(detect_os 2>/dev/null || echo "unknown")" in
      macos) last_modified=$(date -r "$mtime" '+%m/%d %H:%M') ;;
      linux) last_modified=$(date -d "@$mtime" '+%m/%d %H:%M') ;;
      *) last_modified="--" ;;
    esac
  else
    last_modified="--"
  fi

  echo "  📋 ${agent_name} (${line_count}行, 更新: ${last_modified})"

  # ## ヘッダー行を最大5つ抽出してトピック一覧を表示
  grep -m 5 '^## ' "$f" 2>/dev/null | while IFS= read -r line; do
    echo "     ${line}"
  done
  echo ""
done

echo "詳細は .claude/agent-memory/<agent>/MEMORY.md を Read してください。"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
