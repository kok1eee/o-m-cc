#!/bin/bash
# o-m-cc エージェント Memory ダイジェスト
# SessionStart で実行し、サブエージェントの学びをメインセッションに表示
# memory ファイルがなければ何も出力せず終了

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true

# Headless モード（claude -p）ではスキップ
if is_headless; then
  cat > /dev/null
  exit 0
fi

# Read hook input
HOOK_INPUT=$(cat)

# 肥大化チェック閾値（200行の80%で警告）
MEMORY_WARN_THRESHOLD="${MEMORY_WARN_THRESHOLD:-160}"

# サブエージェント memory ディレクトリ
AGENT_MEMORY_DIR=".claude/agent-memory"

# プロジェクト MEMORY.md の肥大化チェック
# auto-memory パス: ~/.claude/projects/-<escaped-cwd>/memory/MEMORY.md
CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
if [[ -z "$CWD" ]]; then
  CWD="$(pwd)"
fi
PROJECT_MEMORY_KEY="${CWD//\//-}"
PROJECT_MEMORY_FILE="${HOME}/.claude/projects/${PROJECT_MEMORY_KEY}/memory/MEMORY.md"
BLOATED_FILES=()

if [[ -f "$PROJECT_MEMORY_FILE" ]]; then
  line_count=$(wc -l < "$PROJECT_MEMORY_FILE" 2>/dev/null | tr -d ' ')
  if [[ "$line_count" -ge "$MEMORY_WARN_THRESHOLD" ]]; then
    BLOATED_FILES+=("project MEMORY.md (${line_count}/200行)")
  fi
fi

# Context Evaluator: MEMORY.md 内のファイルパス参照の実在チェック
# 存在しないファイルへの言及 = 古くなった記述の可能性
STALE_REFS=()
if [[ -f "$PROJECT_MEMORY_FILE" ]]; then
  while IFS= read -r ref_path; do
    # 相対パス → CWD 基準で解決
    if [[ "$ref_path" != /* ]]; then
      resolved="${CWD}/${ref_path}"
    else
      resolved="$ref_path"
    fi
    if [[ ! -e "$resolved" ]]; then
      STALE_REFS+=("$ref_path")
    fi
  done < <(grep -oE '`[a-zA-Z0-9_./-]+\.(md|sh|py|json|yaml|yml|toml|ts|js|txt)`' "$PROJECT_MEMORY_FILE" 2>/dev/null \
    | tr -d '`' | sort -u)
fi

# memory ファイルを収集
MEMORY_FILES=()

if [[ -d "$AGENT_MEMORY_DIR" ]]; then
  while IFS= read -r -d '' f; do
    MEMORY_FILES+=("$f")
    # エージェント memory の肥大化チェック
    line_count=$(wc -l < "$f" 2>/dev/null | tr -d ' ')
    if [[ "$line_count" -ge "$MEMORY_WARN_THRESHOLD" ]]; then
      agent_dir=$(basename "$(dirname "$f")")
      agent_name="${agent_dir#o-m-cc-}"
      BLOATED_FILES+=("${agent_name} (${line_count}/200行)")
    fi
  done < <(find "$AGENT_MEMORY_DIR" -name "MEMORY.md" -print0 2>/dev/null)
fi

# memory がなければ何も表示しない
if [[ ${#MEMORY_FILES[@]} -eq 0 ]] && [[ ${#BLOATED_FILES[@]} -eq 0 ]] && [[ ${#STALE_REFS[@]} -eq 0 ]]; then
  exit 0
fi

# ダイジェスト出力
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🧠 エージェント Memory ダイジェスト"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# 肥大化警告
if [[ ${#BLOATED_FILES[@]} -gt 0 ]]; then
  echo "  ⚠️ MEMORY.md 肥大化警告（200行でトランケートされます）"
  for bloated in "${BLOATED_FILES[@]}"; do
    echo "     - ${bloated}"
  done
  echo "     → トピック別ファイルに分離してください"
  echo ""
fi

# 古い参照の警告
if [[ ${#STALE_REFS[@]} -gt 0 ]]; then
  echo "  🔍 MEMORY.md 古い参照（ファイルが存在しません）"
  for ref in "${STALE_REFS[@]}"; do
    echo "     - ${ref}"
  done
  echo "     → 該当する記述を確認・更新してください"
  echo ""
fi

for f in ${MEMORY_FILES[@]+"${MEMORY_FILES[@]}"}; do
  # エージェント名を抽出 (o-m-cc-security-reviewer → security-reviewer)
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

# 過去の失敗パターン・注意点をハイライト（memory 内の警告的キーワード）
WARNINGS=()
for f in ${MEMORY_FILES[@]+"${MEMORY_FILES[@]}"}; do
  while IFS= read -r line; do
    WARNINGS+=("$line")
  done < <(grep -i -E '注意|落とし穴|バグ|失敗|壊れ|ハマ|踏む|危険|avoid|gotcha|broken|fail' "$f" 2>/dev/null | head -3)
done

if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  echo "  ⚡ 過去の学び（注意すべきパターン）"
  for w in "${WARNINGS[@]}"; do
    cleaned=$(echo "$w" | sed 's/^[#*-]* *//')
    echo "     - ${cleaned}"
  done
  echo ""
fi

echo "詳細は .claude/agent-memory/<agent>/MEMORY.md を Read してください。"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

exit 0
