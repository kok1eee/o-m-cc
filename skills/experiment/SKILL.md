---
name: experiment
description: "実験駆動の反復改善ループ（autoresearch 方式）。毎回フレッシュなサブエージェントで 1変更→測定→保持 or revert。progress.md がイテレーション間の記憶。パフォーマンス最適化、リファクタリング、UI改善、バグ修正の試行錯誤に使う。「最適化して」「パフォーマンス改善」「リファクタリング」「試行錯誤して」「実験的に改善」で発動。"
argument-hint: "<optimization goal and measurement method>"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Agent, AskUserQuestion]
model: opus
effort: high
paths:
  - "**/*.py"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.sh"
  - "**/*.rs"
  - "**/*.go"
---

# Experiment - autoresearch 方式の反復改善ループ

**毎回フレッシュなコンテキストで実験。記憶はファイルに、判断は毎回リセット。**

Sisyphus が計画駆動（要件→設計→実装）なのに対し、Experiment は実験駆動（試す→測る→残す or 戻す）。
autoresearch の原則: コンテキスト劣化を防ぐため、各イテレーションを独立したサブエージェントで実行する。

## いつ使うか

- パフォーマンス最適化（レスポンス時間、メモリ使用量）
- リファクタリング（品質改善、コード整理）
- UI/UX 改善（見た目、操作感の調整）
- バグ修正の試行錯誤（原因が不明で複数のアプローチを試したい）

## ゴール

$ARGUMENTS

## 現在の状態（動的注入）

### 変更統計
!`jj diff --stat 2>/dev/null || git diff --stat HEAD 2>/dev/null || echo "変更なし"`

### 最近のコミット
!`jj log -r 'ancestors(@, 5)' --no-graph 2>/dev/null || git log --oneline -5 2>/dev/null || echo "履歴なし"`

---

## Step 1: ゴール設定 + progress.md 初期化

ゴール、メトリクス、ベースラインを設定し、progress.md に書き込む。

```markdown
# Experiment Progress

## Goal
[何を改善するか]

## Metric
[どう測定するか — コマンドを具体的に書く]

## Baseline
[初期測定値]

## Current Best
[現在の最良値 — 初期はベースラインと同じ]

## Iterations
<!-- 各イテレーションの結果が追記される -->

## Failed Hypotheses
<!-- 棄却された仮説のリスト — 次のサブエージェントが同じことを試さないために -->
```

**ベースラインなしに改善は測れない。** 最初に必ず測定を実行し、progress.md に記録する。

## Step 2: 改善ループ

以下を **ゴール達成まで** 繰り返す。

```
┌─────────────────────────────────────────────────────────┐
│  Iteration N                                             │
│                                                         │
│  1. Agent spawn（毎回フレッシュなコンテキスト）            │
│     → サブエージェントは progress.md だけを読んで実行      │
│     → 1つの仮説を立て、1つの変更を実装し、測定して報告    │
│                                                         │
│  2. メインエージェントが結果を評価                        │
│     改善 → コミットして保持                               │
│       jj describe -m "experiment: [仮説] → [結果]"       │
│       jj new                                             │
│       progress.md の Current Best を更新                  │
│                                                         │
│     悪化/変化なし → revert                                │
│       jj abandon                                         │
│       progress.md の Failed Hypotheses に追記             │
│                                                         │
│  3. 次のイテレーションへ                                  │
└─────────────────────────────────────────────────────────┘
```

### サブエージェント spawn テンプレート

```
Agent:
  description: "Experiment iteration N"
  prompt: |
    あなたは実験の1イテレーションを担当する独立したエージェントです。

    ## 手順
    1. progress.md を Read して、ゴール・メトリクス・過去の結果を把握
    2. Failed Hypotheses を確認し、同じアプローチを繰り返さない
    3. 新しい仮説を1つ立てる
    4. その仮説に基づいて **1つだけ** 変更を実装
    5. progress.md に書かれた Metric コマンドを実行して測定
    6. 以下のフォーマットで結果を報告:

    ## Report
    - Hypothesis: [仮説]
    - Change: [何を変えたか]
    - Files: [変更したファイル]
    - Before: [変更前の測定値]
    - After: [変更後の測定値]
    - Verdict: improved / degraded / neutral
```

### ルール

- **1反復1変更**: 複数の変更を同時にしない。何が効いたか分からなくなる
- **測定が全て**: 「良くなったはず」ではなく数値で判断
- **revert は失敗ではない**: 仮説が棄却されただけ。progress.md に記録して次に活かす
- **サブエージェントに委任**: メインエージェントは判定とファイル管理のみ。実装と測定はサブエージェントの仕事
- **progress.md が唯一の記憶**: サブエージェント間はこのファイルだけで知識を引き継ぐ

### 停止条件

- ゴール達成
- 3回連続で改善なし → AskUserQuestion でユーザーに方向転換を相談
- ユーザーが停止を指示

### jj 操作

```bash
# 保持する場合
jj describe -m "experiment: [仮説] → [結果: +XX% 改善]"
jj new

# revert する場合
jj abandon
```

## Step 3: 完了報告

ゴール達成または停止後、progress.md の内容をもとに結果をまとめる。

```markdown
## 実験結果

### ゴール: [目標]
### ベースライン: [初期値]
### 最終値: [最終値]（[改善率]）
### イテレーション数: N（成功: X, 棄却: Y）

### 成功した変更
1. [仮説] → [結果]
2. ...

### 棄却した仮説
1. [仮説] → [棄却理由]
2. ...

### 学び
- [次回の実験に活かせること]
```

## Gotchas

- **ベースライン測定を忘れて「なんとなく良くなった」で判断**: 必ず数値で比較
- **複数の変更を一度にして何が効いたか不明**: 1反復1変更を厳守
- **revert せずに「まあいいか」で残す**: 悪化した変更は必ず revert
- **progress.md の更新を忘れる**: Failed Hypotheses を書かないと次のサブエージェントが同じ失敗を繰り返す
- **メインエージェントが実装に入る**: メインは判定とファイル管理だけ。実装はサブエージェント

<!-- AUTO-GOTCHAS -->

---

**Step 1 のゴール設定から開始してください。まずベースラインを測定し、progress.md を作成。**
