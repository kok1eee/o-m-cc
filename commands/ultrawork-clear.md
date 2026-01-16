---
description: "Ultrawork + Clear - コンテキストクリア後に最大パフォーマンスモード"
allowed-tools: Task, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TodoWrite, AskUserQuestion
model: opus
---

# Ultrawork + Clear

**まず /clear を実行してコンテキストを完全クリアし、その後 Ultrawork を開始します。**

## タスク

$ARGUMENTS

---

## Step 1: Clear 実行

**ユーザーに以下を依頼:**

```
🗑️ Ultrawork 開始前にコンテキストをクリアします。

以下を実行してください:
/clear

完了後、このタスクを続行します。
```

**注意**: /clear は会話履歴を完全に削除します。必要な情報は再収集されます。

---

## Step 2: Ultrawork 開始

Clear 完了後、Ultrawork モードで実行。

**ULTRAWORK MODE ENABLED!**

以下の原則に従って並列エージェントを起動し、最速で完了:

1. **PARALLEL FIRST** - 独立タスクは並列実行（10個以上もOK）
2. **TODO厳密** - 全ステップをトラッキング
3. **DELEGATE** - 専門エージェントに委任
4. **VERIFY** - 完了前に必ず検証

---

**まず /clear の実行を依頼し、完了後に並列エージェントを起動してください。**
