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

## Step 0: 初期化

**plan/ の掃除**: 前回の sisyphus 実行で残った plan/ 内のファイル（requirements.md, design.md）を削除する。古いドキュメントが残っていると Council が混乱する。

```bash
rm -f plan/requirements.md plan/design.md
```

**[TRACKING] タスク登録**:

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

**CTA**（再実行は最大1回）:
1. plan/requirements.md を Read
2. **形式チェック**: 以下の必須セクションが存在するか確認
   - 背景/概要
   - 機能要件（FR-X）または要件一覧
   - 非スコープ（今回やらないこと）
3. $ARGUMENTS（ユーザーの元の要求）と内容に重大な乖離があれば1回だけ再実行
4. 2回目でも不完全なら、不足を補足コメントとして記録し先に進む

## Step 2: Phase 2 - 設計

→ `TaskUpdate: Phase 1 → completed`, `TaskUpdate: Phase 2 → in_progress`

```
Skill: design
```

**CTA**（再実行は最大1回）:
1. plan/design.md を Read
2. **形式チェック**: requirements.md の全 FR-X（または主要要件）が design.md 内で言及されているか Grep で確認
3. 重大な乖離（要件の半数以上が未言及）があれば1回だけ再実行
4. 2回目でも不完全なら、不足を補足コメントとして記録し先に進む

## Step 3: Phase 3 - タスク分解

→ `TaskUpdate: Phase 2 → completed`, `TaskUpdate: Phase 3 → in_progress`

```
Skill: task-decomposition
```

**CTA**（再実行は最大1回）:
1. TaskList で登録されたタスクを確認
2. **形式チェック**: design.md の主要コンポーネントに対応するタスクが存在するか確認
3. 重大な欠落があれば1回だけ再実行
4. 2回目でも不完全なら、不足を補足コメントとして記録し先に進む

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

**Step 0 のタスク登録から開始し、Step 1 で discovery-council を Skill chain で呼び出してください。各 CTA で形式チェック + 乖離確認（再実行は最大1回）。全フェーズ止まらない。**
