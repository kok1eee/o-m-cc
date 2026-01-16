---
description: "Ultrawork + Compact - コンテキスト要約後に最大パフォーマンスモード"
allowed-tools: Task, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TodoWrite, AskUserQuestion
model: opus
---

# Ultrawork + Compact

**まず /compact を実行してコンテキストを確保し、その後 Ultrawork を開始します。**

## タスク

$ARGUMENTS

---

## Step 1: Compact 実行

**ユーザーに以下を依頼:**

```
🔄 Ultrawork 開始前にコンテキストを最適化します。

以下を実行してください:
/compact

完了後、このタスクを続行します。
```

---

## Step 2: Ultrawork 開始

Compact 完了後、Ultrawork モードで実行。

**ULTRAWORK MODE ENABLED!**

以下の原則に従って並列エージェントを起動し、最速で完了:

1. **PARALLEL FIRST** - 独立タスクは並列実行（10個以上もOK）
2. **TODO厳密** - 全ステップをトラッキング
3. **DELEGATE** - 専門エージェントに委任
4. **VERIFY** - 完了前に必ず検証

---

**まず /compact の実行を依頼し、完了後に並列エージェントを起動してください。**
