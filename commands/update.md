---
name: update
description: o-m-cc プラグインを最新版に更新
---

# o-m-cc Update

プラグインを最新版に更新します。

## 実行コマンド

```bash
claude plugin update o-m-cc@kok1eee
```

上記コマンドを実行して、完了後にユーザーに再起動を促してください。

## キャッシュ問題がある場合

更新後も古いバージョンのままの場合、クリーンインストールを案内：

```bash
# 1. アンインストール
claude plugin uninstall o-m-cc@kok1eee

# 2. キャッシュクリア
rm -rf ~/.claude/plugins/cache/kok1eee/o-m-cc

# 3. 再インストール
claude plugin install o-m-cc@kok1eee

# 4. Claude Code を再起動
```

または、スクリプトを使用：

```bash
bash ~/.claude/plugins/o-m-cc/scripts/update.sh --clean
```

## 完了メッセージ

更新完了後、以下を表示：

```
✅ o-m-cc を最新版に更新しました
⚠️  Claude Code を再起動してください（Cmd+Shift+P → Reload Window）
```
