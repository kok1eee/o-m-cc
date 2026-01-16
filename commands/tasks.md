---
description: "タスク分解（SDD Phase 3）"
argument-hint: ""
allowed-tools: [Task, Read, Write, Glob, Grep, AskUserQuestion]
model: sonnet
---

# Tasks - タスク分解

**SDD Phase 3**: design.md に基づいて実装タスクを分解します。

---

## 前提条件

`.plan/design.md` が存在すること。

存在しない場合は、先に `/design` を実行してください。

---

## 実行内容

**planner subagent** を使用してタスクを分解してください。

```
Task tool で planner subagent を呼び出し：

1. 設計の確認
   - .plan/design.md を読み込み
   - コンポーネント構成を把握

2. タスク分解
   - 各コンポーネントの実装タスク
   - 依存関係の特定
   - 実行順序の決定
   - 見積もり（S/M/L）

3. 出力
   - .plan/tasks.md を作成
```

---

## 出力ファイル

`.plan/tasks.md`

```markdown
# 実装タスク: [機能名]

## 概要
- 総タスク数: X件
- 見積合計: S:X, M:X, L:X

## タスク一覧
### Task 1: [タスク名]
- 説明: ...
- 対応要件: FR-X
- 依存: なし
- 見積: S

## 依存関係図
...

## 実行順序
...
```

---

## 完了時の出力

タスク分解が完了したら、以下を出力してください：

```
✅ タスク分解完了
   📄 .plan/tasks.md

   - 総タスク数: X件
   - 見積: S:X, M:X, L:X
```

## 次のステップ確認

タスク分解完了後、**AskUserQuestion** で次のアクションを確認：

```
質問: タスク分解が完了しました。次のステップは？

選択肢:
1. 実装を開始（推奨） - タスクを順次実行
2. タスクを修正 - フィードバックを反映
3. ここで終了 - 後で続行
```

---

**planner subagent でタスク分解を開始してください。**
