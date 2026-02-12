# o-m-cc Hooks エラーリファレンス

hooks で発生するエラーと対処法を説明します。

## エラーログの確認

hooks のエラーは `spec/hooks-error.log` に記録されます:

```bash
cat spec/hooks-error.log
```

ログ形式:
```
[2026-01-28 12:34:56] [hook-name] [ERROR] エラーメッセージ
```

## 依存コマンド関連

### HOOK-001: jq が見つかりません

**症状**: SessionStart 時に警告が表示される

**原因**: `jq` コマンドがインストールされていない

**対処法**:
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt install jq

# CentOS/RHEL
sudo yum install jq
```

### HOOK-002: python3 が見つかりません

**症状**: セキュリティチェックが実行されない

**対処法**:
```bash
# macOS
brew install python3

# Ubuntu/Debian
sudo apt install python3
```

## SessionStart 関連

### HOOK-101: HANDOVER.md の読み込み失敗

**症状**: 前回のセッション情報が表示されない

**原因**: `spec/plan/HANDOVER.md` が破損している

**対処法**:
```bash
rm spec/plan/HANDOVER.md
```

### HOOK-102: プランファイルのアーカイブ失敗

**症状**: `~/.claude/plans/archive/` にファイルがコピーされない

**原因**: ディスク容量不足、権限の問題

**対処法**:
```bash
# 権限確認
ls -la ~/.claude/plans/

# 手動でアーカイブ
mkdir -p ~/.claude/plans/archive/$(date +%Y-%m-%d)
mv ~/.claude/plans/*.md ~/.claude/plans/archive/$(date +%Y-%m-%d)/
```

## Stop 関連

### HOOK-103: Sisyphus ガードの状態ファイル破損

**症状**: 無限ループや予期しない動作

**対処法**:
```bash
rm spec/sisyphus-state.json
```

### HOOK-104: HANDOVER.md の生成失敗

**症状**: セッション終了時に HANDOVER.md が作成されない

**原因**: `spec/plan/` ディレクトリがない、tasks.md が存在しない

**対処法**:
```bash
mkdir -p spec/plan
```

## PostToolUse 関連

### HOOK-105: auto-verify タイムアウト

**症状**: フェーズ完了時の検証が途中で止まる

**原因**: テストやビルドに時間がかかりすぎ

**対処法**: `hooks/hooks.json` でタイムアウトを延長:
```json
{
  "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/auto-verify.sh",
  "timeout": 180000  // 3分に延長
}
```

## PreToolUse 関連

### HOOK-107: セキュリティチェックの失敗

**症状**: Python エラーが表示される

**原因**: Python 3.8 未満を使用、または依存パッケージの問題

**対処法**:
```bash
python3 --version  # 3.8 以上を確認
```

## 状態リセット

すべての hooks 状態をリセットするには:

```bash
bash hooks/reset-state.sh
```

または手動で:

```bash
rm -f spec/sisyphus-state.json
rm -f spec/.completed-phases
rm -f spec/plan/HANDOVER.md
rm -f spec/hooks-error.log
```

## デバッグ

詳細なログを出力するには:

```bash
export O_M_CC_DEBUG=1
claude
```

特定の hook を手動で実行してテスト:

```bash
echo '{}' | bash hooks/check-dependencies.sh
echo '{}' | bash hooks/resume-session.sh
```

## サポート

問題が解決しない場合:
1. `spec/hooks-error.log` の内容を確認
2. GitHub Issues で報告: https://github.com/kok1eee/o-m-cc/issues
