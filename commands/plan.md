---
description: "Agent Teams で要件→設計→タスクを一括実行する仕様駆動開発フロー。「計画して」「設計から始めて」「この機能を実装したい」で使用。"
argument-hint: "<feature description>"
allowed-tools: [Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TaskCreate, TaskUpdate, AskUserQuestion, TeammateTool]
model: opus
context: fork
---

# Plan - 仕様駆動開発オーケストレーター（Agent Teams）

**要件 → 設計 → タスク** を Agent Teams で一括実行します。

## 機能

$ARGUMENTS

---

## 実行方式

**デフォルト: 一括実行**（要件→設計→タスクを Phase 0.5-3 連続実行）

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

**Phase 0.5 と Phase 1 は並列実行（Agent Teams）**

---

## Step 1: プランニングチーム作成

**TeammateTool の spawnTeam でチームを作成：**

```
TeammateTool: spawnTeam
  teamName: "planning"
```

---

## Step 2: 並列 Phase（0.5 + 1）

**2つの teammate を同時 spawn：**

```
1. TeammateTool: spawnTeammate
   teamName: "planning"
   name: "learnings-researcher"
   prompt: |
     agents/learnings-researcher.md の指示に従ってください。

     ## タスク
     以下の機能に関連する過去の知見を検索してください：
     $ARGUMENTS

     ## 検索対象
     - spec/standards/learned/ を検索
     - 関連するパターン・決定・アンチパターンを抽出

     ## 出力
     関連する学びが見つかったら Lead にメッセージで報告。
     見つからなければ「関連する過去の学びなし」と報告。

2. TeammateTool: spawnTeammate
   teamName: "planning"
   name: "analyst"
   prompt: |
     agents/analyst.md の指示に従ってください。

     ## タスク
     以下の機能の要件定義を作成してください：
     $ARGUMENTS

     ## 出力
     - spec/plan/requirements.md に要件定義を出力
     - 完了したら Lead にメッセージで報告
```

**learned/ が存在しない、または空の場合:** learnings-researcher は即完了。
analyst はlearnings-researcher の結果を待たず並行して作業可能。

---

## Step 3: Phase 1.5 - ギャップ分析

**Phase 0.5 + 1 完了後、scout teammate を spawn：**

```
TeammateTool: spawnTeammate
  teamName: "planning"
  name: "scout"
  prompt: |
    agents/scout.md の指示に従ってください。

    ## タスク
    requirements.md を読み込み、漏れ・曖昧点を発見してください。

    ## 入力
    - spec/plan/requirements.md
    - learnings-researcher からの過去の知見（あれば）

    ## 原則
    - Critical な曖昧点は AskUserQuestion で確認
    - 回答がなければ仮定を記録して進む
    - フローをブロックしない

    ## 出力
    - 発見した漏れ・補完事項を Lead にメッセージで報告
```

---

## Step 4: Phase 2 - 設計

**scout 完了後、designer teammate を spawn：**

```
TeammateTool: spawnTeammate
  teamName: "planning"
  name: "designer"
  prompt: |
    agents/designer.md の指示に従ってください。

    ## タスク
    requirements.md を基にアーキテクチャ設計書を作成してください。

    ## 入力
    - spec/plan/requirements.md
    - scout からの補完事項（あれば）

    ## 出力
    - spec/plan/design.md に設計書を出力
    - 完了したら Lead にメッセージで報告
```

---

## Step 5: Phase 3 - タスク分解

**design.md 完了後、planner teammate を spawn：**

```
TeammateTool: spawnTeammate
  teamName: "planning"
  name: "planner"
  prompt: |
    agents/planner.md の指示に従ってください。

    ## タスク
    design.md を基にタスクを分解してください。

    ## 入力
    - spec/plan/design.md
    - spec/plan/requirements.md

    ## 出力
    - spec/plan/tasks.md にタスクリストを出力
    - spec/plan/orchestration.yml にオーケストレーション設定を出力
    - 完了したら Lead にメッセージで報告
```

---

## Phase 4: レビュー（任意）

**critic teammate で計画全体をレビュー：**

```
TeammateTool: spawnTeammate
  teamName: "planning"
  name: "critic"
  prompt: |
    agents/critic.md の指示に従ってください。

    ## タスク
    計画全体をレビューしてください。

    ## 入力
    - spec/plan/requirements.md
    - spec/plan/design.md
    - spec/plan/tasks.md

    ## チェック項目
    - 漏れや矛盾がないか
    - スコープ・リスク・実現可能性

    ## 出力
    - レビュー結果を Lead にメッセージで報告
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
✅ 計画完了（Agent Teams）
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

**Step 1 からチーム作成し、Phase 0.5 + 1 の並列実行を開始してください。**
