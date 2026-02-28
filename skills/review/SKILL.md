---
name: review
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
     ## エージェント定義
     agents/code-reviewer.md の指示に従ってください。

     ## 参照ポリシー
     facets/policies/confidence-scoring.md を Read して適用してください。

     ## コンテキスト
     - タスク: $ARGUMENTS のコードレビュー
     - スコープ: コード品質（バグ、複雑性、保守性）

     ## 入力
     [変更差分を含める]

     ## チーム連携
     - 発見した問題を security-reviewer teammate にもメッセージで共有
     - セキュリティに関連する発見があれば security-reviewer に相談
     - 完了したら Lead に結果サマリーをメッセージ送信

     ## 出力
     - Confidence 80+ の問題のみ Critical/Warning で報告
     - agents/code-reviewer.md の出力フォーマットに従う

2. TeammateTool: spawnTeammate
   teamName: "review"
   name: "security-reviewer"
   prompt: |
     ## エージェント定義
     agents/security-reviewer.md の指示に従ってください。

     ## 参照ポリシー
     facets/policies/confidence-scoring.md を Read して適用してください。

     ## コンテキスト
     - タスク: $ARGUMENTS のセキュリティレビュー
     - スコープ: OWASP Top 10 + Trail of Bits パターン

     ## 入力
     [変更差分を含める]

     ## チーム連携
     - 発見した問題を code-reviewer teammate にもメッセージで共有
     - コード品質に関連する発見があれば code-reviewer に相談
     - 完了したら Lead に結果サマリーをメッセージ送信

     ## 出力
     - Confidence 80+ の問題のみ Critical/Warning で報告
     - agents/security-reviewer.md の出力フォーマットに従う
```

**重要**: 両方の teammate を同時に spawn してレビュー時間を短縮。
Teammates は互いの発見をメッセージで共有・議論できます。

### Step 4: 結果の集約

両方の teammate からの報告を集約：

#### 集約ルール

- `all("Critical なし")` → マージ可能
- `any("Critical あり")` → 修正必須。Step 5 へ

```markdown
# 統合レビュー結果

## コード品質（code-reviewer teammate）
- Critical: X件
- Warning: X件

## セキュリティ（security-reviewer teammate）
- Critical: X件
- Warning: X件

## 総合判定
→ all("Critical なし"): マージ可能
→ any("Critical あり"): 修正必須
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

### Critical なしの場合 → Step 6 へ

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

### Step 6: /simplify で品質改善

レビューで Critical がない（または修正済み）場合、`/simplify` を実行してコードを自動改善する。

`/simplify` は以下の3観点で変更コードをチェックし、問題があれば自動修正する：
- **再利用**: 既存ユーティリティとの重複がないか
- **品質**: 冗長な状態管理、コピペコード、マジックナンバーがないか
- **効率**: 不要な計算、並列化可能な直列処理がないか

```
/simplify
```

---

## 完了時の出力

```
✅ コードレビュー完了（Agent Teams 並列実行 + /simplify）

📊 コード品質
   🟢 Critical: なし
   🟡 Warning: X件

🔒 セキュリティ
   🟢 Critical: なし
   🟡 Warning: X件

🔧 /simplify
   修正: X件

→ マージ可能

<promise>DONE</promise>
```

---

**レビューを開始します。変更差分を確認し、Agent Teams で code-reviewer と security-reviewer を並列 spawn してください。**
