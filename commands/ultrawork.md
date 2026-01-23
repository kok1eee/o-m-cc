---
description: "Ultraworkモード - 並列エージェントオーケストレーションによる最大パフォーマンス"
allowed-tools: Task, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TodoWrite, AskUserQuestion
model: opus
context: fork
---

# Ultrawork - 最大パフォーマンスモード

## Step 0: Compact 実行（必須）

**Ultrawork 開始前にコンテキストを最適化します。**

プランファイル（`spec/plan/`）にすべての情報が保存されているため、会話履歴は不要です。

**ユーザーに以下を依頼:**

```
🔄 Ultrawork 開始前にコンテキストを最適化します。

以下を実行してください:
/compact

完了後、このタスクを続行します。
```

**Compact 完了後、次のステップに進みます。**

---

## Step 1: バナー表示

**以下を実行:**

```bash
echo -e "\n\033[1;35m╔══════════════════════════════════╗\033[0m"; echo -e "\033[1;35m║\033[0m  \033[1;36m⚡ ULTRAWORK MODE ENABLED ⚡\033[0m    \033[1;35m║\033[0m"; echo -e "\033[1;35m║\033[0m  \033[1;33mParallel Agent Orchestration\033[0m    \033[1;35m║\033[0m"; echo -e "\033[1;35m╚══════════════════════════════════╝\033[0m\n"
```

---

## タスク

$ARGUMENTS

---

## Step 2: Orchestration 設定の確認

**まず `spec/plan/orchestration.yml` の存在を確認:**

```bash
ls -la spec/plan/orchestration.yml 2>/dev/null
```

### orchestration.yml が存在する場合（Orchestrated Mode）

YML ファイルを読み込み、定義に従って実行：

1. **Read** で `spec/plan/orchestration.yml` を読み込む
2. **Read** で `spec/plan/tasks.md` を読み込む
3. `parallel_groups` に従って並列実行
4. `dependencies` に従って順次実行
5. 各タスクグループで:
   - 指定された `agent` を起動
   - 指定された `standards` を読み込む
   - `tasks` を実行

```yaml
# orchestration.yml 構造
task_groups:
  - name: "Phase 1: 基盤構築"
    agent: "general-purpose"
    standards:
      - "global/*"
    tasks:
      - "1-1"
      - "1-2"

parallel_groups:             # 並列実行可能なグループ
  - ["1-1", "1-2"]

dependencies:                # 依存関係
  "Phase 2: 機能実装": ["Phase 1: 基盤構築"]
```

### orchestration.yml が存在しない場合（Free Mode）

従来の自由形式で実行。以下の Ultrawork 原則に従う。

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

### Step 3: 要求分析

ユーザーのリクエストを分析し、必要な作業を特定：

```
- 何を達成するか
- どのエージェントが必要か
- 並列実行できるタスクは何か
```

### Step 4: 並列探索（バックグラウンド）

**独立した探索タスクを同時起動：**

```
Task tool で並列実行（すべて background=true）：
- explore: プロジェクト構造の把握
- explore: 関連コードの検索
- researcher: 必要なドキュメント調査
```

### Step 5: 計画作成

探索結果を待って、planner agent で作業分解：

```
Task tool で planner agent を呼び出し：
- 収集したコンテキストを共有
- 詳細なタスクリストを作成
- 依存関係と実行順序を決定
```

### Step 6: 並列実装

**独立したタスクは並列で実装：**

```
- 依存関係のないタスクは同時実行
- 各タスク完了時に即座に TODO 更新
- 問題発生時は advisor agent に相談
```

### Step 7: 検証と完了

```
1. 全 TODO が completed か確認
2. 元のリクエストと照合
3. code-reviewer で最終レビュー
4. Critical なし → 完了
```

### Step 8: Handoff 更新

**セッション状態を `spec/plan/handoff.yaml` に保存：**

```yaml
# spec/plan/handoff.yaml
updated_at: "[現在時刻]"
status: "completed"  # or "in_progress" if tasks remain

current_task:
  id: "[最後に取り組んだタスク]"
  progress: "100%"

discoveries:
  - type: "pattern"
    content: "[発見したパターン]"
  - type: "decision"
    content: "[決定事項]"

completed_tasks:
  - "[完了したタスクID一覧]"

next_steps:
  - "[残タスクがあれば記載]"

context:
  key_files:
    - "[重要なファイル]"
  notes: "[次回セッションへの申し送り]"
```

**発見したパターンは `spec/standards/learned/` にも記録。**

---

## 出力

### Orchestrated Mode の完了時：

```
🚀 ULTRAWORK COMPLETE (Orchestrated Mode)

Orchestration:
- 設定ファイル: spec/plan/orchestration.yml
- タスクグループ: X個
- 並列実行グループ: X個

実行サマリー:
┌─────────────────────────────┬──────────────┬──────────────┐
│ タスクグループ              │ エージェント │ ステータス   │
├─────────────────────────────┼──────────────┼──────────────┤
│ Phase 1: 基盤構築           │ general      │ ✅ 完了      │
│ Phase 2: 機能実装           │ frontend     │ ✅ 完了      │
│ Phase 3: テスト             │ code-reviewer│ ✅ 完了      │
└─────────────────────────────┴──────────────┴──────────────┘

Standards 適用:
- global/*: 全グループ
- frontend/*: Phase 2
- testing/*: Phase 3

レビュー結果:
- Critical: なし
- Warning: X件

✅ 全要件達成

<promise>DONE</promise>
```

### Free Mode の完了時：

```
🚀 ULTRAWORK COMPLETE (Free Mode)

実行サマリー:
- 起動エージェント: X個
- 並列タスク: X個
- 完了タスク: X/X

レビュー結果:
- Critical: なし
- Warning: X件

✅ 全要件達成

<promise>DONE</promise>
```

---

**今すぐ並列エージェントを起動し、最大速度でタスクを完了してください。**
