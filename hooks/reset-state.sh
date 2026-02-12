#!/bin/bash
# o-m-cc 状態リセットツール
# hooks のエラー時にリカバリーとして使用

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true

# リセット対象ファイル
STATE_FILES=(
  "spec/sisyphus-state.json"
  "spec/.task-counter"
  "spec/.completed-phases"
  "spec/plan/HANDOVER.md"
  "spec/hooks-error.log"
)

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔄 o-m-cc 状態リセットツール"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "以下のファイルを削除します:"
echo ""

# 存在するファイルをリストアップ
EXISTING_FILES=()
for file in "${STATE_FILES[@]}"; do
  if [[ -f "$file" ]]; then
    EXISTING_FILES+=("$file")
    echo "  📄 $file"
  fi
done

if [[ ${#EXISTING_FILES[@]} -eq 0 ]]; then
  echo "  (リセット対象のファイルはありません)"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  exit 0
fi

echo ""
echo "⚠️  この操作は取り消せません。"
echo ""

# 確認プロンプト
read -r -p "続行しますか？ (y/N): " confirm
confirm=${confirm:-N}

if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
  echo ""
  echo "❌ キャンセルしました"
  exit 0
fi

echo ""

# ファイル削除
DELETED_COUNT=0
for file in "${EXISTING_FILES[@]}"; do
  if rm -f "$file" 2>/dev/null; then
    echo "  ✅ 削除: $file"
    DELETED_COUNT=$((DELETED_COUNT + 1))
    log_message "INFO" "状態ファイルを削除: $file" 2>/dev/null || true
  else
    echo "  ❌ 削除失敗: $file"
    log_error "状態ファイルの削除に失敗: $file" 2>/dev/null || true
  fi
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ リセット完了: ${DELETED_COUNT} 件のファイルを削除"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
