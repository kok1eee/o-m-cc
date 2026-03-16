#!/bin/bash
# o-m-cc hooks 共通ライブラリ
# 全 Bash hooks で source して使用

# ログファイル
O_M_CC_LOG_FILE="${O_M_CC_LOG_FILE:-.claude/hooks-error.log}"
O_M_CC_LOG_MAX_LINES=100

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

# ログディレクトリ確保
_ensure_log_dir() {
  local log_dir
  log_dir=$(dirname "$O_M_CC_LOG_FILE")
  if [[ ! -d "$log_dir" ]]; then
    mkdir -p "$log_dir" 2>/dev/null || true
  fi
}

# ログローテーション (100行超過時に古い行から削除)
_rotate_log() {
  if [[ ! -f "$O_M_CC_LOG_FILE" ]]; then
    return
  fi

  local line_count
  line_count=$(wc -l < "$O_M_CC_LOG_FILE" 2>/dev/null || echo "0")
  line_count=$((line_count + 0))  # 数値化

  if [[ "$line_count" -gt "$O_M_CC_LOG_MAX_LINES" ]]; then
    tail -n "$O_M_CC_LOG_MAX_LINES" "$O_M_CC_LOG_FILE" > "${O_M_CC_LOG_FILE}.tmp"
    mv "${O_M_CC_LOG_FILE}.tmp" "$O_M_CC_LOG_FILE"
  fi
}

# メッセージログ出力
log_message() {
  local level="$1"
  local message="$2"
  local hook_name="${O_M_CC_HOOK_NAME:-unknown}"
  local timestamp
  timestamp=$(date '+%Y-%m-%d %H:%M:%S')

  _ensure_log_dir
  echo "[${timestamp}] [${hook_name}] [${level}] ${message}" >> "$O_M_CC_LOG_FILE"
  _rotate_log
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
