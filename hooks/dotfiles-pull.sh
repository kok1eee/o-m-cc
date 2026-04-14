#!/bin/bash
# SessionStart: dotfiles repo を24時間に1回 pull（バックグラウンド）
# 複数マシン（Mac/EC2等）で dotfiles を共有している場合の軽量な自動同期
# - ~/dotfiles が存在しなければ no-op（他プロジェクトへの影響なし）
# - 24時間以内に pull 済みならスキップ（/tmp/dotfiles-last-pull の mtime チェック）
# - バックグラウンド実行で SessionStart をブロックしない
# - O_M_CC_DOTFILES 環境変数で path override 可
set -euo pipefail

DOTFILES="${O_M_CC_DOTFILES:-$HOME/dotfiles}"
MARKER="/tmp/dotfiles-last-pull"
THROTTLE_MINUTES=1440  # 24h

# dotfiles repo がなければ何もしない
[ -d "$DOTFILES/.git" ] || exit 0

# 24h 以内に pull していたらスキップ
if [ -f "$MARKER" ]; then
  AGE=$(find "$MARKER" -mmin +${THROTTLE_MINUTES} -print 2>/dev/null | head -1)
  [ -z "$AGE" ] && exit 0
fi

# バックグラウンドで pull（SessionStart を遅延させない）
# 失敗時は silent（次の throttle 期間後に再試行）
(cd "$DOTFILES" && git pull --rebase --quiet 2>/dev/null) &

# 成功/失敗問わず marker を更新（失敗時に毎回再試行しない）
touch "$MARKER"

exit 0
