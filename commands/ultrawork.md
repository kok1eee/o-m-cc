---
description: "Ultraworkモード - 並列エージェントオーケストレーションによる最大パフォーマンス"
allowed-tools: Task, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TodoWrite, AskUserQuestion
model: opus
---

# Ultrawork - 最大パフォーマンスモード

## Step 0: バナー表示

**まず以下を実行:**

```bash
echo -e "\n\033[1;35m╔══════════════════════════════════╗\033[0m"; echo -e "\033[1;35m║\033[0m  \033[1;36m⚡ ULTRAWORK MODE ENABLED ⚡\033[0m   \033[1;35m║\033[0m"; echo -e "\033[1;35m║\033[0m  \033[1;33mParallel Agent Orchestration\033[0m  \033[1;35m║\033[0m"; echo -e "\033[1;35m╚══════════════════════════════════╝\033[0m\n"
```

---

## タスク

$ARGUMENTS

---

## Ultrawork 原則

### 1. 並列エージェント活用（PARALLEL FIRST）

**独立したタスクは必ず並列実行：**

```
# 同時に複数のバックグラウンドエージェントを起動
Task tool (background=true):
  - explore agent: コードベース構造を探索
  - explore agent: 関連ファイルを検索
  - researcher agent: 外部ドキュメントを調査
```

**10個以上の並列タスクも躊躇なく起動。**

### 2. TODO 厳密トラッキング

```
- 作業開始時に TodoWrite で全タスクを登録
- 各ステップ完了時に即座に completed に更新
- 同時に in_progress は1つだけ
```

### 3. エージェント委任（DELEGATE）

**自分でやらない、専門エージェントに委任：**

| タスク種別 | 委任先 |
|-----------|--------|
| コード探索 | explore agent (background) |
| ドキュメント調査 | researcher agent (background) |
| 設計判断 | advisor agent |
| 計画作成 | planner agent |
| コードレビュー | code-reviewer agent |

### 4. 検証保証（VERIFY）

```
完了前に必ず：
1. 元のリクエストを再読
2. 全要件が満たされているか確認
3. code-reviewer でレビュー
4. 漏れがあれば追加タスク
```

---

## 実行フロー

### Step 1: 要求分析

ユーザーのリクエストを分析し、必要な作業を特定：

```
- 何を達成するか
- どのエージェントが必要か
- 並列実行できるタスクは何か
```

### Step 2: 並列探索（バックグラウンド）

**独立した探索タスクを同時起動：**

```
Task tool で並列実行（すべて background=true）：
- explore: プロジェクト構造の把握
- explore: 関連コードの検索
- researcher: 必要なドキュメント調査
```

### Step 3: 計画作成

探索結果を待って、planner agent で作業分解：

```
Task tool で planner agent を呼び出し：
- 収集したコンテキストを共有
- 詳細なタスクリストを作成
- 依存関係と実行順序を決定
```

### Step 4: 並列実装

**独立したタスクは並列で実装：**

```
- 依存関係のないタスクは同時実行
- 各タスク完了時に即座に TODO 更新
- 問題発生時は advisor agent に相談
```

### Step 5: 検証と完了

```
1. 全 TODO が completed か確認
2. 元のリクエストと照合
3. code-reviewer で最終レビュー
4. Critical なし → 完了
```

---

## 出力

作業完了時：

```
🚀 ULTRAWORK COMPLETE

実行サマリー:
- 起動エージェント: X個
- 並列タスク: X個
- 完了タスク: X/X

レビュー結果:
- Critical: なし
- Warning: X件

✅ 全要件達成
```

---

**今すぐ並列エージェントを起動し、最大速度でタスクを完了してください。**
