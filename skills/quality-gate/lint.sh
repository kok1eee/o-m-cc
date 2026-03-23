#!/bin/bash
# quality-gate 静的解析スクリプト
# usage: bash lint.sh [--proof]
#   --proof: 全チェック通過時に proof ファイルを書き込む
set -euo pipefail

PASS=true
WRITE_PROOF=false
[[ "${1:-}" == "--proof" ]] && WRITE_PROOF=true

check_cmd() { command -v "$1" >/dev/null 2>&1; }

# Python
if compgen -G "**/*.py" > /dev/null 2>&1; then
  echo "🐍 Python: ruff check"
  if check_cmd ruff; then
    ruff check . || PASS=false
  else
    echo "  ⚠️ ruff not found, skipping"
  fi
  if check_cmd ty; then
    echo "🐍 Python: ty check"
    ty check . || PASS=false
  fi
fi

# Shell
SHELL_FILES=$(find . -name "*.sh" -not -path "./.claude/*" -not -path "./node_modules/*" 2>/dev/null || true)
if [[ -n "$SHELL_FILES" ]]; then
  echo "🐚 Shell: shellcheck"
  if check_cmd shellcheck; then
    echo "$SHELL_FILES" | xargs shellcheck -S warning || PASS=false
  else
    echo "  ⚠️ shellcheck not found, skipping"
  fi
fi

# TypeScript
if compgen -G "**/*.ts" > /dev/null 2>&1 || compgen -G "**/*.tsx" > /dev/null 2>&1; then
  echo "📘 TypeScript: tsc + eslint"
  if [[ -f "node_modules/.bin/tsc" ]]; then
    npx tsc --noEmit || PASS=false
  fi
  if [[ -f "node_modules/.bin/eslint" ]]; then
    npx eslint . || PASS=false
  fi
fi

# Rust
if [[ -f "Cargo.toml" ]]; then
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
