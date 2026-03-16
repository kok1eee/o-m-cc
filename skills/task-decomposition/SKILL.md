---
name: task-decomposition
description: "planner エージェントによるタスク分解。design.md を基に TaskCreate でネイティブタスクに登録。「タスクに分解して」「タスク分解して」「実装計画を立てて」で発動。"
argument-hint: ""
allowed-tools: [Agent, Read, Glob, Grep, TaskCreate, TaskUpdate, AskUserQuestion]
model: opus
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

    ## 完了
    - 全タスクの TaskCreate 登録が完了したらその旨を報告

    ## 出力
    - TaskCreate でネイティブタスクシステムに登録（plan/tasks.md は使わない）
```

> **foreground spawn**: planner の完了を待ってから制御を返す。background spawn しないこと。

## 出力

TaskCreate（ネイティブタスクシステム）
