#!/bin/bash
# o-m-cc hooks 共通ライブラリ
# 全 Bash hooks で source して使用

# ログ: ファイル書き込みは廃止。
# 相対パス .claude/hooks-error.log が各リポを汚染し、permission-denied hook 経由で
# 拒否コマンド本文の秘密がコミット漏洩したため。可視化は log_* の stderr 出力に委ね、
# Claude Code の native な hook stderr/失敗表示に乗せる（logging.md「ファイルログ廃止」方針）。

# =============================================================================
# Headless モード検出
# =============================================================================

# CLAUDE_NON_INTERACTIVE=1（claude -p 時に自動設定）の場合、hook をスキップ
# 用途: headless 実行時にコンテキスト注入やブロックを防止
is_headless() {
  [[ "${CLAUDE_NON_INTERACTIVE:-}" = "1" ]]
}

# =============================================================================
# OS 検出
# =============================================================================

detect_os() {
  case "$(uname -s)" in
    Darwin*) echo "macos" ;;
    Linux*)  echo "linux" ;;
    *)       echo "unknown" ;;
  esac
}

# macOS / Linux 対応の stat (ファイル更新時刻取得)
get_file_mtime() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo "0"
    return
  fi

  case "$(detect_os)" in
    macos) stat -f %m "$file" 2>/dev/null || echo "0" ;;
    linux) stat -c %Y "$file" 2>/dev/null || echo "0" ;;
    *)     echo "0" ;;
  esac
}

# macOS / Linux 対応の sed -i
sed_inplace() {
  local expression="$1"
  local file="$2"

  case "$(detect_os)" in
    macos) sed -i '' "$expression" "$file" ;;
    linux) sed -i "$expression" "$file" ;;
    *)     sed -i "$expression" "$file" ;;  # fallback
  esac
}

# =============================================================================
# ログ機能
# =============================================================================

# メッセージログ出力（ファイル書き込みは廃止 → no-op）。
# 旧実装は .claude/hooks-error.log に追記していたが、相対パスゆえに作業中の各リポへ書き込まれ、
# 拒否コマンド本文の秘密が混入してコミット漏洩した。可視化は呼び出し側（log_error は常時 stderr、
# log_warn/log_debug は O_M_CC_DEBUG=1 時に stderr）に委ねる。
log_message() {
  : # no-op
}

log_error() {
  local message="$1"
  log_message "ERROR" "$message"
  # stderr にも出力 (Claude Code コンソールに表示される)
  echo "❌ [o-m-cc] $message" >&2
}

log_warn() {
  local message="$1"
  log_message "WARN" "$message"
  if [[ "${O_M_CC_DEBUG:-0}" == "1" ]]; then
    echo "⚠️  [o-m-cc] $message" >&2
  fi
}

log_debug() {
  local message="$1"
  if [[ "${O_M_CC_DEBUG:-0}" == "1" ]]; then
    log_message "DEBUG" "$message"
    echo "🔍 [o-m-cc] $message" >&2
  fi
}

# =============================================================================
# ユーティリティ
# =============================================================================

# コマンド存在チェック
check_command() {
  local cmd="$1"
  command -v "$cmd" >/dev/null 2>&1
}

# デバッグモード有効化
enable_debug_if_set() {
  if [[ "${O_M_CC_DEBUG:-0}" == "1" ]]; then
    set -x
  fi
}

# 安全な数値変換
to_number() {
  local value="$1"
  local default="${2:-0}"

  # 空文字列や非数値の場合はデフォルト値を返す
  if [[ -z "$value" ]] || ! [[ "$value" =~ ^[0-9]+$ ]]; then
    echo "$default"
  else
    echo "$value"
  fi
}

# リポジトリのルートを検出 (jj root → git rev-parse → cwd)
detect_repo_root() {
  jj root 2>/dev/null || git rev-parse --show-toplevel 2>/dev/null || pwd
}

# =============================================================================
# 初期化
# =============================================================================

# hook 名を自動設定 (呼び出し元のファイル名から)
if [[ -z "${O_M_CC_HOOK_NAME:-}" ]]; then
  O_M_CC_HOOK_NAME=$(basename "${BASH_SOURCE[1]:-unknown}" .sh)
fi

# エラートラップ: どの hook のどこで失敗したか stderr に出力
_on_error() {
  local exit_code=$?
  local line_no="${1:-unknown}"
  local script="${O_M_CC_HOOK_NAME:-unknown}"
  echo "❌ [o-m-cc:${script}] line ${line_no} で失敗 (exit ${exit_code})" >&2
  log_message "ERROR" "line ${line_no} で失敗 (exit ${exit_code})"
}
trap '_on_error ${LINENO}' ERR
