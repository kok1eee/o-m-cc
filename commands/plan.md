---
description: "仕様駆動の計画フロー（要件 → 設計 → タスク 一括実行）"
argument-hint: "<feature description>"
allowed-tools: [Task, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TodoWrite]
model: opus
---

# Plan - 仕様駆動開発オーケストレーター

**要件 → 設計 → タスク** を一括で実行します。

個別に実行したい場合は `/requirements`, `/design`, `/tasks` を使用してください。

## 機能

$ARGUMENTS

---

## 実行フロー

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Phase 1     │───▶│  Phase 2     │───▶│  Phase 3     │
│  要件定義    │    │  設計        │    │  タスク分解  │
│  (analyst)   │    │  (designer)  │    │  (planner)   │
└──────────────┘    └──────────────┘    └──────────────┘
       │                   │                   │
       ▼                   ▼                   ▼
  requirements.md      design.md          tasks.md
```

---

## Phase 1: 要件定義

**analyst subagent** で要件定義を作成。

```
Task tool で analyst subagent を呼び出し：
- 現状分析
- 要件整理（FR/NFR）
- 出力: .plan/requirements.md
```

**完了を待ってから Phase 2 へ。**

---

## Phase 2: 設計

**designer subagent** で設計書を作成。

```
Task tool で designer subagent を呼び出し：
- requirements.md を読み込み
- アーキテクチャ設計
- 出力: .plan/design.md
```

**完了を待ってから Phase 3 へ。**

---

## Phase 3: タスク分解

**planner subagent** でタスクを分解。

```
Task tool で planner subagent を呼び出し：
- design.md を読み込み
- タスク分解・依存関係整理
- 出力: .plan/tasks.md
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
.plan/
├── requirements.md  # 要件定義
├── design.md        # 設計書
└── tasks.md         # 実装タスク
```

---

## 完了時の出力

計画が完了したら、以下を出力してください：

```
✅ 計画完了
   📄 .plan/requirements.md
   📄 .plan/design.md
   📄 .plan/tasks.md

   - 機能要件: X件
   - コンポーネント: X個
   - タスク: X件 (S:X, M:X, L:X)

計画完了。「実装を開始して」と依頼してください。
```

---

**Phase 1 を開始します。analyst subagent で要件定義を作成してください。**
