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

**デフォルト: 一括実行**（Discovery Council → Design → Tasks を連続実行）

---

## 実行フロー（Council + Pipeline ハイブリッド）

```
┌─────────────────────────────────────────────────────┐
│              Phase 1: Discovery Council               │
│                                                       │
│  learnings-researcher ◄─► analyst (Lead) ◄─► scout   │
│  peer-to-peer で findings を共有                      │
│  analyst が統合して requirements.md を確定             │
└─────────────────────────────────────────────────────┘
          │
          ▼ requirements.md
┌──────────────┐    ┌──────────────┐
│  Phase 2     │───▶│  Phase 3     │
│  設計        │    │  タスク分解  │
│  (designer)  │    │  (planner)   │
└──────────────┘    └──────────────┘
       │                   │
       ▼                   ▼
   design.md           tasks.md
                           │
                           ▼
┌──────────────────────────────────────────┐
│         Phase 4: Review Council           │
│                                           │
│  critic (Lead) ◄─► advisor               │
│  peer-to-peer で指摘を共有               │
│  critic が統合してレビュー結果を確定      │
└──────────────────────────────────────────┘
```

**Phase 1 は Discovery Council（3エージェント同時 spawn + peer-to-peer 共有）**
**Phase 2-3 は Pipeline 型（順次実行）**
**Phase 4 は Review Council（2エージェント同時 spawn + peer-to-peer 共有）**

---

## Step 1: プランニングチーム作成

**TeammateTool の spawnTeam でチームを作成：**

```
TeammateTool: spawnTeam
  teamName: "planning"
```

---

## Step 2: Phase 1 - Discovery Council

**3つの teammate を同時 spawn：**

```
1. TeammateTool: spawnTeammate
   teamName: "planning"
   name: "learnings-researcher"
   prompt: |
     agents/learnings-researcher.md の指示に従ってください。

     ## タスク
     以下の機能に関連する過去の知見を検索してください：
     $ARGUMENTS

     ## 検索方式
     1. ToolSearch で claude-mem MCP ツールの可用性を確認
     2. 利用可能なら search で関連する過去の操作をセマンティック検索
     3. 補完として spec/standards/learned/ を Grep 検索
     4. 結果をマージして報告（検索方式も併記）

     ## Council 連携（peer-to-peer）
     あなたは Discovery Council のメンバーです。
     - 知見が見つかったら analyst と scout の両方にメッセージで共有してください
     - analyst・scout から追加検索を依頼されたら対応してください
     - 検索完了時、全知見のサマリーを analyst に送信してください

     ## 出力
     関連する学びが見つかったら analyst と scout にメッセージで報告。
     見つからなければ「関連する過去の学びなし」と報告。

2. TeammateTool: spawnTeammate
   teamName: "planning"
   name: "analyst"
   prompt: |
     agents/analyst.md の指示に従ってください。

     ## タスク
     以下の機能の要件定義を作成してください：
     $ARGUMENTS

     ## Council Lead（peer-to-peer）
     あなたは Discovery Council の Lead です。
     - 要件ドラフトの主要部分ができたら scout・learnings-researcher にメッセージで共有し、フィードバックを促してください
     - scout からのギャップ報告を受け取り、要件に反映してください
     - learnings-researcher からの過去知見を受け取り、要件に反映してください
     - 全員の findings を統合してから requirements.md を最終確定してください

     ## 確定前チェック
     requirements.md を Write する前に、scout と learnings-researcher からの報告を受信済みか確認してください。
     未受信の場合はメッセージで状況を確認してください。

     ## 出力
     - spec/plan/requirements.md に要件定義を出力
     - 完了したら Lead にメッセージで報告

3. TeammateTool: spawnTeammate
   teamName: "planning"
   name: "scout"
   prompt: |
     agents/scout.md の指示に従ってください。

     ## タスク
     以下の機能について、ギャップ分析を行ってください：
     $ARGUMENTS

     ## 入力
     - ユーザーの元の要求（上記）
     - コードベースを直接調査（Glob, Grep, Read）

     ## Council 連携（peer-to-peer）
     あなたは Discovery Council のメンバーです。
     - ギャップを発見したら analyst にメッセージで即共有してください
     - learnings-researcher から過去の知見を受け取ったら分析に反映してください
     - analyst から追加調査を依頼されたら対応してください
     - 分析完了時、ギャップ一覧を analyst に送信してください

     ## 原則
     - requirements.md の完成を待たず、ユーザーの要求とコードベースから直接分析を開始
     - Critical な曖昧点は AskUserQuestion で確認
     - 回答がなければ仮定を記録して進む
     - フローをブロックしない

     ## 出力
     - 発見した漏れ・補完事項を analyst にメッセージで報告
```

**Discovery Council の動作:**
- 3エージェントが同時に作業を開始
- learnings-researcher は過去の知見を検索し、見つけ次第 analyst・scout に共有
- scout は requirements.md を待たず、ユーザーの要求とコードベースから直接ギャップ分析
- analyst は自身の分析 + scout のギャップ報告 + learnings-researcher の知見を統合して requirements.md を確定

---

## Step 3: Phase 2 - 設計

**Discovery Council 完了後、designer teammate を spawn：**

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

    ## 出力
    - spec/plan/design.md に設計書を出力
    - 完了したら Lead にメッセージで報告
```

---

## Step 4: Phase 3 - タスク分解

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

## Step 5: Phase 4 - Review Council

**planner 完了後、2つの teammate を同時 spawn：**

```
1. TeammateTool: spawnTeammate
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

     ## Council Lead（peer-to-peer）
     あなたは Review Council の Lead です。
     - 主要な指摘を advisor にメッセージで共有し、戦略的観点からのフィードバックを促してください
     - advisor からのアーキテクチャ懸念・代替案を受け取り、レビューに反映してください
     - 両者の指摘を統合してレビューレポートを確定してください

     ## チェック項目
     - 漏れや矛盾がないか
     - スコープ・リスク・実現可能性

     ## 出力
     - レビュー結果を Lead にメッセージで報告

2. TeammateTool: spawnTeammate
   teamName: "planning"
   name: "advisor"
   prompt: |
     agents/advisor.md の指示に従ってください。

     ## タスク
     計画全体を戦略的・アーキテクチャ的観点からレビューしてください。

     ## 入力
     - spec/plan/requirements.md
     - spec/plan/design.md
     - spec/plan/tasks.md

     ## Council 連携（peer-to-peer）
     あなたは Review Council のメンバーです。
     - アーキテクチャ懸念や代替案を critic にメッセージで共有してください
     - critic からの確認依頼には思考フレームワークを活用して分析してください
     - 分析完了時、戦略的観点の指摘一覧を critic に送信してください

     ## チェック観点
     - アーキテクチャの妥当性
     - スケーラビリティ・保守性の懸念
     - より良い代替アプローチの有無

     ## 出力
     - 戦略的観点の指摘を critic にメッセージで報告
```

**Review Council の動作:**
- critic と advisor が同時に計画全体をレビュー
- critic は完全性・実現可能性・リスク・明確性を検証
- advisor はアーキテクチャ・戦略的妥当性を検証
- 両者が peer-to-peer で指摘を共有し、critic が統合してレビュー結果を確定

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

**Step 1 からチーム作成し、Discovery Council（3エージェント同時 spawn）を開始してください。**
