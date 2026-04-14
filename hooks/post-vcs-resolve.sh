#!/bin/bash
# PostToolUse(Bash): VCS 操作後に .claude/chronicle.md / context.md のコンフリクトを自動解決
#
# 対象コマンド: jj rebase, jj git fetch, jj pull, git pull, git merge, git rebase
#   → これらの後はコンフリクトマーカーが working copy に出現する可能性
#
# ⚠️ 対象ファイルは .claude/chronicle.md と .claude/context.md のみ。
#   他のファイルは一切触らない（resolve-conflicts.sh でハードコード）。
set -euo pipefail

HOOK_INPUT=$(cat)
CMD=$(echo "$HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)

# VCS 操作でなければ no-op
if ! echo "$CMD" | grep -qE '(^|[[:space:]])(jj[[:space:]]+(rebase|pull|git[[:space:]]+(fetch|push))|git[[:space:]]+(pull|merge|rebase))([[:space:]]|$)'; then
  exit 0
fi

# resolve-conflicts.sh に委譲
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${SCRIPT_DIR}/resolve-conflicts.sh" </dev/null

exit 0
