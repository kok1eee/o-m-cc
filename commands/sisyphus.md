---
description: "Sisyphusモードを有効化（CLAUDE.mdに原則を追加）"
argument-hint: ""
allowed-tools: [Read, Write, Edit, Glob, Bash, AskUserQuestion]
model: sonnet
---

# Sisyphus - モード有効化

**プロジェクトに Sisyphus モードを有効化します。**

一度有効化すれば、以降は自動的に「タスク完了まで止まらない」モードで動作します。

---

## Step 0: 依存プラグインの確認（任意）

**推奨プラグインがインストールされているか確認:**

```bash
echo "=== 推奨プラグイン確認 ==="
for plugin in frontend-design feature-dev code-simplifier security-guidance pyright-lsp typescript-lsp; do
  claude plugin list 2>/dev/null | grep -q "$plugin" && echo "✅ $plugin" || echo "❌ $plugin (未インストール)"
done
```

**未インストールのプラグインをインストール:**

```bash
# 推奨（開発支援）
claude plugin install frontend-design@claude-code-plugins
claude plugin install feature-dev@claude-code-plugins
claude plugin install code-simplifier@claude-code-plugins
claude plugin install security-guidance@claude-code-plugins

# LSP（エラー検出）
claude plugin install pyright-lsp@claude-code-lsps
claude plugin install typescript-lsp@claude-code-lsps
```

| プラグイン | 用途 |
|-----------|------|
| frontend-design | フロントエンド設計支援 |
| feature-dev | 機能開発ワークフロー |
| code-simplifier | コード簡素化（レビュー後サジェスト） |
| security-guidance | セキュリティレビュー支援 |
| pyright-lsp | Python エラー検出 |
| typescript-lsp | TypeScript エラー検出 |

> **Note**: ループ制御は o-m-cc 内蔵の Stop Hook で実現。ralph-wiggum は不要です。

---

## Step 1: 設定内容の確認

**AskUserQuestion** で設定内容を確認してください：

```
質問: Sisyphus モードの設定を行います。どのように設定しますか？

選択肢:
1. 標準設定（推奨） - 基本原則のみ追加
2. フル設定 - 原則 + hooks（stop-guard.sh）を設定
3. 確認のみ - 現在の設定状態を確認
```

---

## 実行内容

### Step 2: 現状確認

まず CLAUDE.md の存在と内容を確認：

```bash
# CLAUDE.md が存在するか確認
ls -la CLAUDE.md 2>/dev/null || echo "CLAUDE.md not found"
```

- **存在しない場合** → 新規作成
- **存在する場合** → Sisyphus セクションがあるか確認

### Step 3: Sisyphus セクションの追加

CLAUDE.md に以下のセクションを追加（既に存在する場合はスキップ）：

```markdown
## Sisyphus Mode

**タスク完了まで決して止まらない。**

### 原則

1. **TODO First** - 作業開始時に TodoWrite でタスクリストを作成
2. **One at a Time** - 同時に in_progress は1つだけ
3. **Complete Honestly** - 本当に完了したタスクのみ completed に
4. **Never Abandon** - 途中で止まらない
5. **Review Before Done** - 完了前に code-reviewer subagent でレビュー

### 完了条件

全てのTODOが完了し、レビューで Critical がない場合のみ：

\`\`\`
<promise>DONE</promise>
\`\`\`

### 禁止事項

- 途中放棄禁止 - TODOが残っている状態で「完了」と言わない
- 嘘の完了禁止 - `<promise>DONE</promise>` は本当に完了した時だけ
- レビュースキップ禁止 - 完了前に必ずレビュー
```

### Step 4: hooks の設定（フル設定時）

o-m-cc 内蔵の Stop Hook を設定。これで普段のタスクでも自動的に「完了まで止まらない」動きになる。

**1. hooks ディレクトリ作成:**
```bash
mkdir -p .claude/hooks
```

**2. stop-guard.sh 作成:**
```bash
cat > .claude/hooks/stop-guard.sh << 'EOF'
#!/bin/bash
# Sisyphus Stop Guard - o-m-cc 内蔵
# <promise>DONE</promise> が出力されるまでループ継続

TRANSCRIPT="$CLAUDE_TRANSCRIPT"

if echo "$TRANSCRIPT" | grep -q "<promise>DONE</promise>"; then
  # 完了条件を満たした → 停止を許可
  exit 0
else
  # 完了条件を満たしていない → 続行を強制
  echo "⚠️ タスク未完了。続行します..."
  exit 2
fi
EOF
chmod +x .claude/hooks/stop-guard.sh
```

**3. settings.json に hooks 追加:**
```bash
# .claude/settings.json を編集（または作成）
```

```json
{
  "hooks": {
    "Stop": [
      {
        "type": "command",
        "command": ".claude/hooks/stop-guard.sh"
      }
    ]
  }
}
```

> **動作**: Claude が停止しようとすると stop-guard.sh が実行され、`<promise>DONE</promise>` がない場合は exit 2 で続行を強制。

---

## 完了時の出力

### 新規有効化の場合

```
✅ Sisyphus モード有効化
   📄 CLAUDE.md に Sisyphus セクションを追加しました

   以降、このプロジェクトでは自動的に
   「タスク完了まで止まらない」モードで動作します。
```

### 既に有効な場合

```
ℹ️ Sisyphus モードは既に有効です
   📄 CLAUDE.md に Sisyphus セクションが存在します
```

---

## 使用例

### 初回セットアップ

```
/sisyphus
```

### 有効化後の通常作業

```
「ログインボタンのバグを修正して」
→ 自動的に Sisyphus モードで動作
→ TODO作成 → 実装 → レビュー → 完了
```

### 複雑なタスク

```
/plan "認証システムを実装"
→ 要件 → 設計 → タスク分解
→ 自動的に Sisyphus モードで実装
```

---

**CLAUDE.md を確認し、Sisyphus セクションを追加してください。**
