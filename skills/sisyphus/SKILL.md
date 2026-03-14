---
name: sisyphus
description: "計画→実装→品質ゲートまで止まらない Sisyphus ワークフロー。Agent Teams で要件→設計→タスク分解→実装→quality-gate を一括実行。「計画して」「設計から始めて」「この機能を実装したい」「要件を整理して」「タスクに分解して」で発動。"
argument-hint: "<feature description>"
allowed-tools: [Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TaskCreate, TaskUpdate, AskUserQuestion, Agent, TeamCreate, TeamDelete, SendMessage]
model: opus
context: fork
---

# Sisyphus - 仕様駆動開発オーケストレーター（Agent Teams）

**要件 → 設計 → タスク** を Agent Teams で一括実行します。

## 機能

$ARGUMENTS

---

## 実行方式

### Headless モード判定

**`-p`（headless）モードで実行されている場合、全承認ゲートをスキップする。**

判定方法: `AskUserQuestion` ツールが `allowed-tools` に含まれていても、headless 環境では応答する人間がいない。以下のいずれかで判定：
- 環境変数 `CLAUDE_NON_INTERACTIVE=1` がセットされている
- 最初のユーザーメッセージが `-p` 経由の単一プロンプトである（会話履歴がない）

**Headless の場合**: 全承認ゲート（Step 2.5, 3.5, 4.5）を自動承認。AskUserQuestion を使わない。旧 Sisyphus（完全自律）として動作。

**対話モードの場合**: 以下の通り承認ゲート付きで動作。

---

**計画フェーズは承認ゲート付き（対話時のみ）、実装フェーズは止まらない。**

対話モードでは計画の各ステップで人間に確認を求め、方向性を合わせてから次に進む。
Headless モードでは全自動で計画→実装→完了まで止まらない。

---

## 実行フロー（Council + Pipeline ハイブリッド + 承認ゲート）

```
┌─────────────────────────────────────────────────────┐
│              Phase 1: Discovery Council               │
│                                                       │
│  researcher ◄──────► analyst ◄──────► scout            │
│  peer-to-peer で findings を相互検証                   │
│  analyst が統合して requirements.md を確定              │
└─────────────────────────────────────────────────────┘
          │
          ▼ requirements.md
    ┌──────────────┐
    │ 🚦 承認ゲート │ ← 曖昧点あり → 聞く / 明確 → 自動承認
    └──────────────┘
          │
          ▼
┌──────────────┐
│  Phase 2     │
│  設計        │
│  (designer)  │
└──────────────┘
          │
          ▼ design.md
    ┌──────────────┐
    │ 🚦 承認ゲート │ ← 判断ポイントあり → 聞く / 明確 → 自動承認
    └──────────────┘
          │
          ▼
┌──────────────┐
│  Phase 3     │
│  タスク分解  │
│  (planner)   │
└──────────────┘
          │
          ▼ TaskCreate
    ┌──────────────┐
    │ 🚦 承認ゲート │ ← 確認事項あり → 聞く / 明確 → 自動承認
    └──────────────┘
          │
          ▼
    Phase 4: 実装（Sisyphus Loop — 止まらない）
```

**Phase 1 は Discovery Council（3エージェント同時 spawn + peer-to-peer 共有）**
**Phase 2-3 は Pipeline 型（順次実行・foreground spawn）**

> **重要**: Phase 2-3 の designer/planner は **foreground（デフォルト）で spawn** すること。background で spawn すると待機中に「やることがない」と判断して終了しようとする。Discovery Council の 3 agent は同時 spawn（background）が正しいが、Pipeline 型は foreground で完了を待ってから次に進む。

---

## Step 0: プランニングチーム作成

**既存チームがあれば削除してから作成（前回の残骸 cleanup）：**

```
TeamDelete:
  team_name: "<既存チーム名>"  # エラーが出なければスキップ

TeamCreate:
  team_name: "planning"
  description: "Sisyphus Discovery → Design → Tasks"
```

## Step 1: フェーズタスクを登録（進捗の可視化）

> **重要**: TeamCreate の後にタスクを登録すること。TeamCreate でタスクのスコープがチームに切り替わるため、先に作ったタスクは見えなくなる。

```
TaskCreate: "Phase 1: Discovery Council（要件分析）"
TaskCreate: "Phase 2: 設計"
TaskCreate: "Phase 3: タスク分解"
TaskCreate: "Phase 4: 実装"
TaskCreate: "Phase 5: Quality Gate"
```

各フェーズの TaskUpdate タイミング：

| Phase | in_progress にするタイミング | completed にするタイミング |
|-------|--------------------------|--------------------------|
| Phase 1 | Step 1 完了後 | Step 3 開始前 |
| Phase 2 | Step 3 開始前 | Step 4 開始前 |
| Phase 3 | Step 4 開始前 | Step 5 開始前 |
| Phase 4 | Step 5 開始前 | 全実装タスク完了後 |
| Phase 5 | /quality-gate 開始前 | quality-gate 通過後 |

→ `TaskUpdate: Phase 1 → in_progress`

---

## Step 2: Phase 1 - Discovery Council

**3つの teammate を Agent ツールで同時 spawn：**

Phase 1 集約ルール:
- `all("報告完了")` → analyst が全メンバーの findings を統合して requirements.md を最終確定
- **teammate 間通信**: SendMessage ツールで peer-to-peer メッセージ交換

```
1. Agent:
   subagent_type: "o-m-cc:researcher"
   name: "researcher"
   team_name: "planning"
   description: "Discovery Council: 技術調査"
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

     ## Council プロトコル
     あなたは Discovery Council のメンバーです。
     1. 独立に技術調査を実施
     2. 知見が見つかったら SendMessage で analyst と scout の両方に共有
     3. analyst・scout から共有された findings を検証し、技術的に妥当かコメント
     4. 追加調査を依頼されたら対応

     ## 出力
     関連する知見が見つかったら SendMessage で analyst と scout に報告。
     見つからなければ「関連する既存知見なし」と報告。

2. Agent:
   subagent_type: "o-m-cc:analyst"
   name: "analyst"
   team_name: "planning"
   description: "Discovery Council: 要件分析"
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

     ## Council プロトコル
     あなたは Discovery Council のメンバーです（requirements.md の作成担当）。
     1. 独立に要件分析を実施
     2. 要件ドラフトの主要部分ができたら SendMessage で scout・researcher に共有し、フィードバックを促す
     3. scout からのギャップ報告、researcher からの調査知見を SendMessage で受け取り、要件に反映
     4. 全員の findings を統合してから requirements.md を最終確定

     ## 確定前チェック
     requirements.md を Write する前に、scout と researcher からの報告を受信済みか確認してください。
     未受信の場合は SendMessage で状況を確認してください。

     ## 出力
     - plan/requirements.md に要件定義を出力

3. Agent:
   subagent_type: "o-m-cc:scout"
   name: "scout"
   team_name: "planning"
   description: "Discovery Council: ギャップ分析"
   prompt: |
     ## エージェント定義
     agents/scout.md の指示に従ってください。

     ## コンテキスト
     - タスク: 以下の機能について、ギャップ分析を実施
     - 機能: $ARGUMENTS

     ## 入力
     - ユーザーの元の要求（上記）
     - コードベースを直接調査（Glob, Grep, Read）

     ## Council プロトコル
     あなたは Discovery Council のメンバーです。
     1. 独立にギャップ分析を実施
     2. ギャップを発見したら SendMessage で analyst・researcher に共有
     3. researcher から技術知見を SendMessage で受け取ったら分析に反映
     4. analyst の要件ドラフトを検証し、漏れがあればフィードバック

     ## 原則
     - requirements.md の完成を待たず、ユーザーの要求とコードベースから直接分析を開始
     - Critical な曖昧点は AskUserQuestion で確認
     - 回答がなければ仮定を記録して進む
     - フローをブロックしない

     ## 出力
     - 発見した漏れ・補完事項を SendMessage で analyst に報告
```

**Discovery Council の動作:**
- 3エージェントが対等に同時作業を開始
- researcher は技術知見を検索し、見つけ次第 analyst・scout に共有
- scout はユーザーの要求とコードベースから直接ギャップ分析し、analyst・researcher に共有
- analyst は自身の分析 + scout のギャップ報告 + researcher の知見を統合して requirements.md を確定
- 各メンバーは他のメンバーの findings を検証しフィードバック

> **Note**: teammate の出力ファイルはメインリポジトリに直接書き込まれる。worktree からのコピーは不要。次の Phase に進む前にファイルの存在を確認するだけでよい。
> **通信**: teammate 間の peer-to-peer メッセージ交換は SendMessage ツールで行われる。Agent spawn 時に `name` と `team_name` を明示指定することで teammate としてチームに登録される（未指定だと通常 subagent になり SendMessage が配信されない）。

---

## Step 2.5: 🚦 要件承認ゲート（条件付き / Headless: スキップ）

**requirements.md を確認し、人間の判断が必要か評価する。**

### 判定基準

以下のいずれかに該当 → **止まって聞く**：
- scout が未解決の曖昧点・仮定を報告している
- 要件に複数の解釈がありうる（例: スコープの境界が不明確）
- ユーザーの元の要求と requirements.md の間にギャップがある

すべて明確 → **自動承認して進む**

### 止まる場合

```
AskUserQuestion:
  question: |
    ## 要件定義に確認事項があります

    📄 plan/requirements.md の概要:
    [主要ポイントを箇条書き]

    ⚠️ 確認が必要な点:
    [未解決の曖昧点・仮定・判断ポイントを列挙]

    以下から選んでください:
    A) このまま設計に進む
    B) 修正してほしい点がある（具体的に教えてください）
```

- **A の場合**: Phase 2 に進む
- **B の場合**: フィードバックを analyst に SendMessage で伝え、requirements.md を修正させる。修正後、再度評価する

### 自動承認の場合

```
✅ 要件承認: 自動承認（未解決の曖昧点なし）
   📄 plan/requirements.md
   → Phase 2（設計）に進みます
```

---

## Step 3: Phase 2 - 設計

→ `TaskUpdate: Phase 1 → completed`, `TaskUpdate: Phase 2 → in_progress`

**承認後、designer teammate を spawn：**

```
Agent:
  subagent_type: "o-m-cc:designer"
  name: "designer"
  team_name: "planning"
  description: "Phase 2: アーキテクチャ設計"
  prompt: |
    ## エージェント定義
    agents/designer.md の指示に従ってください。

    ## コンテキスト
    - タスク: requirements.md を基にアーキテクチャ設計書を作成

    ## 入力
    - plan/requirements.md

    ## 完了
    - 設計書の出力が完了したらその旨を報告

    ## 出力
    - plan/design.md に設計書を出力
```

---

## Step 3.5: 🚦 設計承認ゲート（条件付き / Headless: スキップ）

**design.md を確認し、人間の判断が必要か評価する。**

### 判定基準

以下のいずれかに該当 → **止まって聞く**：
- 複数の設計アプローチがありトレードオフの判断が必要
- 既存アーキテクチャとの整合性に懸念がある
- 要件に対して設計がオーバー/アンダースペック

すべて明確 → **自動承認して進む**

### 止まる場合

```
AskUserQuestion:
  question: |
    ## 設計に判断ポイントがあります

    📄 plan/design.md の概要:
    [主要な設計判断・コンポーネント構成を要約]

    ⚠️ 判断が必要な点:
    [トレードオフ・懸念点を列挙]

    以下から選んでください:
    A) このままタスク分解に進む
    B) 修正してほしい点がある（具体的に教えてください）
```

- **A の場合**: Phase 3 に進む
- **B の場合**: フィードバックを designer に伝え、design.md を修正させる。修正後、再度評価する

### 自動承認の場合

```
✅ 設計承認: 自動承認（設計判断に曖昧さなし）
   📄 plan/design.md
   → Phase 3（タスク分解）に進みます
```

---

## Step 4: Phase 3 - タスク分解

→ `TaskUpdate: Phase 2 → completed`, `TaskUpdate: Phase 3 → in_progress`

**承認後、planner teammate を spawn：**

```
Agent:
  subagent_type: "o-m-cc:planner"
  name: "planner"
  team_name: "planning"
  description: "Phase 3: タスク分解"
  prompt: |
    ## エージェント定義
    agents/planner.md の指示に従ってください。

    ## コンテキスト
    - タスク: design.md を基にタスクを分解

    ## 入力
    - plan/design.md
    - plan/requirements.md

    ## 完了
    - 全タスクの TaskCreate 登録が完了したらその旨を報告

    ## 出力
    - TaskCreate でネイティブタスクシステムに登録（plan/tasks.md は使わない）
```

---

## Step 4.5: 🚦 タスク承認ゲート（条件付き / Headless: スキップ）

**登録されたタスクを確認し、人間の判断が必要か評価する。**

### 判定基準

以下のいずれかに該当 → **止まって聞く**：
- タスク数が多い（10件以上）で優先順位の判断が必要
- タスク間の依存関係が複雑
- 設計書にない追加タスクが生まれた

すべて明確 → **自動承認して進む**

### 止まる場合

```
AskUserQuestion:
  question: |
    ## タスク分解に確認事項があります

    📋 登録タスク:
    [TaskList の内容を一覧表示]

    ⚠️ 確認が必要な点:
    [判断ポイントを列挙]

    以下から選んでください:
    A) このまま実装に進む
    B) タスクを修正してほしい（具体的に教えてください）
```

- **A の場合**: 実装フェーズに進む（ここから先は Sisyphus Loop — 止まらない）
- **B の場合**: フィードバックに基づいてタスクを修正。修正後、再度評価する

### 自動承認の場合

```
✅ タスク承認: 自動承認（タスク構成に問題なし）
   📋 TaskCreate: X件登録済み
   → 実装フェーズに進みます（Sisyphus Loop — 止まらない）
```

---

## 出力

```
plan/
├── requirements.md  # 要件定義（承認済み）
└── design.md        # 設計書（承認済み）

TaskCreate           # 実装タスク（承認済み）
```

---

## Step 5: 実行方式の自動選択

→ `TaskUpdate: Phase 3 → completed`, `TaskUpdate: Phase 4 → in_progress`

**承認後**、登録されたタスクを分析して実行方式を**自動で決定**する。ここから先は Sisyphus Loop — 止まらない。

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
   📋 TaskCreate: X件登録済み

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
   📋 TaskCreate: X件登録済み

   - タスク: X件 (S:X, M:X, L:X)
   - 実行方式: Sisyphus Loop（依存関係のあるタスク）

計画に沿って実装を開始します。
```

その後、登録されたタスクに基づいて直列で実装を進める。

---

## Step 6: 実装中のタスク管理

実装中は各タスクの進捗を `TaskUpdate` で更新する：
- タスク着手時: `in_progress`
- タスク完了時: `completed`
- 同時に `in_progress` は1つだけ
- `TaskList` で残タスクを確認し、次の未着手・ブロック解除済みタスクに着手

全タスク完了後:
→ `TaskUpdate: Phase 4 → completed`, `TaskUpdate: Phase 5 → in_progress`
→ `/quality-gate` を実行
→ 通過後: `TaskUpdate: Phase 5 → completed`

---

**Step 0 でチーム作成、Step 1 でタスク登録（TeamCreate の後！）、Step 2 で Discovery Council（3エージェント同時 spawn）へ進んでください。各計画フェーズ完了後は承認ゲート（AskUserQuestion）で人間の確認を取ってから次に進むこと（Headless モードではスキップ）。実装フェーズ（Step 5 以降）に入ったら止まらない。**
