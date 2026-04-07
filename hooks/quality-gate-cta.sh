#!/bin/bash
# PreToolUse(Bash): push 前に quality-gate 実行を促す（非強制 CTA）
# 判定: 直近コミット時刻 > 最終 quality-gate 実行時刻 → ヒント出力
# exit 0 で push 自体はブロックしない
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
fi

# Headless モードではスキップ
if is_headless 2>/dev/null; then
  cat > /dev/null
  exit 0
fi

# JSON 入力
HOOK_INPUT=$(cat)

# Bash tool 以外はスキップ（matcher で絞っているが念のため）
TOOL_NAME=$(echo "$HOOK_INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")
if [[ "$TOOL_NAME" != "Bash" ]]; then
  exit 0
fi

# command 取得
COMMAND=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null || echo "")

# push 系のコマンドのみ反応（jj git push / git push）
if ! echo "$COMMAND" | grep -qE '(jj[[:space:]]+git[[:space:]]+push|^[[:space:]]*git[[:space:]]+push|[[:space:]&;|]git[[:space:]]+push)'; then
  exit 0
fi

# CLAUDE_PLUGIN_DATA / skill-usage.log の存在確認
PLUGIN_DATA="${CLAUDE_PLUGIN_DATA:-}"
LOG_FILE="${PLUGIN_DATA}/skill-usage.log"

# 最終 quality-gate 実行時刻を取得（なければ空）
LAST_QG_ISO=""
if [[ -f "$LOG_FILE" ]]; then
  LAST_QG_ISO=$(grep -E '(o-m-cc:)?quality-gate' "$LOG_FILE" 2>/dev/null | tail -1 | awk '{print $1}' || true)
fi

# 直近コミット時刻を取得（jj 優先 → git fallback）
LAST_COMMIT_EPOCH=0
if command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
  # jj: @- (working copy parent) の committer timestamp
  LAST_COMMIT_EPOCH=$(jj log -r '@-' --no-graph -T 'committer.timestamp().format("%s")' 2>/dev/null | head -1 || echo "0")
elif command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  LAST_COMMIT_EPOCH=$(git log -1 --format='%ct' 2>/dev/null || echo "0")
fi
LAST_COMMIT_EPOCH=${LAST_COMMIT_EPOCH:-0}

# ISO8601 → epoch 変換（macOS / Linux 両対応）
to_epoch() {
  local ts="$1"
  if [[ -z "$ts" ]]; then
    echo "0"
    return
  fi
  case "$(uname -s)" in
    Darwin*)
      date -j -f "%Y-%m-%dT%H:%M:%SZ" "$ts" "+%s" 2>/dev/null || echo "0"
      ;;
    *)
      date -d "$ts" "+%s" 2>/dev/null || echo "0"
      ;;
  esac
}

LAST_QG_EPOCH=$(to_epoch "$LAST_QG_ISO")

# 判定
SHOULD_HINT=0
REASON=""

if [[ "$LAST_QG_EPOCH" -eq 0 ]]; then
  SHOULD_HINT=1
  REASON="quality-gate の実行履歴が見つかりません"
elif [[ "$LAST_COMMIT_EPOCH" -gt "$LAST_QG_EPOCH" ]]; then
  SHOULD_HINT=1
  DIFF_HOURS=$(( (LAST_COMMIT_EPOCH - LAST_QG_EPOCH) / 3600 ))
  REASON="最終 quality-gate 以降に新しいコミットがあります（${DIFF_HOURS}時間以上前）"
fi

if [[ "$SHOULD_HINT" -eq 1 ]]; then
  {
    echo ""
    echo "💡 [push 前 CTA] ${REASON}"
    echo "   コード品質確認のため Skill: o-m-cc:quality-gate の実行を検討してください（非強制）。"
    echo "   不要な場合はこのまま push を続行できます。"
    echo ""
  } >&2
fi

exit 0
