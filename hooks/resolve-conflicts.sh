#!/bin/bash
# SessionStart: .claude/chronicle.md と .claude/context.md のコンフリクトを自動解決
#
# 跨マシン同期（local ⇄ EC2 等）で chronicle.md / context.md に頻発する
# コンフリクトを、ユーザー操作ゼロで自動解決する。
#
# 解決方針:
#   chronicle.md → 両側のエントリを union → dedupe → タイムスタンプ DESC → top 30
#   context.md   → Snapshot タイムスタンプが新しい側を採用
#
# jj は conflict を first-class で扱うが、コンフリクトマーカーを除去した内容を
# 書き戻せば自動的に「解決済み」と認識される（jj's auto-resolve on edit）。
# git の場合は念のため git add でマーク。
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

# stdin を drain
cat > /dev/null

CHRONICLE=".claude/chronicle.md"
CONTEXT=".claude/context.md"
RESOLVED_FILES=()

# --- chronicle.md の解決 ---
# 両側のエントリを union → dedupe → タイムスタンプ DESC → top 30
# git 形式（<<<<<<< / ======= / >>>>>>>）と jj 形式（%%%%%%% / +++++++）の両方に対応
resolve_chronicle() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -q '^<<<<<<<' "$file" 2>/dev/null || return 0

  local tmp
  tmp=$(mktemp)

  # Header: 最初のエントリ行 (`- [`) より前。全コンフリクトマーカー行を除外
  # 注: jj 形式の %%%%%%% / +++++++ も skip。diff 行 (+- [...]) も header には含めない
  awk '
    /^<<<<<<<|^=======|^>>>>>>>|^%%%%%%%|^\+\+\+\+\+\+\+/ {next}
    /^[+-]- \[/ {next}   # diff 行内の entry は header の判定対象外
    /^- \[/ {exit}
    {print}
  ' "$file" > "$tmp"

  # Entries: 全ての chronicle エントリを抽出 → dedupe → timestamp DESC ソート → top 30
  # - `^- [` : 通常の entry（git 形式の両側 or jj 形式の +++++++ section verbatim）
  # - `^\+- [` : jj 形式の %%%%%%% diff section で追加された行（+プレフィックス付き）
  {
    grep -E '^- \[' "$file"
    grep -E '^\+- \[' "$file" | sed 's/^+//'
  } | awk '!seen[$0]++' | \
      sort -t'[' -k2,2r | \
      head -30 >> "$tmp"

  mv "$tmp" "$file"
  RESOLVED_FILES+=("chronicle.md")
}

# --- context.md の解決 ---
# 形式検出 → それぞれのロジックで解決
resolve_context() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  grep -q '^<<<<<<<' "$file" 2>/dev/null || return 0

  if grep -q '^%%%%%%%' "$file"; then
    # --- jj 3-way 形式 ---
    # side #2（+++++++ 以降の verbatim）を採用
    # 理由: side #2 は通常 remote (他マシンが push した最新 snapshot)
    local tmp
    tmp=$(mktemp)

    awk '
      /^<<<<<<</    { in_conflict=1; in_side2=0; next }
      /^%%%%%%%/    { if (in_conflict) { in_side2=0 } next }
      /^\+\+\+\+\+\+\+/ { if (in_conflict) { in_side2=1 } next }
      /^>>>>>>>/    { in_conflict=0; in_side2=0; next }
      !in_conflict  { print; next }
      in_side2      { print }
    ' "$file" > "$tmp"

    mv "$tmp" "$file"
    RESOLVED_FILES+=("context.md ← side #2 (jj 3-way)")
    return 0
  fi

  # --- git 形式 ---
  # Snapshot タイムスタンプが新しい側を採用
  local local_side remote_side
  local_side=$(awk '
    /^>>>>>>>/ {skip=0; next}
    /^=======/ {skip=1; next}
    /^<<<<<<</ {next}
    !skip {print}
  ' "$file")
  remote_side=$(awk '
    /^<<<<<<</ {skip=1; next}
    /^=======/ {skip=0; next}
    /^>>>>>>>/ {next}
    !skip {print}
  ' "$file")

  local local_ts remote_ts
  local_ts=$(echo "$local_side" | grep -oE '### Snapshot \([0-9]+/[0-9]+ [0-9]+:[0-9]+' | head -1 | sed 's/### Snapshot (//')
  remote_ts=$(echo "$remote_side" | grep -oE '### Snapshot \([0-9]+/[0-9]+ [0-9]+:[0-9]+' | head -1 | sed 's/### Snapshot (//')

  local chosen_side chosen_label
  if [[ -n "${remote_ts:-}" && "${remote_ts:-}" > "${local_ts:-}" ]]; then
    chosen_side="$remote_side"
    chosen_label="remote (${remote_ts})"
  else
    chosen_side="$local_side"
    chosen_label="local (${local_ts:-unknown})"
  fi

  echo "$chosen_side" > "$file"
  RESOLVED_FILES+=("context.md ← ${chosen_label}")
}

# --- 実行 ---
resolve_chronicle "$CHRONICLE" || true
resolve_context "$CONTEXT" || true

# --- 結果報告 + jj/git にマーク ---
if [[ ${#RESOLVED_FILES[@]} -gt 0 ]]; then
  echo "📐 .claude/ コンフリクトを自動解決:"
  for f in "${RESOLVED_FILES[@]}"; do
    echo "  - ${f}"
  done

  # git の場合は念のため staging
  if command -v git >/dev/null 2>&1 && git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    git add "$CHRONICLE" "$CONTEXT" 2>/dev/null || true
  fi
  # jj はファイル更新で自動的に解決を認識（特別なマークは不要）
fi

exit 0
