---
description: "コード変更をレビュー（code-reviewer subagent）"
argument-hint: "[specific files or 'all']"
allowed-tools: [Task, Read, Glob, Grep, Bash]
model: sonnet
---

# Review Command - コードレビュー

実装したコードの品質をチェックします。

## 対象

$ARGUMENTS

---

## 実行フロー

### Step 1: 変更差分の取得

まず変更内容を確認します：

```bash
# 変更差分を取得
jj diff  # または git diff
```

### Step 2: コードレビュー

**code-reviewer subagent** を Task tool で呼び出してレビューを実行してください。

```
Task tool で code-reviewer subagent を呼び出し：
- 変更差分を共有
- 以下の観点でレビュー：
  - コード品質
  - セキュリティ
  - 保守性
  - パフォーマンス
```

### Step 3: 結果の確認

code-reviewer の結果を確認：

- **Critical なし** → レビュー完了、次のステップへ
- **Critical あり** → 問題を修正してから再レビュー

---

## 完了時の出力

レビューが完了したら、以下を出力してください：

### Critical なしの場合

```
✅ コードレビュー完了
   🟢 Critical: なし
   🟡 Warning: X件
   🟢 Suggestion: X件
```

### Critical ありの場合

```
⚠️ コードレビュー完了
   🔴 Critical: X件 ← 要修正
   🟡 Warning: X件
   🟢 Suggestion: X件
```

Critical がある場合は、問題点と修正方法を具体的に提案してください。

---

**レビューを開始します。まず変更差分を確認し、code-reviewer subagent を呼び出してください。**
