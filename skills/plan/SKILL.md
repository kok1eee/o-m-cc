---
name: plan
description: "Agent Teams で要件→設計→タスクを一括実行する仕様駆動開発フロー。新機能の実装、大規模リファクタリング、アーキテクチャ変更など、複数ステップの作業を始めるときに使う。「計画して」「設計から始めて」「この機能を実装したい」「要件を整理して」「タスクに分解して」で発動。"
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
│  researcher ◄──────► analyst (Lead) ◄──────► scout   │
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
```

**Phase 1 は Discovery Council（3エージェント同時 spawn + peer-to-peer 共有）**
**Phase 2-3 は Pipeline 型（順次実行）**

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

Phase 1 集約ルール:
- `all("報告完了")` → analyst が requirements.md を最終確定

```
1. TeammateTool: spawnTeammate
   teamName: "planning"
   name: "researcher"
   prompt: |
     ## エージェント定義
     agents/researcher.md の指示に従ってください。

     ## コンテキスト
     - タスク: 以下の機能に関連する技術情報・実装パターン・既存知見を調査
     - 機能: $ARGUMENTS

     ## 入力
     - MEMORY.md（プロジェクトの蓄積知識）
     - コードベース内の既存実装（Glob/Grep）
     - 必要に応じて外部ドキュメント（WebSearch）

     ## チーム連携
     あなたは Discovery Council のメンバーです。
     - 知見が見つかったら analyst と scout の両方にメッセージで共有してください
     - analyst・scout から追加調査を依頼されたら対応してください
     - 調査完了時、全知見のサマリーを analyst に送信してください

     ## 出力
     関連する知見が見つかったら analyst と scout にメッセージで報告。
     見つからなければ「関連する既存知見なし」と報告。

2. TeammateTool: spawnTeammate
   teamName: "planning"
   name: "analyst"
   prompt: |
     ## エージェント定義
     agents/analyst.md の指示に従ってください。

     ## コンテキスト
     - タスク: 以下の機能の要件定義を作成
     - 機能: $ARGUMENTS

     ## 入力
     - ユーザーの機能要求（上記）
     - scout からのギャップ報告
     - researcher からの調査知見

     ## チーム連携
     あなたは Discovery Council の Lead です。
     - 要件ドラフトの主要部分ができたら scout・researcher にメッセージで共有し、フィードバックを促してください
     - scout からのギャップ報告を受け取り、要件に反映してください
     - researcher からの調査知見を受け取り、要件に反映してください
     - 全員の findings を統合してから requirements.md を最終確定してください

     ## 確定前チェック
     requirements.md を Write する前に、scout と researcher からの報告を受信済みか確認してください。
     未受信の場合はメッセージで状況を確認してください。

     ## 出力
     - plan/requirements.md に要件定義を出力
     - 完了したら Lead にメッセージで報告

3. TeammateTool: spawnTeammate
   teamName: "planning"
   name: "scout"
   prompt: |
     ## エージェント定義
     agents/scout.md の指示に従ってください。

     ## コンテキスト
     - タスク: 以下の機能について、ギャップ分析を実施
     - 機能: $ARGUMENTS

     ## 入力
     - ユーザーの元の要求（上記）
     - コードベースを直接調査（Glob, Grep, Read）

     ## チーム連携
     あなたは Discovery Council のメンバーです。
     - ギャップを発見したら analyst にメッセージで即共有してください
     - researcher から技術知見を受け取ったら分析に反映してください
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
- researcher は技術知見を検索し、見つけ次第 analyst・scout に共有
- scout は requirements.md を待たず、ユーザーの要求とコードベースから直接ギャップ分析
- analyst は自身の分析 + scout のギャップ報告 + researcher の知見を統合して requirements.md を確定

---

## Step 3: Phase 2 - 設計

**Discovery Council 完了後、designer teammate を spawn：**

```
TeammateTool: spawnTeammate
  teamName: "planning"
  name: "designer"
  prompt: |
    ## エージェント定義
    agents/designer.md の指示に従ってください。

    ## コンテキスト
    - タスク: requirements.md を基にアーキテクチャ設計書を作成

    ## 入力
    - plan/requirements.md

    ## チーム連携
    - 完了したら Lead にメッセージで報告

    ## 出力
    - plan/design.md に設計書を出力
```

---

## Step 4: Phase 3 - タスク分解

**design.md 完了後、planner teammate を spawn：**

```
TeammateTool: spawnTeammate
  teamName: "planning"
  name: "planner"
  prompt: |
    ## エージェント定義
    agents/planner.md の指示に従ってください。

    ## コンテキスト
    - タスク: design.md を基にタスクを分解

    ## 入力
    - plan/design.md
    - plan/requirements.md

    ## チーム連携
    - 完了したら Lead にメッセージで報告

    ## 出力
    - plan/tasks.md にタスクリストを出力
```

---

## 出力ファイル

```
plan/
├── requirements.md  # 要件定義
├── design.md        # 設計書
└── tasks.md         # 実装タスク
```

---

## Step 5: 実行方式の自動選択

planner 完了後、tasks.md のタスクを分析して実行方式を**自動で決定**する。人間に判断を委ねない。

### 判定基準

以下の**すべて**に該当 → **`/batch` で並列実行**：
- 独立した同種の変更が **5件以上**
- 各タスクが **他のタスクに依存しない**（並列実行可能）
- 各タスクが **同じパターンの繰り返し**（import 書き換え、命名変更、テスト追加など）

それ以外 → **通常の Sisyphus Loop で直列実行**

### /batch 判定の場合

計画完了を出力した後、**自動的に `/batch` を実行**する。止まらない。

```
✅ 計画完了（Agent Teams）
   📄 plan/requirements.md
   📄 plan/design.md
   📄 plan/tasks.md

   - タスク: X件 (S:X, M:X, L:X)
   - 実行方式: /batch（独立した同種タスク X件を検出）

→ /batch で並列実行を開始します
```

その後、`/batch` を実行して計画に基づいた並列実装に進む。

### 通常の場合

```
✅ 計画完了（Agent Teams）
   📄 plan/requirements.md
   📄 plan/design.md
   📄 plan/tasks.md

   - タスク: X件 (S:X, M:X, L:X)
   - 実行方式: Sisyphus Loop（依存関係のあるタスク）

計画に沿って実装を開始します。
```

その後、tasks.md に基づいて直列で実装を進める。

---

**Step 1 からチーム作成し、Discovery Council（3エージェント同時 spawn）を開始してください。**
