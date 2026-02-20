#!/bin/bash
# Auto-verify on phase completion
# PostToolUse (Write|Edit) で実行
# フェーズ完了を検知して自動的にビルド/テスト/リントを実行

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  check_command() { command -v "$1" >/dev/null 2>&1; }
  log_debug() { :; }
  log_error() { echo "❌ $1" >&2; }
fi

TASKS_FILE="plan/tasks.md"
COUNTER_FILE=".claude/.completed-phases"
VERIFY_CONFIG=".claude/verify.json"

# tasks.md が存在しない場合はスキップ
if [[ ! -f "$TASKS_FILE" ]]; then
  exit 0
fi

# Read hook input (required by Claude Code hook protocol)
HOOK_INPUT=$(cat)

# フェーズ完了数をカウント
COMPLETED_PHASES=0
CURRENT_PHASE=""
PHASE_TOTAL=0
PHASE_DONE=0

while IFS= read -r line; do
  if echo "$line" | grep -qE '^##\s+Phase'; then
    if [[ -n "$CURRENT_PHASE" && "$PHASE_TOTAL" -gt 0 && "$PHASE_DONE" -eq "$PHASE_TOTAL" ]]; then
      COMPLETED_PHASES=$((COMPLETED_PHASES + 1))
    fi
    CURRENT_PHASE="$line"
    PHASE_TOTAL=0
    PHASE_DONE=0
    continue
  fi
  if echo "$line" | grep -qE '^\s*-\s*\[[ x]\]'; then
    PHASE_TOTAL=$((PHASE_TOTAL + 1))
    if echo "$line" | grep -qE '^\s*-\s*\[x\]'; then
      PHASE_DONE=$((PHASE_DONE + 1))
    fi
  fi
done < "$TASKS_FILE"

# 最後のフェーズの判定
if [[ -n "$CURRENT_PHASE" && "$PHASE_TOTAL" -gt 0 && "$PHASE_DONE" -eq "$PHASE_TOTAL" ]]; then
  COMPLETED_PHASES=$((COMPLETED_PHASES + 1))
fi

# 前回の完了フェーズ数を取得
if [[ -f "$COUNTER_FILE" ]]; then
  PREV_PHASES=$(cat "$COUNTER_FILE" 2>/dev/null || echo "0")
else
  mkdir -p "$(dirname "$COUNTER_FILE")"
  PREV_PHASES=0
fi

# 新しいフェーズ完了を検知
if [[ "$COMPLETED_PHASES" -le "$PREV_PHASES" ]]; then
  exit 0
fi

# 現在の状態を保存
echo "$COMPLETED_PHASES" > "$COUNTER_FILE"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔍 Phase $COMPLETED_PHASES 完了 - 自動検証開始"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# 検証コマンドを取得
get_verify_commands() {
  # カスタム設定があれば使用
  if [[ -f "$VERIFY_CONFIG" ]] && command -v jq >/dev/null 2>&1; then
    jq -r '.commands[]?' "$VERIFY_CONFIG" 2>/dev/null && return
  fi

  # プロジェクトタイプ自動検出
  if [[ -f "package.json" ]]; then
    # Node.js/TypeScript プロジェクト
    if jq -e '.scripts.typecheck' package.json >/dev/null 2>&1; then
      echo "npm run typecheck"
    fi
    if jq -e '.scripts.lint' package.json >/dev/null 2>&1; then
      echo "npm run lint"
    fi
    if jq -e '.scripts.test' package.json >/dev/null 2>&1; then
      echo "npm test"
    fi
    if jq -e '.scripts.build' package.json >/dev/null 2>&1; then
      echo "npm run build"
    fi
  elif [[ -f "Cargo.toml" ]]; then
    # Rust プロジェクト
    echo "cargo check"
    echo "cargo clippy -- -D warnings"
    echo "cargo test"
  elif [[ -f "pyproject.toml" ]] || [[ -f "setup.py" ]]; then
    # Python プロジェクト
    if [[ -f "pyproject.toml" ]] && grep -q "ruff" pyproject.toml 2>/dev/null; then
      echo "ruff check ."
    fi
    if command -v pytest >/dev/null 2>&1 || [[ -d "tests" ]]; then
      echo "pytest"
    fi
  elif [[ -f "go.mod" ]]; then
    # Go プロジェクト
    echo "go build ./..."
    echo "go vet ./..."
    echo "go test ./..."
  fi
}

# 検証実行
ERRORS=()
COMMANDS=$(get_verify_commands)

if [[ -z "$COMMANDS" ]]; then
  echo "⚠️  検証コマンドが見つかりません"
  echo "   .claude/verify.json を作成するか、サポートされているプロジェクトタイプを使用してください"
  echo ""
  exit 0
fi

while IFS= read -r cmd; do
  [[ -z "$cmd" ]] && continue

  echo ""
  echo "▶ $cmd"

  # shellcheck disable=SC2086
  if ! bash -c "$cmd" 2>&1 | head -50; then
    ERRORS+=("$cmd")
    echo "❌ FAILED: $cmd"
  else
    echo "✅ PASSED"
  fi
done <<< "$COMMANDS"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo "❌ 検証失敗: ${#ERRORS[@]} 件のエラー"
  echo ""
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  echo ""
  echo "上記のエラーを修正してから次のフェーズに進んでください。"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  # エラーがあっても hooks は exit 0 で終了（Claude に修正を促す）
  exit 0
else
  echo "✅ 検証成功"
  echo ""
  echo "🔍 code-reviewer subagent でレビューすること"
  echo "💾 レビュー完了後、/compact を実行すること"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
fi

exit 0
