#!/bin/bash
# o-m-cc: Agent Suggestion - ユーザー入力から適切なエージェント/コマンドを提案
# UserPromptSubmit hook
#
# agent-rules.json のキーワード・パターンとユーザー入力をマッチし、
# 関連するエージェントやコマンドを提案する。
# ブロックはしない（suggest のみ）。

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RULES_FILE="${SCRIPT_DIR}/agent-rules.json"

# agent-rules.json が存在しない場合はスキップ
if [[ ! -f "$RULES_FILE" ]]; then
  exit 0
fi

# jq が必要
if ! command -v jq >/dev/null 2>&1; then
  exit 0
fi

# stdin から入力を読み取り
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)

# プロンプトが空ならスキップ
if [[ -z "$PROMPT" ]]; then
  exit 0
fi

# プロンプトを小文字化（日本語はそのまま）
PROMPT_LOWER=$(echo "$PROMPT" | tr '[:upper:]' '[:lower:]')

MATCHED_HIGH=""
MATCHED_MEDIUM=""
MATCHED_LOW=""

# エージェントのマッチング
match_entry() {
  local name="$1"
  local type="$2"  # agent or command
  local priority="$3"
  local keywords="$4"
  local patterns="$5"

  local matched=false

  # キーワードマッチ
  if [[ -n "$keywords" ]]; then
    while IFS= read -r kw; do
      if [[ -n "$kw" ]] && echo "$PROMPT_LOWER" | grep -qi "$kw" 2>/dev/null; then
        matched=true
        break
      fi
    done <<< "$keywords"
  fi

  # パターンマッチ（キーワードでマッチしなかった場合）
  if [[ "$matched" == "false" ]] && [[ -n "$patterns" ]]; then
    while IFS= read -r pat; do
      if [[ -n "$pat" ]] && echo "$PROMPT_LOWER" | grep -qiE "$pat" 2>/dev/null; then
        matched=true
        break
      fi
    done <<< "$patterns"
  fi

  if [[ "$matched" == "true" ]]; then
    local label
    if [[ "$type" == "command" ]]; then
      label="$name"
    else
      label="$name エージェント"
    fi

    case "$priority" in
      high)   MATCHED_HIGH="${MATCHED_HIGH}  → ${label}\n" ;;
      medium) MATCHED_MEDIUM="${MATCHED_MEDIUM}  → ${label}\n" ;;
      low)    MATCHED_LOW="${MATCHED_LOW}  → ${label}\n" ;;
    esac
  fi
}

# agents セクションを処理
for agent_name in $(jq -r '.agents | keys[]' "$RULES_FILE" 2>/dev/null); do
  priority=$(jq -r ".agents[\"$agent_name\"].priority" "$RULES_FILE")
  keywords=$(jq -r ".agents[\"$agent_name\"].keywords[]?" "$RULES_FILE" 2>/dev/null)
  patterns=$(jq -r ".agents[\"$agent_name\"].patterns[]?" "$RULES_FILE" 2>/dev/null)
  match_entry "$agent_name" "agent" "$priority" "$keywords" "$patterns"
done

# commands セクションを処理
for cmd_name in $(jq -r '.commands | keys[]' "$RULES_FILE" 2>/dev/null); do
  priority=$(jq -r ".commands[\"$cmd_name\"].priority" "$RULES_FILE")
  keywords=$(jq -r ".commands[\"$cmd_name\"].keywords[]?" "$RULES_FILE" 2>/dev/null)
  patterns=$(jq -r ".commands[\"$cmd_name\"].patterns[]?" "$RULES_FILE" 2>/dev/null)
  match_entry "$cmd_name" "command" "$priority" "$keywords" "$patterns"
done

# マッチがなければ何も出力しない
if [[ -z "$MATCHED_HIGH" ]] && [[ -z "$MATCHED_MEDIUM" ]] && [[ -z "$MATCHED_LOW" ]]; then
  exit 0
fi

# 提案メッセージを構築
MSG=""

if [[ -n "$MATCHED_HIGH" ]]; then
  MSG="${MSG}📌 推奨:\n${MATCHED_HIGH}"
fi

if [[ -n "$MATCHED_MEDIUM" ]]; then
  MSG="${MSG}💡 関連:\n${MATCHED_MEDIUM}"
fi

if [[ -n "$MATCHED_LOW" ]]; then
  MSG="${MSG}📎 参考:\n${MATCHED_LOW}"
fi

# systemMessage として注入
jq -n --arg msg "$MSG" '{
  "systemMessage": ("━━━ 🎯 Agent Suggestion ━━━\n" + $msg + "━━━━━━━━━━━━━━━━━━━━━━━━━")
}'

exit 0
