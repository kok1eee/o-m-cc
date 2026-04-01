---
name: design
description: "designer エージェントによるアーキテクチャ設計。requirements.md 完成後、実装前に使う。requirements.md を基に design.md を作成。「設計して」「アーキテクチャ設計して」「アーキテクチャを考えて」「設計書を作って」で発動。"
argument-hint: ""
allowed-tools: [Agent, Read, Write, Glob, Grep, WebSearch, WebFetch, AskUserQuestion]
model: opus
effort: high
---

# Design - アーキテクチャ設計

requirements.md を基に designer エージェントがアーキテクチャ設計書を作成する。

## 前提

plan/requirements.md が存在すること。なければ「先に /discovery-council で要件定義を行ってください」と案内する。

## Step 1: designer spawn

```
Agent:
  subagent_type: "o-m-cc:designer"
  name: "designer"
  description: "アーキテクチャ設計"
  prompt: |
    ## エージェント定義
    agents/designer.md の指示に従ってください。

    ## コンテキスト
    - タスク: plan/requirements.md を基にアーキテクチャ設計書を作成

    ## 入力
    - plan/requirements.md
    - requirements.md に `## 既知の不足` セクションがある場合、設計でカバーできる不足は補完し、カバーできないものは design.md の `## 既知の不足` に引き継ぐ

    ## 完了
    - 設計書の出力が完了したらその旨を報告

    ## 出力
    - plan/design.md に設計書を出力
```

> **foreground spawn**: designer の完了を待ってから制御を返す。background spawn しないこと。

## 出力

plan/design.md
