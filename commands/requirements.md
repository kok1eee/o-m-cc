---
description: "要件定義を作成（SDD Phase 1）"
argument-hint: "<feature description>"
allowed-tools: [Task, Read, Write, Glob, Grep, WebSearch, AskUserQuestion]
model: sonnet
---

# Requirements - 要件定義

**SDD Phase 1**: 機能の要件を整理し、requirements.md を作成します。

## 機能

$ARGUMENTS

---

## Step 0: 要件の明確化

機能説明が曖昧な場合は、**AskUserQuestion** で確認してください：

```
確認すべき点（必要に応じて）:
- 対象ユーザーは？（管理者/一般ユーザー/両方）
- 優先する品質は？（パフォーマンス/セキュリティ/UX）
- 既存機能との関係は？（新規/拡張/置換）
- スコープは？（MVP/フル機能）
```

**明確な場合はスキップして次へ進む。**

---

## 実行内容

**analyst subagent** を使用して要件定義を作成してください。

```
Task tool で analyst subagent を呼び出し：

1. 現状分析
   - 既存コードベースの構造
   - 技術スタックと制約
   - 関連する既存機能

2. 要件整理
   - 機能要件（FR-1, FR-2, ...）
   - 非機能要件（NFR-1, NFR-2, ...）
   - 制約条件
   - 受け入れ基準

3. 出力
   - .plan/requirements.md を作成
```

---

## 出力ファイル

`.plan/requirements.md`

```markdown
# 要件定義: [機能名]

## 機能要件
### FR-1: [要件名]
- 説明: ...
- 受け入れ基準: ...

## 非機能要件
### NFR-1: [要件名]
- カテゴリ: ...
- 説明: ...

## 制約条件
- ...
```

---

## 完了時の出力

要件定義が完了したら、以下を出力してください：

```
✅ 要件定義完了
   📄 .plan/requirements.md

   - 機能要件: X件
   - 非機能要件: X件
```

## 次のステップ確認

要件定義完了後、**AskUserQuestion** で次のアクションを確認：

```
質問: 要件定義が完了しました。次のステップは？

選択肢:
1. 設計へ進む（推奨） - Phase 2 を実行
2. 要件を修正 - フィードバックを反映
3. ここで終了 - 後で続行
```

**「ここで終了」選択時のみ:**
```
<promise>DONE</promise>
```

---

**analyst subagent で要件定義を開始してください。**
