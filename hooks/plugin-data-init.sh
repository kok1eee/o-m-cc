#!/bin/bash
# Plugin Data Init - PLUGIN_DATA パス表示 + 一時ファイルクリーンアップ

set -euo pipefail

if [[ "${CLAUDE_HEADLESS:-}" = "1" ]]; then
  cat > /dev/null
  exit 0
fi

# CLAUDE_PLUGIN_DATA 確認（2.1.78+）
if [[ -n "${CLAUDE_PLUGIN_DATA:-}" ]]; then
  echo "📦 CLAUDE_PLUGIN_DATA=${CLAUDE_PLUGIN_DATA}"
fi

# hook input を消費
cat > /dev/null

# 前セッションの一時ファイルをクリーンアップ
rm -f .claude/quality-gate-running .claude/evolve-done

exit 0
