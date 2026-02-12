# o-m-cc Hooks ガイド

o-m-cc プラグインが提供する hooks の使い方を説明します。

## 概要

o-m-cc は Claude Code の hooks 機能を使って、以下の自動化を提供します:

- **セッション管理**: 前回の作業状態の復元、プランファイルのアーカイブ
- **品質チェック**: セキュリティ警告、自動検証
- **フォーカス維持**: タスク進行中の脱線防止
- **Sisyphus モード**: タスク完了時のコードレビュー強制

## Hook 一覧

### SessionStart (セッション開始時)

| Hook | 説明 | タイムアウト |
|------|------|------------|
| `check-dependencies.sh` | 依存コマンド（jq, python3）の存在確認 | 3秒 |
| `archive-plans.sh` | 1時間以上前のプランファイルをアーカイブ | 5秒 |
| `resume-session.sh` | 前回のセッション状態を表示 | 5秒 |

### Stop (セッション終了時)

| Hook | 説明 | タイムアウト |
|------|------|------------|
| `stop-guard.sh` | Sisyphus ガード（DONE 検知時のレビュー確認） | 10秒 |
| `generate-handover.sh` | セッション状態を HANDOVER.md に保存（/handover 未実行時のフォールバック） | 10秒 |

### UserPromptSubmit (ユーザー入力時)

| Hook | 説明 | タイムアウト |
|------|------|------------|
| `focus-guard.sh` | タスク進行中の脱線防止（systemMessage 注入） | 3秒 |

タスク進行中（`plan/tasks.md` に未完了タスクがある）の場合、以下のルールを systemMessage として注入します:
- 現在の作業に関連する修正・方向転換 → 反映する
- 全く別の作業の依頼 → 「現在のタスク完了後に対応します」と返答

### PreToolUse (ツール実行前)

| Hook | 対象ツール | 説明 | タイムアウト |
|------|-----------|------|------------|
| `security_reminder_hook.py` | Write, Edit | セキュリティパターンの検出と警告 | 5秒 |

### PostToolUse (ツール実行後)

| Hook | 対象ツール | 説明 | タイムアウト |
|------|-----------|------|------------|
| `auto-verify.sh` | Write, Edit | フェーズ完了時の自動検証 | 120秒 |

## 設定

### hooks.json

hooks の設定は `hooks/hooks.json` で管理されています。

```json
{
  "hooks": {
    "SessionStart": [...],
    "Stop": [...],
    "UserPromptSubmit": [...],
    "PreToolUse": [...],
    "PostToolUse": [...]
  }
}
```

### デバッグモード

環境変数 `O_M_CC_DEBUG=1` を設定すると、詳細なログが出力されます:

```bash
export O_M_CC_DEBUG=1
claude
```

### エラーログ

hooks のエラーは `.claude/hooks-error.log` に記録されます。

## トラブルシューティング

### 依存コマンドがない

SessionStart 時に警告が表示されます:

```
⚠️  o-m-cc: 必須コマンドが不足しています

  ❌ jq が見つかりません
     インストール: brew install jq
```

### 状態ファイルのリセット

問題が発生した場合、状態ファイルをリセットできます:

```bash
bash hooks/reset-state.sh
```

削除されるファイル:
- `.claude/sisyphus-state.json`
- `.claude/.completed-phases`
- `plan/HANDOVER.md`
- `.claude/hooks-error.log`

### hooks を無効化

特定の hook を無効にするには、`hooks/hooks.json` を編集してください。

## カスタム hooks の追加

1. `hooks/` ディレクトリにスクリプトを作成
2. `hooks/hooks.json` にエントリを追加
3. 共通ライブラリを使用（推奨）:

```bash
#!/bin/bash
set -euo pipefail

# 共通ライブラリ読み込み
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# hook の実装
log_debug "カスタム hook 実行"
# ...

exit 0  # 常に exit 0 で終了
```

## 共通ライブラリ

`hooks/lib/common.sh` は以下の関数を提供します:

| 関数 | 説明 |
|------|------|
| `detect_os` | OS を検出（macos / linux / unknown） |
| `get_file_mtime` | ファイルの更新時刻を取得（クロスプラットフォーム対応） |
| `sed_inplace` | sed -i のクロスプラットフォーム対応 |
| `log_error` | エラーログ出力 |
| `log_warn` | 警告ログ出力 |
| `log_debug` | デバッグログ出力（`O_M_CC_DEBUG=1` 時のみ） |
| `check_command` | コマンドの存在確認 |
| `to_number` | 安全な数値変換 |
