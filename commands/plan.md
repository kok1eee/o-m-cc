---
description: "仕様駆動の計画フロー（要件 → 設計 → タスク 一括実行）"
argument-hint: "<feature description>"
allowed-tools: [Task, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TaskCreate, TaskUpdate, AskUserQuestion]
model: opus
context: fork
---

# Plan - 仕様駆動開発オーケストレーター

**要件 → 設計 → タスク** を一括で実行します。

## 機能

$ARGUMENTS

---

## 実行方式

**デフォルト: 一括実行**（要件→設計→タスクを Phase 1-3 連続実行）

---

## 実行フロー

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Phase 0.5   │───▶│  Phase 1     │───▶│  Phase 1.5   │───▶│  Phase 2     │───▶│  Phase 3     │
│  学び検索    │    │  要件定義    │    │  ギャップ    │    │  設計        │    │  タスク分解  │
│  (learnings) │    │  (analyst)   │    │  (scout)     │    │  (designer)  │    │  (planner)   │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
       │                   │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼                   ▼
  過去の知見を確認   requirements.md    追加質問で補完       design.md          tasks.md
```

---

## Phase 0.5: 過去の学び検索

**learnings-researcher subagent** で関連する過去の知見を検索。

```
Task tool で learnings-researcher subagent を呼び出し：
- タスク説明: $ARGUMENTS
- spec/standards/learned/ を検索
- 関連するパターン・決定・アンチパターンを抽出
```

**learned/ が存在しない、または空の場合はスキップして Phase 1 へ。**
関連する学びが見つかった場合、以降の Phase で考慮事項として活用する。

---

## Phase 1: 要件定義

**analyst subagent** で要件定義を作成。

```
Task tool で analyst subagent を呼び出し：
- 現状分析
- 要件整理（FR/NFR）
- 出力: spec/plan/requirements.md
```

**完了を待ってから Phase 1.5 へ。**

---

## Phase 1.5: ギャップ分析

**scout subagent** で漏れを発見し、追加質問。

```
Task tool で scout subagent を呼び出し：
- requirements.md を読み込み
- 曖昧な点・聞き漏れを発見
- AskUserQuestion で追加確認
- Critical な曖昧点を AskUserQuestion で確認
- 回答がなければ仮定を記録して進む
```

**scout の原則:**
- 読み取り専用（プランモード互換）
- 曖昧点は質問するが、フローをブロックしない
- 仮定で進んだ場合は出力に明記

---

## Phase 2: 設計

**designer subagent** で設計書を作成。

```
Task tool で designer subagent を呼び出し：
- requirements.md を読み込み
- アーキテクチャ設計
- 出力: spec/plan/design.md
```

**完了を待ってから Phase 3 へ。**

---

## Phase 3: タスク分解

**planner subagent** でタスクを分解。

```
Task tool で planner subagent を呼び出し：
- design.md を読み込み
- タスク分解・依存関係整理
- 出力: spec/plan/tasks.md
```

---

## Phase 4: レビュー（任意）

**critic subagent** で計画全体をレビュー。

```
Task tool で critic subagent を呼び出し：
- requirements.md, design.md, tasks.md をレビュー
- 漏れや矛盾がないか確認
```

---

## 出力ファイル

```
spec/plan/
├── requirements.md  # 要件定義
├── design.md        # 設計書
└── tasks.md         # 実装タスク
```

---

## 完了時の出力

計画が完了したら、以下を出力してください：

```
✅ 計画完了
   📄 spec/plan/requirements.md
   📄 spec/plan/design.md
   📄 spec/plan/tasks.md

   - 機能要件: X件
   - コンポーネント: X個
   - タスク: X件 (S:X, M:X, L:X)

計画完了。「実装を開始して」と依頼してください。

<promise>DONE</promise>
```

---

**Phase 0.5 から一括実行を開始してください。**
