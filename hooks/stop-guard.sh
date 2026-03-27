#!/bin/bash
# Sisyphus Stop Guard (diff-based)
# ファイル変更量ベースで quality-gate を推奨/強制。セッション横断で累積。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true

if [[ -f "${SCRIPT_DIR}/lib/cta.sh" ]]; then
  # shellcheck source=lib/cta.sh
  source "${SCRIPT_DIR}/lib/cta.sh"
fi

# Headless モード（claude -p）ではスキップ
if is_headless; then
  cat > /dev/null
  exit 0
fi

if ! check_command jq; then
  exit 0
fi

# Configuration
STATE_FILE=".claude/sisyphus-state.json"
MAX_ITERATIONS="${SISYPHUS_MAX_ITERATIONS:-50}"
MIN_DIFF="${SISYPHUS_MIN_DIFF:-500}"
FORCE_DIFF="${SISYPHUS_FORCE_DIFF:-1000}"
PROOF_FILE=".claude/quality-gate-proof.json"
RUNNING_FILE=".claude/quality-gate-running"
CARRYOVER_FILE="${CLAUDE_PLUGIN_DATA:-/dev/null}/unreviewed-lines.json"

HOOK_INPUT=$(cat)

# サブエージェントはスキップ
AGENT_TYPE=$(echo "$HOOK_INPUT" | jq -r '.agent_type // empty' 2>/dev/null || echo "")
if [[ -n "$AGENT_TYPE" && "$AGENT_TYPE" != "main" ]]; then
  exit 0
fi

# プロジェクトディレクトリに移動（hook はプラグインルートで実行される可能性がある）
PROJECT_CWD=$(echo "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null || echo "")
if [[ -n "$PROJECT_CWD" && -d "$PROJECT_CWD" ]]; then
  cd "$PROJECT_CWD"
fi

# get_diff_lines は common.sh で定義（cwd スコープ済み）

DIFF_LINES=$(get_diff_lines "$PROJECT_CWD")

# ベースライン計算: max(セッション開始時, 前回 quality-gate 通過時)
BASELINE_FILE=".claude/sisyphus-baseline.json"
BASELINE=0
if [[ -f "$BASELINE_FILE" ]]; then
  BASELINE=$(jq -r '.baseline_diff // 0' "$BASELINE_FILE" 2>/dev/null || echo "0")
fi
PASSED_AT=0
if [[ -f "$STATE_FILE" ]]; then
  PASSED_AT=$(jq -r '.passed_at_diff // 0' "$STATE_FILE" 2>/dev/null || echo "0")
fi

# コミット検出: 総 diff が passed_at を下回った → コミットが行われたのでリセット
if [[ $PASSED_AT -gt 0 && $DIFF_LINES -lt $PASSED_AT ]]; then
  PASSED_AT=0
  rm -f "$STATE_FILE"
fi

EFFECTIVE_BASELINE=$(( BASELINE > PASSED_AT ? BASELINE : PASSED_AT ))
SESSION_DIFF=$(( DIFF_LINES - EFFECTIVE_BASELINE ))
if [[ $SESSION_DIFF -lt 0 ]]; then
  SESSION_DIFF=0
fi

# セッション横断の累積: 前セッションからの未検証行数を加算
CARRYOVER=0
if [[ -f "$CARRYOVER_FILE" ]]; then
  CARRYOVER=$(jq -r '.lines // 0' "$CARRYOVER_FILE" 2>/dev/null || echo "0")
fi
EFFECTIVE_DIFF=$(( SESSION_DIFF + CARRYOVER ))

# 未検証行数を更新（次セッションへの引き継ぎ用）
save_carryover() {
  if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
    mkdir -p "${CLAUDE_PLUGIN_DATA}"
    jq -n --argjson lines "$1" '{lines: $lines}' > "$CARRYOVER_FILE"
  fi
}

# 実効変更が閾値未満 → 素通り
if [[ $EFFECTIVE_DIFF -lt $MIN_DIFF ]]; then
  save_carryover "$EFFECTIVE_DIFF"
  exit 0
fi

# quality-gate 実行中 → ブロックしない（エージェント待機中の誤ブロック防止）
if [[ -f "$RUNNING_FILE" ]]; then
  # running マーカーが baseline より新しい場合のみ有効
  if [[ "$RUNNING_FILE" -nt "$BASELINE_FILE" ]]; then
    exit 0
  fi
fi

# --- 以下、変更が閾値以上の場合のみ実行 ---

# Iteration counter
if [[ -f "$STATE_FILE" ]]; then
  ITERATION=$(jq -r '.iteration // 0' "$STATE_FILE" 2>/dev/null || echo "0")
else
  mkdir -p "$(dirname "$STATE_FILE")"
  ITERATION=0
fi

if [[ $ITERATION -ge $MAX_ITERATIONS ]]; then
  echo "🛑 SISYPHUS GUARD: Max iterations ($MAX_ITERATIONS) に到達。"
  rm -f "$STATE_FILE"
  exit 0
fi

increment() {
  jq -n --argjson iter "$((ITERATION + 1))" --argjson pat "$PASSED_AT" \
    '{iteration: $iter, passed_at_diff: $pat}' > "$STATE_FILE"
}

# proof ファイル検証（quality-gate スキルが書き込む）
if [[ -f "$PROOF_FILE" ]]; then
  # セッション開始後に書かれた proof か確認（baseline ファイルより新しい）
  if [[ "$PROOF_FILE" -nt "$BASELINE_FILE" ]]; then
    echo "✅ Sisyphus Guard: Quality Gate 通過を確認（変更 ${EFFECTIVE_DIFF} 行）"
    jq -n --argjson pat "$DIFF_LINES" '{iteration: 0, passed_at_diff: $pat}' > "$STATE_FILE"
    # carryover リセット（quality-gate 通過）
    save_carryover 0
    exit 0
  fi
fi

# proof なし → 推奨 or 強制（変更量で判定）
# 累積行数を保存（次セッションに引き継ぐ）
save_carryover "$EFFECTIVE_DIFF"

CARRYOVER_MSG=""
if [[ $CARRYOVER -gt 0 ]]; then
  CARRYOVER_MSG="（前セッションからの累積 ${CARRYOVER} 行を含む）"
fi

if [[ $EFFECTIVE_DIFF -ge $FORCE_DIFF ]]; then
  # 強制ブロック（1000行〜）
  if [[ $ITERATION -gt 0 ]]; then
    increment
    echo "🛑 Sisyphus Guard: ${EFFECTIVE_DIFF} 行の未検証コード${CARRYOVER_MSG}。Skill ツールで /quality-gate を実行してください。他のことはしないでください。" >&2
    exit 2
  fi
  increment
  jq -n \
    --arg reason "${EFFECTIVE_DIFF} 行の未検証コード${CARRYOVER_MSG}があります。今すぐ Skill ツールで o-m-cc:quality-gate を実行してください。他のことはしないでください。" \
    '{ "decision": "block", "reason": $reason }'
  exit 0
else
  # 推奨ブロック（500行〜999行）: 初回のみブロック、2回目以降は素通り
  if [[ $ITERATION -eq 0 ]]; then
    increment
    jq -n \
      --arg reason "${EFFECTIVE_DIFF} 行の未検証コード${CARRYOVER_MSG}があります。Skill ツールで o-m-cc:quality-gate を実行してください。" \
      '{ "decision": "block", "reason": $reason }'
    exit 0
  fi
  # 2回目以降: 素通り（一度注意喚起済み）
  exit 0
fi
