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

Clear 完了後、**ultrawork.md の内容に従って実行**してください。

---

**まず /clear の実行を依頼し、完了後に ultrawork 本体を実行してください。**
