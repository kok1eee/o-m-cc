---
name: task-decomposition
description: "planner エージェントによるタスク分解。design.md を基に TaskCreate でネイティブタスクに登録。「タスクに分解して」「タスク分解して」「実装計画を立てて」「何から始める？」で発動。"
argument-hint: ""
allowed-tools: [Agent, Read, Glob, Grep, TaskCreate, TaskUpdate, AskUserQuestion]
effort: medium
---

# Task Decomposition - タスク分解

design.md と requirements.md を基に planner エージェントがタスクを分解し、TaskCreate で登録する。

## 前提

plan/design.md と plan/requirements.md が存在すること。なければ「先に /design で設計を行ってください」と案内する。

## Step 1: planner spawn

```
Agent:
  subagent_type: "o-m-cc:planner"
  name: "planner"
  description: "タスク分解"
  prompt: |
    ## エージェント定義
    agents/planner.md の指示に従ってください。

    ## コンテキスト
    - タスク: design.md を基にタスクを分解

    ## 入力
    - plan/design.md
    - plan/requirements.md
    - design.md または requirements.md に `## 既知の不足` セクションがある場合、不足に対応するタスクを明示的に作成するか、対応不要と判断した理由をタスク description に記録する

    ## 完了
    - 全タスクの TaskCreate 登録が完了したらその旨を報告

    ## 出力
    - TaskCreate でネイティブタスクシステムに登録（plan/tasks.md は使わない）
```

> **foreground spawn**: planner の完了を待ってから制御を返す。background spawn しないこと。

## 出力

TaskCreate（ネイティブタスクシステム）

## Gotchas

- **plan/tasks.md を作らない**: タスクはネイティブ TaskCreate に登録する。tasks.md を作るとネイティブタスクと二重管理になり乖離する（Claude Code ネイティブ活用の原則）
- **design.md だけで呼ばない**: requirements.md も入力に渡さないと要件トレーサビリティ（FR-X ↔ task）が切れる。両方が前提
- **`## 既知の不足` を放置しない**: 対応タスクを作るか、対応不要の理由を task description に記録する。無言でスキップすると quality-gate の実装範囲検証で落ちる
- **atoms backlog 由来の実装**: タスク metadata に `pipeline_id`/`atom_id` を付与して業務状態(CSV)と橋渡しする（CSV への複製はしない軽量規約）

<!-- AUTO-GOTCHAS -->
