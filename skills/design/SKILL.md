---
name: design
description: "designer エージェントによるアーキテクチャ設計。requirements.md を基に design.md を作成。「設計して」「アーキテクチャ設計して」「アーキテクチャを考えて」「設計書を作って」で発動。"
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

## Gotchas

- **requirements.md 無しで spawn しない**: 前提が無いと designer が空想で設計し、下流のタスク分解・実装がずれる。無ければ `discovery-council` へ誘導して終了する
- **background spawn 禁止**: designer は foreground で完了を待つ。background にすると design.md 未完成のまま次フェーズ（task-decomposition）が走る
- **`## 既知の不足` の引き継ぎ漏れ**: requirements.md の既知の不足を design.md に反映/引き継がないと、quality-gate まで漏れが顕在化しない
- **軽微な設計変更で毎回 spawn しない**: designer は opus/high でトークンが重い。1 コンポーネントの微修正なら design.md を直接 Edit する方が速い

<!-- AUTO-GOTCHAS -->
