---
description: "Sisyphusモードを有効化（CLAUDE.mdに原則を追加）"
argument-hint: ""
allowed-tools: [Read, Write, Edit, Glob, Bash]
model: sonnet
---

# Sisyphus - モード有効化

**プロジェクトに Sisyphus モードを有効化します。**

一度有効化すれば、以降は自動的に「タスク完了まで止まらない」モードで動作します。

---

## 実行内容

### Step 1: 現状確認

まず CLAUDE.md の存在と内容を確認：

```bash
# CLAUDE.md が存在するか確認
ls -la CLAUDE.md 2>/dev/null || echo "CLAUDE.md not found"
```

- **存在しない場合** → 新規作成
- **存在する場合** → Sisyphus セクションがあるか確認

### Step 2: Sisyphus セクションの追加

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

### Step 3: hooks の設定（任意）

stop-guard.sh を設定する場合は、hooks.json を作成：

```json
{
  "hooks": [
    {
      "matcher": "Stop",
      "hooks": [
        {
          "type": "command",
          "command": ".claude/hooks/stop-guard.sh"
        }
      ]
    }
  ]
}
```

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
