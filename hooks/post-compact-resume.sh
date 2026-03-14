#!/bin/bash
# PostCompact: compaction 後にプロジェクト状態をリマインド
# stdout が system message として model に入る
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
fi

HOOK_INPUT=$(cat)

# --- プロジェクト状態を動的に取得 ---

echo ""
echo "📍 Compaction 後の現在地:"

# 1. context.md の Intent（直前に PreCompact が書いたもの）
CONTEXT_FILE=".claude/context.md"
if [[ -f "$CONTEXT_FILE" ]]; then
  INTENT=$(grep '^\*\*Intent:\*\*' "$CONTEXT_FILE" 2>/dev/null | head -1 | sed 's/\*\*Intent:\*\* //' || echo "")
  if [[ -n "$INTENT" ]]; then
    echo "  Intent: ${INTENT}"
  fi
fi

# 2. 変更行数（plan/ 除外）
DIFF_LINES=0
if check_command jj && jj root >/dev/null 2>&1; then
  STAT=$(jj diff --stat -- 'all() & ~glob:"plan/**"' 2>/dev/null | tail -1) || true
elif check_command git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  STAT=$(git diff --stat HEAD -- . ':!plan/' 2>/dev/null | tail -1) || true
fi
if [[ -n "${STAT:-}" ]]; then
  INS=$(echo "$STAT" | grep -oE '[0-9]+ insertion' | grep -oE '[0-9]+' || echo "0")
  DEL=$(echo "$STAT" | grep -oE '[0-9]+ deletion' | grep -oE '[0-9]+' || echo "0")
  DIFF_LINES=$(( ${INS:-0} + ${DEL:-0} ))
fi
echo "  変更: ${DIFF_LINES} 行（plan/ 除外）"

# 3. Quality Gate 状態
PROOF_FILE=".claude/quality-gate-proof.json"
RUNNING_FILE=".claude/quality-gate-running"
if [[ -f "$PROOF_FILE" ]]; then
  echo "  Quality Gate: ✅ 通過済み"
elif [[ -f "$RUNNING_FILE" ]]; then
  echo "  Quality Gate: ⏳ 実行中"
else
  echo "  Quality Gate: 未実行"
fi

# 4. plan/ の状態からフェーズ推測
if [[ -d "plan" ]]; then
  HAS_REQ=$(ls plan/requirements.md 2>/dev/null && echo "1" || echo "0")
  HAS_DESIGN=$(ls plan/design.md 2>/dev/null && echo "1" || echo "0")

  if [[ "$HAS_DESIGN" == "1" ]]; then
    echo "  フェーズ: 設計完了 → 実装中"
  elif [[ "$HAS_REQ" == "1" ]]; then
    echo "  フェーズ: 要件定義完了 → 設計中"
  else
    echo "  フェーズ: Discovery（計画開始）"
  fi
fi

echo ""
echo "→ .claude/context.md を Read して詳細な文脈を復元し、中断した作業を続行してください。"
echo ""

exit 0
