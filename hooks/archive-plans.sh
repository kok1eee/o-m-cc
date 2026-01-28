#!/bin/bash
# o-m-cc: Archive existing plan files on session start

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/lib/common.sh" ]]; then
  # shellcheck source=lib/common.sh
  source "${SCRIPT_DIR}/lib/common.sh"
else
  get_file_mtime() { stat -f %m "$1" 2>/dev/null || stat -c %Y "$1" 2>/dev/null || echo "0"; }
  log_debug() { :; }
  log_error() { echo "❌ $1" >&2; }
fi

PLANS_DIR="${HOME}/.claude/plans"
ARCHIVE_DIR="${PLANS_DIR}/archive"
TODAY=$(date +%Y-%m-%d)
TODAY_ARCHIVE="${ARCHIVE_DIR}/${TODAY}"

# Skip if no plans directory
if [[ ! -d "$PLANS_DIR" ]]; then
  log_debug "plans ディレクトリが存在しません"
  exit 0
fi

# Find plan files (exclude archive directory and agent files)
plan_files=$(find "$PLANS_DIR" -maxdepth 1 -name "*.md" -type f 2>/dev/null || true)
if [[ -z "$plan_files" ]]; then
  log_debug "アーカイブ対象のファイルがありません"
  exit 0
fi

mkdir -p "$TODAY_ARCHIVE"

archived_count=0
for file in $plan_files; do
  filename=$(basename "$file")

  # Skip agent files
  [[ "$filename" == *"-agent-"* ]] && continue

  # Check file age (archive if older than 1 hour)
  file_mtime=$(get_file_mtime "$file")
  file_mtime=$((file_mtime + 0))  # 数値化
  current_time=$(date +%s)
  file_age=$((current_time - file_mtime))

  if [[ $file_age -lt 3600 ]]; then
    log_debug "$filename は1時間以内のためスキップ"
    continue
  fi

  # Archive with timestamp if file already exists
  target="${TODAY_ARCHIVE}/${filename}"
  if [[ -f "$target" ]]; then
    timestamp=$(date +%H%M%S)
    target="${TODAY_ARCHIVE}/${filename%.md}-${timestamp}.md"
  fi

  if cp "$file" "$target" 2>/dev/null; then
    ((archived_count++))
    log_debug "$filename をアーカイブ: $target"
  else
    log_error "$filename のアーカイブに失敗"
  fi
done

if [[ $archived_count -gt 0 ]]; then
  echo "Archived $archived_count plan file(s) to ${TODAY_ARCHIVE}"
fi

exit 0
