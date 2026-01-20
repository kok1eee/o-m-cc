---
name: update
description: o-m-cc プラグインをクリーンインストール（キャッシュクリア + 再インストール）
---

# o-m-cc Clean Update

キャッシュをクリアして最新版をインストールします。

## 実行手順

以下のコマンドを順番に実行してください：

```bash
# 1. アンインストール
claude plugin uninstall o-m-cc@kok1eee

# 2. キャッシュクリア
rm -rf ~/.claude/plugins/cache/kok1eee/o-m-cc

# 3. 再インストール
claude plugin install o-m-cc@kok1eee
```

## 完了後

```
✅ o-m-cc をクリーンインストールしました
⚠️  Claude Code を再起動してください（Cmd+Shift+P → Reload Window）
```
