#!/bin/bash
# quality-gate 静的解析スクリプト（変更ファイルのみ対象）
# usage: bash lint.sh [--proof]
#   --proof: 全チェック通過時に proof ファイルを書き込む
set -euo pipefail

PASS=true
WRITE_PROOF=false
[[ "${1:-}" == "--proof" ]] && WRITE_PROOF=true

check_cmd() { command -v "$1" >/dev/null 2>&1; }

# 変更ファイル一覧を取得（jj → git fallback）
get_changed_files() {
  if check_cmd jj && jj root >/dev/null 2>&1; then
    jj diff --name-only 2>/dev/null || true
  elif check_cmd git && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git diff --name-only HEAD 2>/dev/null || true
  fi
}

CHANGED_FILES=$(get_changed_files)
if [[ -z "$CHANGED_FILES" ]]; then
  echo "✅ 変更ファイルなし — スキップ"
  if [[ "$WRITE_PROOF" == "true" ]]; then
    mkdir -p .claude
    echo "{\"passed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > .claude/quality-gate-proof.json
    echo "📝 proof ファイル書き込み完了"
  fi
  rm -f .claude/quality-gate-running
  exit 0
fi

# 拡張子別にフィルタ
py_files=$(echo "$CHANGED_FILES" | grep -E '\.py$' || true)
sh_files=$(echo "$CHANGED_FILES" | grep -E '\.sh$' | grep -v '.claude/' || true)
ts_files=$(echo "$CHANGED_FILES" | grep -E '\.(ts|tsx)$' || true)
js_files=$(echo "$CHANGED_FILES" | grep -E '\.(js|jsx)$' || true)
rs_files=$(echo "$CHANGED_FILES" | grep -E '\.rs$' || true)

# Python（変更ファイルのみ）
if [[ -n "$py_files" ]]; then
  echo "🐍 Python: ruff check ($(echo "$py_files" | wc -l | tr -d ' ') files)"
  if check_cmd ruff; then
    echo "$py_files" | xargs ruff check || PASS=false
  else
    echo "  ⚠️ ruff not found, skipping"
  fi
  if check_cmd ty; then
    echo "🐍 Python: ty check"
    echo "$py_files" | xargs ty check 2>/dev/null || PASS=false
  fi
fi

# Shell（変更ファイルのみ）
if [[ -n "$sh_files" ]]; then
  echo "🐚 Shell: shellcheck ($(echo "$sh_files" | wc -l | tr -d ' ') files)"
  if check_cmd shellcheck; then
    echo "$sh_files" | xargs shellcheck -S warning || PASS=false
  else
    echo "  ⚠️ shellcheck not found, skipping"
  fi
fi

# TypeScript（変更ファイルのみ — tsc はプロジェクト全体だが eslint はファイル指定）
if [[ -n "$ts_files" ]]; then
  echo "📘 TypeScript ($(echo "$ts_files" | wc -l | tr -d ' ') files)"
  if [[ -f "node_modules/.bin/tsc" ]]; then
    npx tsc --noEmit || PASS=false
  fi
  if [[ -f "node_modules/.bin/eslint" ]]; then
    echo "$ts_files" | xargs npx eslint || PASS=false
  fi
fi

# Rust（cargo は常にプロジェクト全体）
if [[ -n "$rs_files" ]]; then
  echo "🦀 Rust: clippy + test"
  if check_cmd cargo; then
    cargo clippy -- -D warnings || PASS=false
    cargo test || PASS=false
  fi
fi

# running マーカー削除
rm -f .claude/quality-gate-running

# 結果
if [[ "$PASS" == "true" ]]; then
  echo ""
  echo "✅ 静的解析通過"
  if [[ "$WRITE_PROOF" == "true" ]]; then
    mkdir -p .claude
    echo "{\"passed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > .claude/quality-gate-proof.json
    echo "📝 proof ファイル書き込み完了"
  fi
else
  echo ""
  echo "❌ 静的解析失敗 — エラーを修正して再実行してください"
  exit 1
fi
