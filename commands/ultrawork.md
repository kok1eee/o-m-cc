---
description: "Agent Teams による並列エージェントオーケストレーションで最大パフォーマンス実装。「並列で実装して」「最速で作って」で使用。"
allowed-tools: Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TaskCreate, TaskUpdate, TaskList, TaskGet, AskUserQuestion, TeammateTool
model: opus
context: fork
---

# Ultrawork - 最大パフォーマンスモード（Agent Teams）

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
echo -e "\n\033[1;35m╔══════════════════════════════════╗\033[0m"; echo -e "\033[1;35m║\033[0m  \033[1;36m⚡ ULTRAWORK MODE ENABLED ⚡\033[0m    \033[1;35m║\033[0m"; echo -e "\033[1;35m║\033[0m  \033[1;33mAgent Teams Orchestration\033[0m      \033[1;35m║\033[0m"; echo -e "\033[1;35m╚══════════════════════════════════╝\033[0m\n"
```

---

## タスク

$ARGUMENTS

---

## Step 2: チーム作成

**TeammateTool の spawnTeam で ultrawork チームを作成:**

```
TeammateTool: spawnTeam
  teamName: "ultrawork"
```

---

## Step 3: Orchestration 設定の確認

**まず `spec/plan/orchestration.yml` の存在を確認:**

```bash
ls -la spec/plan/orchestration.yml 2>/dev/null
```

### orchestration.yml が存在する場合（Orchestrated Mode）

YML ファイルを読み込み、定義に従って実行：

1. **Read** で `spec/plan/orchestration.yml` を読み込む
2. **Read** で `spec/plan/tasks.md` を読み込む
3. 各タスクグループに対して **teammate を spawn**
4. `parallel_groups` のグループは同時に spawn
5. `dependencies` に従って後続 teammate を spawn

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

**各 teammate の spawn prompt:**

```
TeammateTool: spawnTeammate
  teamName: "ultrawork"
  name: "[agent-name]-[phase]"
  prompt: |
    agents/{agent-name}.md の指示に従って作業してください。

    ## 担当タスク
    [tasks.md から該当タスクの詳細]

    ## 参照 Standards
    [spec/standards/{standards-path} を読み込んで従ってください]

    ## 作業対象
    [対象ファイル/ディレクトリ]

    ## チーム連携
    - 問題を発見したら Lead にメッセージで報告
    - 他の teammate の作業に影響する変更は事前に共有
    - 完了したら結果サマリーを Lead にメッセージ送信
```

### orchestration.yml が存在しない場合（Free Mode）

従来の自由形式で実行。Lead がタスクを分解し teammate に割り当て。

---

## Ultrawork 原則

### 1. Agent Teams 並列活用（PARALLEL FIRST）

**独立したタスクは teammate を同時 spawn：**

```
TeammateTool で並列 spawn：
  - explore teammate: コードベース構造を探索
  - explore teammate: 関連ファイルを検索
  - researcher teammate: 外部ドキュメントを調査
```

**10個以上の teammate も躊躇なく spawn。**

### 2. 共有タスクリスト（依存関係対応）

```
- TaskList で未着手タスクを確認（blockedBy が空のものが着手可能）
- TaskCreate で全タスクを登録、TaskUpdate で依存関係を設定
- Teammates が自律的にタスクをクレーム → 実行 → 完了報告
- tasks.md の対応行も [x] に更新（suggest-review.sh が cc-sidebar に同期）
```

**TaskList が空の場合（初回起動時）:**
tasks.md から TaskCreate で登録し、TaskUpdate で依存関係を設定する。

### 3. Teammate 委任（DELEGATE）

**自分でやらない、専門 teammate に委任：**

| タスク種別 | 委任先 teammate |
|-----------|----------------|
| コード探索 | explore teammate |
| ドキュメント調査 | researcher teammate |
| 設計判断 | advisor teammate |
| 計画作成 | planner teammate |
| コードレビュー | code-reviewer teammate |

### 4. 検証保証（VERIFY）

```
完了前に必ず：
1. 元のリクエストを再読
2. 全要件が満たされているか確認
3. code-reviewer teammate でレビュー
4. 漏れがあれば追加タスク
```

---

## 実行フロー

### Step 4: 要求分析

ユーザーのリクエストを分析し、必要な作業を特定：

```
- 何を達成するか
- どの teammate が必要か
- 並列 spawn できるタスクは何か
```

### Step 5: 並列探索（Teammates Spawn）

**独立した探索タスクの teammate を同時 spawn：**

```
TeammateTool で並列 spawn：
  - explore teammate: プロジェクト構造の把握
  - explore teammate: 関連コードの検索
  - researcher teammate: 必要なドキュメント調査
```

### Step 6: 計画作成

探索 teammate の結果を受けて、planner teammate を spawn：

```
TeammateTool: spawnTeammate
  teamName: "ultrawork"
  name: "planner"
  prompt: |
    agents/planner.md の指示に従ってください。
    収集したコンテキストを基に：
    - 詳細なタスクリストを作成
    - 依存関係と実行順序を決定
```

### Step 7: 並列実装

**独立したタスクの teammate を並列 spawn：**

```
- 依存関係のないタスクは同時に teammate spawn
- 各 teammate 完了時に Lead へメッセージで報告
- Lead が TaskUpdate で TODO 更新
- 問題発生時は advisor teammate を spawn して相談
```

### Step 8: 監視・調整

**Lead は定期的に：**

- teammates の進捗をメッセージで確認
- 問題があれば teammate にメッセージでリダイレクト
- 完了した teammate に追加タスクをメッセージで割り当て
- ブロックされた teammate を支援

### Step 9: 検証と完了

```
1. 全 TODO が completed か確認
2. 元のリクエストと照合
3. code-reviewer teammate で最終レビュー
4. Critical なし → 完了
```

### Step 10: 引き継ぎ書の生成

`/o-m-cc:handover` を実行してセッションの引き継ぎ書を生成する。

---

## 出力

### Orchestrated Mode の完了時：

```
🚀 ULTRAWORK COMPLETE (Orchestrated Mode - Agent Teams)

Orchestration:
- 設定ファイル: spec/plan/orchestration.yml
- タスクグループ: X個
- 並列 Teammates: X個

実行サマリー:
┌─────────────────────────────┬──────────────┬──────────────┐
│ タスクグループ              │ Teammate     │ ステータス   │
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
🚀 ULTRAWORK COMPLETE (Free Mode - Agent Teams)

実行サマリー:
- Spawn Teammates: X個
- 並列タスク: X個
- 完了タスク: X/X

レビュー結果:
- Critical: なし
- Warning: X件

✅ 全要件達成

<promise>DONE</promise>
```

---

**今すぐ Agent Teams を起動し、teammate を並列 spawn して最大速度でタスクを完了してください。**
