---
description: "Agent Teams で code-reviewer と security-reviewer を並列実行してコード品質・セキュリティをチェック。「レビューして」「コードを確認して」で使用。"
argument-hint: "[specific files or 'all']"
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion, TeammateTool]
model: sonnet
context: fork
---

# Review Command - コードレビュー（Agent Teams 並列実行）

コード品質とセキュリティを **Agent Teams** で**同時にチェック**します。

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

### Step 2: レビューチーム作成

**TeammateTool の spawnTeam でレビューチームを作成：**

```
TeammateTool: spawnTeam
  teamName: "review"
```

### Step 3: Reviewer Teammates Spawn

**2つの teammate を同時に spawn：**

```
1. TeammateTool: spawnTeammate
   teamName: "review"
   name: "code-reviewer"
   prompt: |
     agents/code-reviewer.md の指示に従い、以下の変更差分をレビューしてください。

     ## レビュー対象
     [変更差分を含める]

     ## チェック項目
     - バグ、ロジックエラー
     - コード複雑性、保守性
     - プロジェクト規約への準拠
     - Confidence Scoring で高優先度の問題のみ報告

     ## チーム連携
     - 発見した問題を security-reviewer teammate にもメッセージで共有
     - セキュリティに関連する発見があれば security-reviewer に相談
     - 完了したら Lead に結果サマリーをメッセージ送信

2. TeammateTool: spawnTeammate
   teamName: "review"
   name: "security-reviewer"
   prompt: |
     agents/security-reviewer.md の指示に従い、以下の変更差分のセキュリティをチェックしてください。

     ## レビュー対象
     [変更差分を含める]

     ## チェック項目
     - OWASP Top 10 ベースのセキュリティチェック
     - 脆弱性、認証/認可、機密データ
     - Trail of Bits パターン（Rationalizations, Insecure Defaults, Sharp Edges）

     ## チーム連携
     - 発見した問題を code-reviewer teammate にもメッセージで共有
     - コード品質に関連する発見があれば code-reviewer に相談
     - 完了したら Lead に結果サマリーをメッセージ送信
```

**重要**: 両方の teammate を同時に spawn してレビュー時間を短縮。
Teammates は互いの発見をメッセージで共有・議論できます。

### Step 4: 結果の集約

両方の teammate からの報告を集約：

```markdown
# 統合レビュー結果

## コード品質（code-reviewer teammate）
- Critical: X件
- Warning: X件

## セキュリティ（security-reviewer teammate）
- Critical: X件
- Warning: X件

## 総合判定
→ 両方 Critical なし: マージ可能
→ いずれか Critical あり: 修正必須
```

### Step 5: Critical 発見時の対応確認

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
✅ コードレビュー完了（Agent Teams 並列実行）

📊 コード品質
   🟢 Critical: なし
   🟡 Warning: X件

🔒 セキュリティ
   🟢 Critical: なし
   🟡 Warning: X件

→ マージ可能

<promise>DONE</promise>
```

### Critical ありの場合

```
⚠️ コードレビュー完了（Agent Teams 並列実行）

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

**レビューを開始します。変更差分を確認し、Agent Teams で code-reviewer と security-reviewer を並列 spawn してください。**
