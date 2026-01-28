#!/bin/bash
# o-m-cc 依存コマンドチェック
# SessionStart で実行し、必須コマンドの存在を確認

set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh" 2>/dev/null || true

# Read hook input
HOOK_INPUT=$(cat)

# OS 検出
OS=$(detect_os 2>/dev/null || echo "unknown")

# インストール手順
get_install_cmd() {
  local cmd="$1"

  case "$OS" in
    macos)
      case "$cmd" in
        jq)      echo "brew install jq" ;;
        python3) echo "brew install python3" ;;
        npm)     echo "brew install node" ;;
        cargo)   echo "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" ;;
        go)      echo "brew install go" ;;
        pytest)  echo "pip3 install pytest" ;;
        *)       echo "パッケージマネージャでインストールしてください" ;;
      esac
      ;;
    linux)
      case "$cmd" in
        jq)      echo "sudo apt install jq  # または yum install jq" ;;
        python3) echo "sudo apt install python3" ;;
        npm)     echo "sudo apt install nodejs npm" ;;
        cargo)   echo "curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh" ;;
        go)      echo "sudo apt install golang" ;;
        pytest)  echo "pip3 install pytest" ;;
        *)       echo "パッケージマネージャでインストールしてください" ;;
      esac
      ;;
    *)
      echo "パッケージマネージャでインストールしてください"
      ;;
  esac
}

# 必須コマンドチェック
MISSING_REQUIRED=()
REQUIRED_CMDS=("jq" "python3")

for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! check_command "$cmd" 2>/dev/null; then
    MISSING_REQUIRED+=("$cmd")
  fi
done

# 必須コマンドが不足している場合は警告
if [[ ${#MISSING_REQUIRED[@]} -gt 0 ]]; then
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "⚠️  o-m-cc: 必須コマンドが不足しています"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
  for cmd in "${MISSING_REQUIRED[@]}"; do
    echo "  ❌ $cmd が見つかりません"
    echo "     インストール: $(get_install_cmd "$cmd")"
    echo ""
    log_error "$cmd が見つかりません" 2>/dev/null || true
  done
  echo "上記をインストールしないと一部の hooks が正常に動作しません。"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
fi

# オプションコマンドチェック（デバッグモードのみ）
if [[ "${O_M_CC_DEBUG:-0}" == "1" ]]; then
  OPTIONAL_CMDS=("npm" "cargo" "go" "pytest")
  MISSING_OPTIONAL=()

  for cmd in "${OPTIONAL_CMDS[@]}"; do
    if ! check_command "$cmd" 2>/dev/null; then
      MISSING_OPTIONAL+=("$cmd")
    fi
  done

  if [[ ${#MISSING_OPTIONAL[@]} -gt 0 ]]; then
    echo ""
    echo "🔍 [o-m-cc debug] オプションコマンド:"
    for cmd in "${MISSING_OPTIONAL[@]}"; do
      echo "   ⚪ $cmd: 未インストール"
    done
    echo ""
  fi
fi

# 常に exit 0 (ブロックしない)
exit 0
