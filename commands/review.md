---
description: "コード変更をレビュー（code-reviewer + security-reviewer 並列実行）"
argument-hint: "[specific files or 'all']"
allowed-tools: [Task, Read, Glob, Grep, Bash, AskUserQuestion]
model: sonnet
context: fork
---

# Review Command - コードレビュー（並列実行）

コード品質とセキュリティを**同時にチェック**します。

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

### Step 2: 並列レビュー実行

**code-reviewer** と **security-reviewer** を Task tool で**同時に**呼び出し：

```
Task tool で並列実行（両方 background=true）：

1. code-reviewer subagent
   - 変更差分を共有
   - バグ、複雑性、保守性をチェック
   - 発見したパターンを learned/ に記録

2. security-reviewer subagent
   - 変更差分を共有
   - OWASP Top 10 ベースのセキュリティチェック
   - 脆弱性、認証/認可、機密データをチェック
```

**重要**: 両方のレビュアーを並列で起動してレビュー時間を短縮。

### Step 3: 結果の集約

両方のレビューが完了したら結果を集約：

```markdown
# 統合レビュー結果

## コード品質（code-reviewer）
- Critical: X件
- Warning: X件

## セキュリティ（security-reviewer）
- Critical: X件
- Warning: X件

## 総合判定
→ 両方 Critical なし: マージ可能
→ いずれか Critical あり: 修正必須
```

### Step 4: Critical 発見時の対応確認

Critical が見つかった場合、**AskUserQuestion** で対応を確認：

```
質問: Critical な問題が見つかりました。どう対応しますか？

選択肢:
1. 今すぐ修正（推奨） - 問題を修正して再レビュー
2. 詳細を確認 - 問題の詳細説明を表示
3. 後で対応 - 問題を記録して一旦終了
4. 無視して続行 - リスクを承知で続行
```

---

## 完了時の出力

### Critical なしの場合

```
✅ コードレビュー完了（並列実行）

📊 コード品質
   🟢 Critical: なし
   🟡 Warning: X件

🔒 セキュリティ
   🟢 Critical: なし
   🟡 Warning: X件

→ マージ可能
```

**AskUserQuestion** でコード簡素化を提案：

```
質問: レビュー完了しました。コードを簡素化しますか？

選択肢:
1. 簡素化する - code-simplifier を実行
2. スキップ（推奨） - このまま完了
```

**「スキップ」または簡素化完了後:**
```
<promise>DONE</promise>
```

### Critical ありの場合

```
⚠️ コードレビュー完了（並列実行）

📊 コード品質
   🔴 Critical: X件 ← 要修正
   🟡 Warning: X件

🔒 セキュリティ
   🔴 Critical: X件 ← 要修正
   🟡 Warning: X件

→ 修正が必要
```

Critical がある場合は、問題点と修正方法を具体的に提案してください。

---

**レビューを開始します。変更差分を確認し、code-reviewer と security-reviewer を並列で起動してください。**
