---
name: sisyphus
description: "計画→実装→品質ゲートまで止まらない Sisyphus ワークフロー。Agent Teams で要件→設計→タスク分解→実装→quality-gate を一括実行。「計画して」「この機能を実装したい」で発動。"
argument-hint: "<feature description>"
allowed-tools: [Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TaskCreate, TaskUpdate, AskUserQuestion, Agent, TeamCreate, TeamDelete, SendMessage, Skill]
model: opus
context: fork
---

# Sisyphus - 仕様駆動開発オーケストレーター

各 Phase を独立スキルとして chain 実行し、計画→実装→品質ゲートまで止まらない。

## 機能

$ARGUMENTS

## Headless モード

`CLAUDE_NON_INTERACTIVE=1` または `-p` モードで実行されている場合、AskUserQuestion を使わない。全自動で完了まで止まらない。

---

## Step 0: [TRACKING] タスク登録

```
TaskCreate: "[TRACKING] Phase 1: Discovery Council（要件分析）"
TaskCreate: "[TRACKING] Phase 2: 設計"
TaskCreate: "[TRACKING] Phase 3: タスク分解"
TaskCreate: "[TRACKING] Phase 4: 実装"
TaskCreate: "[TRACKING] Phase 5: Quality Gate"
```

> [TRACKING] タスクは進捗管理用。Skill chain 開始前に登録すること。

## Step 1: Phase 1 - Discovery Council

→ `TaskUpdate: Phase 1 → in_progress`

```
Skill: discovery-council
```

**CTA**: plan/requirements.md を Read し、$ARGUMENTS（ユーザーの元の要求）と乖離があれば discovery-council を再実行。

## Step 2: Phase 2 - 設計

→ `TaskUpdate: Phase 1 → completed`, `TaskUpdate: Phase 2 → in_progress`

```
Skill: design
```

**CTA**: plan/design.md を Read し、requirements.md との乖離があれば design を再実行。

## Step 3: Phase 3 - タスク分解

→ `TaskUpdate: Phase 2 → completed`, `TaskUpdate: Phase 3 → in_progress`

```
Skill: task-decomposition
```

**CTA**: TaskList を確認し、design.md にないタスクや依存関係の問題があれば task-decomposition を再実行。

## Step 4: 実行方式の自動選択

→ `TaskUpdate: Phase 3 → completed`, `TaskUpdate: Phase 4 → in_progress`

以下の**すべて**に該当 → **`/batch` で並列実行**：
- 独立した同種の変更が **5件以上**
- 各タスクが **他のタスクに依存しない**
- 各タスクが **同じパターンの繰り返し**

それ以外 → **通常の Sisyphus Loop で直列実行**

## Step 5: 実装中のタスク管理

- タスク着手時: `in_progress`
- タスク完了時: `completed`
- 同時に `in_progress` は1つだけ
- `TaskList` で残タスクを確認し、次の未着手タスクに着手

## Step 6: Quality Gate

→ `TaskUpdate: Phase 4 → completed`, `TaskUpdate: Phase 5 → in_progress`

```
Skill: quality-gate
```

→ 通過後: `TaskUpdate: Phase 5 → completed`

---

**Step 0 のタスク登録から開始し、Step 1 で discovery-council を Skill chain で呼び出してください。各 CTA で乖離があれば差し戻す。全フェーズ止まらない。**
