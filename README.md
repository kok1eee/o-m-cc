# o-m-cc v0.9.0

**Sisyphus Loop for Claude Code** - TODOが完了するまで止まらないマルチエージェントワークフロー

## Overview

o-m-cc は、Claude Codeに「不屈の開発者」マインドセットを注入するプラグインです。

- **Agent Teams**: TeammateTool による peer-to-peer マルチエージェント協調
- **claude-mem 連携**: セマンティックメモリ検索で過去の全操作を活用
- **Sisyphus哲学**: タスク完了まで決して止まらない
- **TODOドリブン**: 明確なタスクリストに基づいて作業
- **仕様駆動開発**: 要件 → 設計 → タスク → 実装の構造化フロー
- **Prometheus式インタビュー**: 計画前にギャップ分析で漏れを発見

## Quick Start

```bash
# 0. Agent Teams を有効化（必須）
export CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1

# 1. marketplace 追加
claude plugin marketplace add kok1eee/o-m-cc

# 2. プラグインインストール
claude plugin install o-m-cc@kok1eee

# 3. プロジェクト初期化（CLAUDE.md作成 + Sisyphus有効化）
/o-m-cc:init

# 4. あとは普通に作業するだけ
「ログインボタンのバグを修正して」
→ 自動的に Sisyphus モードで動作
```

## Usage

### 簡単なタスク（バグ修正、小さな機能追加）

Sisyphus モード有効化後は、普通にタスクを依頼するだけ：

```
「APIのエラーハンドリングを追加して」
「ボタンの色を青に変更して」
「ログイン画面のバグを修正して」
```

自動的に TODO作成 → 実装 → レビュー → 完了 の流れで動作。

### 複雑なタスク（新機能、大きなリファクタリング）

計画フェーズを先に実行：

```bash
# 方法1: 一括実行
/o-m-cc:plan "認証システムを実装"

# 方法2: 段階的に実行
/o-m-cc:requirements "認証システムを実装"
/o-m-cc:design
/o-m-cc:tasks
```

計画が完了したら、普通に実装を依頼：

```
「計画に沿って実装を開始して」
```

### 最大パフォーマンスモード

Agent Teams で teammate を並列 spawn して最速実行：

```bash
/o-m-cc:ultrawork "認証機能を実装"
```

> **Note**: ultrawork 開始時に自動的に `/compact` を実行します。プランファイル（`spec/plan/`）にすべての情報が保存されているため、会話履歴のクリーンアップが安全に行えます。

## Commands

### セットアップ

| コマンド | 説明 |
|---------|------|
| `/o-m-cc:init` | プロジェクト初期化（CLAUDE.md作成 + Sisyphus有効化） |
| `/o-m-cc:install` | グローバル設定（プラグイン・スピナー・hooks）- 一度だけ |

> 既存プロジェクト（CLAUDE.md あり）でも `/o-m-cc:init` でOK。Sisyphusセクションのみ追加されます。

### 計画フェーズ（複雑なタスク用）

| コマンド | 説明 | Context |
|---------|------|---------|
| `/o-m-cc:requirements <task>` | 要件定義（SDD Phase 1） | - |
| `/o-m-cc:design` | 設計書作成（SDD Phase 2） | - |
| `/o-m-cc:tasks` | タスク分解（SDD Phase 3） | - |
| `/o-m-cc:plan <task>` | 上記を一括実行（Agent Teams で並列化 + scout ギャップ分析） | fork |

### 実行

| コマンド | 説明 | Context |
|---------|------|---------|
| `/o-m-cc:ultrawork <task>` | Agent Teams で teammate 並列 spawn、最大パフォーマンス実行（自動 /compact） | fork |

### 品質

| コマンド | 説明 | Context |
|---------|------|---------|
| `/o-m-cc:review [files]` | Agent Teams でコードレビュー（peer-to-peer 議論 + code-simplifier提案） | fork |
| `/o-m-cc:audit [target]` | エージェント・コマンドの品質監査 | - |
| `/o-m-cc:learn [概要]` | 学びを構造化記録（パターン / アンチパターン / 決定） | - |
| `/o-m-cc:promote [keyword]` | 繰り返す学びをスキルに昇格 | - |

> **Context: fork** - teammate 実行時のコンテキスト汚染を防止。探索結果やレビュー詳細がメイン会話を汚さない。

## Workflow

### 初回セットアップ

```
/o-m-cc:init
  → 依存プラグイン確認・インストール
  → CLAUDE.md に Sisyphus 原則を追加
  → hooks 設定（<promise>DONE</promise> までループ）
```

### 簡単なタスク

```
「○○を修正して」→ TODO → 実装 → レビュー → 完了
※ hooks により <promise>DONE</promise> まで自動継続
```

### 複雑なタスク（/o-m-cc:plan）

```
Agent Teams:
┌──────────────┐ ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Phase 0.5   │ │  Phase 1     │───▶│  Phase 1.5   │───▶│  Phase 2     │───▶│  Phase 3     │
│  学び検索    │ │  要件定義    │    │  ギャップ    │    │  設計        │    │  タスク分解  │
│  (learnings) │ │  (analyst)   │    │  (scout)     │    │  (designer)  │    │  (planner)   │
└──────┬───────┘ └──────┬───────┘    └──────────────┘    └──────────────┘    └──────────────┘
       │                │                   │                   │                   │
       └── 並列 spawn ──┘                   ▼                   ▼                   ▼
                                       追加質問で          design.md          tasks.md
                                       要件を補完
```

**Phase 0.5 + 1 は並列 teammates、Phase 1.5 以降は依存タスクで順序制御**

### 実装フェーズ

```
「実装開始して」または /o-m-cc:ultrawork
  → Agent Teams → teammate 並列 spawn → レビュー → 簡素化提案 → 完了
```

## Dependencies

`/o-m-cc:init` 実行時に推奨プラグインをインストール。

```bash
# マーケットプレイス追加（初回のみ）
claude plugin marketplace add anthropics/claude-plugins-official
```

### セマンティックメモリ（オプション）

| プラグイン | 用途 |
|-----------|------|
| [claude-mem](https://github.com/thedotmack/claude-mem) | 全セッションの操作を自動記録、セマンティック検索（`/o-m-cc:install` で設定） |

> **Note**: claude-mem は AGPL ライセンスの外部依存です。o-m-cc は claude-mem の MCP ツールを呼ぶ側であり、組み込みはしません。未設定でも Grep フォールバックで動作します。

### 開発支援（共通）

| プラグイン | 用途 |
|-----------|------|
| frontend-design | フロントエンド設計支援 |
| feature-dev | 機能開発ワークフロー |
| code-simplifier | コード簡素化（レビュー後提案） |
| security-guidance | セキュリティレビュー支援 |

### LSP（言語に応じて選択）

| 言語 | プラグイン | インストール |
|------|-----------|-------------|
| TypeScript/JS/React | vtsls | `claude plugin install vtsls` |
| Python | pyright | `claude plugin install pyright` |
| Go | gopls | `claude plugin install gopls` |
| Rust | rust-analyzer | `claude plugin install rust-analyzer` |

> **Note**: ループ制御（`<promise>DONE</promise>` 検知）は o-m-cc 内蔵の Stop Hook で実現。外部プラグイン不要。

## Agents

### Planning Agents（計画系）

| Agent | 役割 | Model | Permission | Memory |
|-------|------|-------|------------|--------|
| @analyst | 現状分析・要件定義 | sonnet | write | project |
| @scout | ギャップ分析・追加質問（仮定で進む） | sonnet | **plan** | - |
| @designer | アーキテクチャ設計 | opus | write | project |
| @planner | タスク分解 | sonnet | write | project |
| @critic | 計画レビュー | sonnet | **plan** | - |

### Analysis Agents（分析系）

| Agent | 役割 | Model | Permission | Memory |
|-------|------|-------|------------|--------|
| @advisor | デバッグ・戦略相談 | opus | **plan** | project |
| @researcher | ドキュメント調査 | sonnet | **plan** | - |
| @learnings-researcher | 過去の学び検索 | haiku | **plan** | - |
| @debugger | 体系的デバッグ | sonnet | default | project |
| @explore | 高速コード探索 | haiku | **plan** | - |
| @vision | PDF/画像分析 | sonnet | **plan** | - |

### Implementation Agents（実装系）

| Agent | 役割 | Model | Permission | Memory |
|-------|------|-------|------------|--------|
| @frontend | UI/UXコンポーネント作成 | sonnet | write | project |
| @document-writer | ドキュメント作成 | sonnet | write | - |

### Quality Agents（品質系）

| Agent | 役割 | Model | Permission | Memory |
|-------|------|-------|------------|--------|
| @code-reviewer | コードレビュー | sonnet | default | project |
| @security-reviewer | セキュリティレビュー | sonnet | default | project |
| @code-simplifier | コード簡素化・リファクタリング | sonnet | write | - |

> **Permission**:
> - `plan`: 読み取り専用モード（permissionMode: plan）。権限確認なしで高速動作
> - `write`: 書き込み可能（Write/Edit ツール使用）
> - `default`: Bashなど特殊ツール使用のため標準権限
>
> **Memory**: `project` スコープのエージェントはプロジェクト固有の知見（パターン、規約、過去の判断）を永続的に記憶

## Output Files

計画フェーズで以下のファイルが生成されます：

```
spec/plan/
├── brainstorm.md       # ブレインストーミング結果（オプション）
├── requirements.md     # 要件定義（FR-X, NFR-X）
├── design.md           # 設計書（コンポーネント、API）
├── tasks.md            # 実装タスク（依存関係、見積もり）
└── orchestration.yml   # オーケストレーション設定（ultrawork用）
```

## Orchestration

`/o-m-cc:tasks` で tasks.md と同時に `orchestration.yml` が生成されます。
`/o-m-cc:ultrawork` はこのファイルを読み込み、Agent Teams で構造化された実行を行います。

### orchestration.yml 構造

```yaml
version: 1

task_groups:
  - name: "Phase 1: 基盤構築"
    agent: "general-purpose"
    standards:
      - "global/*"
    tasks:
      - "1-1"

  - name: "Phase 2: 機能実装"
    agent: "frontend"
    standards:
      - "global/*"
      - "frontend/*"
    tasks:
      - "2-1"
      - "2-2"

parallel_groups:
  - ["Phase 1: 基盤構築", "Phase 2: 機能実装"]

dependencies:
  "Phase 3: テスト":
    - "Phase 2: 機能実装"
```

### 実行モード

| モード | 条件 | 動作 |
|--------|------|------|
| **Orchestrated** | `orchestration.yml` あり | YML定義に従って teammate を spawn して構造化実行 |
| **Free** | `orchestration.yml` なし | Lead がタスク分解 → teammate に割り当て |

## Standards & Steering

プロジェクト固有の規約とコンテキストを `spec/` 配下で管理：

```bash
# セットアップ（プロジェクトルートで実行）
bash ~/spec/plugins/o-m-cc/scripts/setup-project.sh
```

### Standards（技術規約）

実装時にエージェントが参照する技術規約：

```
spec/standards/
├── global/
│   ├── coding-style.md   # コーディングスタイル
│   ├── conventions.md    # 規約（Git、エラーハンドリング等）
│   └── tech-stack.md     # 技術スタック
├── frontend/
│   └── components.md     # フロントエンド規約
├── backend/
│   └── api-design.md     # API設計規約
└── testing/
    └── test-strategy.md  # テスト戦略
```

### Steering（プロジェクト文脈）

計画時にエージェントが参照するプロジェクト文脈：

```
spec/steering/
├── product.md     # プロダクト概要、目的、ロードマップ
├── tech.md        # アーキテクチャ、技術選定理由、ADR
└── structure.md   # ディレクトリ構造、ファイル配置規則
```

**Standards vs Steering**:

| | Standards | Steering |
|---|-----------|----------|
| 目的 | 実装品質の統一 | 計画の文脈提供 |
| 参照タイミング | 実装時 | 計画時 |
| 内容 | How（どう実装するか） | What/Why（何を、なぜ） |

## Token Efficiency

### 初期読み込みコスト

o-m-cc プラグインの初期トークン消費:

| カテゴリ | トークン数 | 内訳 |
|---------|-----------|------|
| エージェント | ~880 | 16 エージェント定義 |
| スキル | ~130 | 11 コマンド定義 |
| **合計** | **~1010** | Opus 1M の約 **0.1%** |

> **Note**: Memory files (CLAUDE.md等) や他プラグインは別途消費。`/clear` 後の表示で確認可能。

### 実行時の効率化

エージェントの出力は **要約 + ログ分離** でトークン消費を抑制。

### 仕組み

```
Teammate
    │
    ├─ 詳細 → spec/plan/logs/{agent}-{timestamp}.md に保存
    │
    └─ 要約 → Lead にメッセージで返却
```

### エージェント出力フォーマット

```markdown
## ✅ [agent-name] 完了

**結果**: 成功 / 失敗 / 要確認
**変更ファイル**:
- path/to/file.ts:45-67
**サマリー**: [1-2文で何をしたか]
**詳細ログ**: spec/plan/logs/{agent}-{YYYYMMDD-HHMMSS}.md
```

### ログ構造

```
spec/plan/logs/
├── frontend-20260120-143052.md      # フロントエンド実装詳細
├── code-reviewer-20260120-144530.md # レビュー詳細
└── explore-20260120-142010.md       # 探索結果詳細
```

**メリット**:
- メインエージェントのコンテキスト消費を抑制
- 人間への表示も簡潔に
- 詳細は必要時のみ参照可能

## Cross-Session Restoration

セッション開始時に前回の状態を自動表示。`/compact` 後も継続作業可能。

### 仕組み

```
SessionStart Hook
    │
    └─ spec/plan/handoff.yaml を検出
         │
         ├─ 7日以上古い → スキップ
         │
         └─ 有効 → 前回の状態を表示
              ├─ Status
              ├─ Current Task
              └─ Next Steps
```

### 表示例

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📋 Previous Session Found (spec/plan/handoff.yaml)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Status: in_progress

Current Task:
  - Phase: Phase 2: 機能実装
  - Task: 2-1 - UserService の実装

Next Steps:
  - UserService のテスト追加

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
💡 To continue: describe what you want to work on
💡 To start fresh: /clear
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Handoff

セッション状態を構造化して引き継ぐ仕組み。ultrawork 完了時に自動生成。

### 目的

- `/compact` 後も状態を復元可能
- 次回セッションへのスムーズな引き継ぎ
- 発見事項の記録

### 構造

```yaml
# spec/plan/handoff.yaml
updated_at: "2026-01-20T14:30:00+09:00"
status: "in_progress"

current_task:
  phase: "Phase 2: 機能実装"
  task: "2-1"
  progress: "70%"

discoveries:
  - type: "pattern"
    content: "Service クラスは interface を先に定義"
  - type: "decision"
    content: "認証は session-based を採用"

next_steps:
  - "UserService のテスト追加"
```

## Learned Standards

プロジェクトで発見したパターン・規約を累積記録。

### Static vs Learned

| 種類 | 場所 | 内容 |
|------|------|------|
| **Static** | `spec/standards/global/` etc. | 事前定義の規約 |
| **Learned** | `spec/standards/learned/` | 発見したパターン（動的） |

### ファイル構成

```
spec/standards/learned/
├── patterns.md      # 発見したパターン
├── decisions.md     # 技術的決定
└── antipatterns.md  # 避けるべきパターン
```

### 記録タイミング

- コードレビュー時に発見
- 実装中に気づいた暗黙の規約
- Handoff の discoveries から転記

## Agent Capabilities

エージェント選択の効率化。`agents/capabilities.md` で能力サマリーとキーワードを管理。

### 使い分け

| シナリオ | 選択方法 |
|---------|---------|
| **小タスク**（plan なし） | キーワードでマッチ → teammate spawn |
| **plan あり** | 得意分野・使用場面で選択 → teammate spawn |

### サマリーテーブル（抜粋）

| エージェント | 得意分野 | キーワード |
|-------------|---------|-----------|
| explore | 高速検索・構造把握 | 探索, 検索, どこ, where |
| designer | アーキテクチャ設計 | 設計, design |
| frontend | UI実装 | UI, 画面, component |
| code-reviewer | コード品質 | レビュー, 品質, review |
| security-reviewer | セキュリティ | セキュリティ, 脆弱性, security |

> **Note**: `code-reviewer` と `security-reviewer` は **Agent Teams で並列 spawn 推奨**

**詳細**: `agents/capabilities.md` を参照

## Research Depth Levels

`@researcher` エージェントは、リクエストのキーワードから調査深度を自動判断。

### 深度レベル

| 深度 | 検索回数 | ソース数 | トリガーキーワード |
|------|---------|---------|------------------|
| **quick** | 1-2回 | 3-5 | ざっくり、簡単に、概要 |
| **standard** | 3-5回 | 10-15 | （デフォルト） |
| **deep** | 5-10回 | 20-30 | 詳しく、比較して、深掘り |
| **exhaustive** | 10+回 | 30+ | 徹底的に、網羅的に、全部 |

### 使用例

```
「React Hooks の使い方をざっくり教えて」     → quick
「JWT認証の実装方法を調べて」               → standard
「Prisma vs TypeORM を詳しく比較して」      → deep
「GraphQL の全機能を徹底的に調査して」      → exhaustive
```

## Hooks

o-m-cc は hooks を使って以下の自動化を提供します。

### 概要

| イベント | Hook | 説明 |
|---------|------|------|
| SessionStart | `check-dependencies.sh` | 依存コマンド（jq, python3）の確認 |
| SessionStart | `archive-plans.sh` | 古いプランファイルをアーカイブ |
| SessionStart | `resume-session.sh` | 前回のセッション状態を表示 |
| Stop | `stop-guard.sh` | Sisyphus ガード（レビュー確認） |
| Stop | `generate-handoff.sh` | セッション状態を保存 |
| UserPromptSubmit | `focus-guard.sh` | タスク進行中の脱線防止 |
| PreToolUse | `security_reminder_hook.py` | セキュリティパターン検出 |
| PostToolUse | `auto-verify.sh` | フェーズ完了時の自動検証 |
| TeammateIdle | `teammate-idle.sh` | idle teammate への残タスク再割り当て示唆 |
| TaskCompleted | `task-completed.sh` | タスク完了時の進捗表示・依存タスクアンブロック |

### デバッグモード

```bash
export O_M_CC_DEBUG=1
claude
```

### エラーログ

hooks のエラーは `spec/hooks-error.log` に記録されます。

### 状態リセット

問題が発生した場合:

```bash
bash hooks/reset-state.sh
```

**詳細**: [docs/hooks-guide.md](docs/hooks-guide.md), [docs/hooks-errors.md](docs/hooks-errors.md)

## Structure

```
o-m-cc/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/                    # エージェント定義（teammate spawn 時に参照）
│   ├── capabilities.md        # エージェント能力サマリー + キーワード
│   ├── analyst.md             # 要件定義
│   ├── scout.md               # ギャップ分析（Prometheus式）
│   ├── designer.md            # アーキテクチャ設計
│   ├── planner.md             # タスク分解
│   ├── critic.md              # 計画レビュー
│   ├── advisor.md             # 戦略アドバイザー
│   ├── researcher.md          # 調査スペシャリスト
│   ├── explore.md             # 高速探索
│   ├── frontend.md            # UI/UXエンジニア
│   ├── document-writer.md     # テクニカルライター
│   ├── vision.md              # マルチモーダル分析
│   ├── debugger.md             # 体系的デバッグ
│   ├── learnings-researcher.md # 過去の学び検索
│   ├── code-reviewer.md       # コード品質レビュー
│   ├── security-reviewer.md   # セキュリティレビュー（並列 spawn 推奨）
│   └── code-simplifier.md     # コード簡素化・リファクタリング
├── commands/                  # スラッシュコマンド
│   ├── init.md                # プロジェクト初期化
│   ├── install.md             # グローバル設定
│   ├── audit.md               # 品質監査
│   ├── learn.md               # 学び記録
│   ├── promote.md             # スキル昇格
│   ├── requirements.md        # 要件定義
│   ├── design.md              # 設計
│   ├── tasks.md               # タスク分解
│   ├── plan.md                # 計画（Agent Teams オーケストレーター）
│   ├── review.md              # コードレビュー（Agent Teams 並列）
│   └── ultrawork.md           # Agent Teams 並列実行（自動 /compact）
├── hooks/                     # フック
│   ├── hooks.json             # フック設定
│   ├── lib/
│   │   └── common.sh          # 共通ライブラリ
│   ├── check-dependencies.sh  # 依存コマンド確認
│   ├── archive-plans.sh       # プランアーカイブ
│   ├── resume-session.sh      # セッション復元
│   ├── stop-guard.sh          # Sisyphus ガード
│   ├── generate-handoff.sh    # セッション状態保存
│   ├── auto-verify.sh         # フェーズ完了時の自動検証
│   ├── focus-guard.sh         # タスク進行中の脱線防止
│   ├── teammate-idle.sh       # Teammate idle 時の再割り当て（Agent Teams）
│   ├── task-completed.sh      # タスク完了時の進捗・アンブロック（Agent Teams）
│   ├── security_reminder_hook.py  # セキュリティチェック
│   └── reset-state.sh         # 状態リセットツール
├── docs/                      # ドキュメント
│   ├── hooks-guide.md         # Hooks 使い方ガイド
│   └── hooks-errors.md        # エラーリファレンス
├── templates/                 # Standards/Steering/Handoff テンプレート
│   ├── handoff.yaml.example   # Handoff テンプレート
│   ├── standards/
│   │   ├── global/
│   │   ├── frontend/
│   │   ├── backend/
│   │   ├── testing/
│   │   └── learned/           # 発見したパターン（動的）
│   └── steering/
│       ├── product.md
│       ├── tech.md
│       └── structure.md
├── scripts/
│   ├── install-plugins.sh     # 推奨プラグインのインストール
│   ├── setup-claude-md.sh     # CLAUDE.md の Sisyphus セクション管理
│   └── setup-project.sh       # Standards/Steering セットアップ
└── README.md
```

## Philosophy

Sisyphus Loop の背後にある哲学：

| 原則 | 説明 |
|------|------|
| **Iteration > Perfection** | 最初から完璧を目指さない。ループに任せて改善させる |
| **Failures Are Data** | 失敗は情報。予測可能な失敗から学び、プロンプトを調整 |
| **Operator Skill Matters** | 成功は良いプロンプトを書くスキルに依存する |
| **Persistence Wins** | 成功するまで試し続ける。ループがリトライを自動処理 |

## Prompt Design Guide

効果的なプロンプト設計のパターン：

### 1. 明確な完了条件

```
❌ 悪い例: 「Todo APIを作って、いい感じにして」

✅ 良い例:
Build a REST API for todos.
When complete:
- All CRUD endpoints working
- Input validation in place
- Tests passing (coverage > 80%)
- README with API docs
```

### 2. 段階的なゴール設定

```
Phase 1: User authentication (JWT, tests)
Phase 2: Product catalog (list/search, tests)
Phase 3: Shopping cart (add/remove, tests)
```

### 3. 自己修正の指示（TDD）

```
Implement feature X following TDD:
1. Write failing tests
2. Implement feature
3. Run tests
4. If any fail, debug and fix
5. Refactor if needed
6. Repeat until all green
```

### 4. 安全弁

環境変数 `SISYPHUS_MAX_ITERATIONS` で最大イテレーション数を設定（デフォルト: 50）

```bash
export SISYPHUS_MAX_ITERATIONS=30
```

## Best Use Cases

### ✅ 向いているタスク

- **大規模リファクタリング** - フレームワーク移行、依存関係アップグレード
- **バッチ処理** - ドキュメント生成、コード標準化
- **テストカバレッジ向上** - 全関数にテスト追加
- **グリーンフィールド開発** - 新規プロジェクトの足場作り

### ❌ 向いていないタスク

- **人間の判断が必要** - デザイン決定、UX評価
- **一発で終わる操作** - ファイルコピー、単純なスクリプト
- **成功基準が曖昧** - 「いい感じに」「きれいに」
- **本番環境のデバッグ** - 繊細な調査が必要

## Changelog

### 0.9.0

- **claude-mem 連携**: セマンティックメモリ検索を全エージェントに提供
- **learnings-researcher 強化**: claude-mem セマンティック検索をプライマリに、Grep をフォールバックに
- **/install に claude-mem セットアップステップ追加**
- **/promote が claude-mem からクロスプロジェクトのスキル候補を発掘**
- **4エージェント (debugger, designer, advisor, analyst)** に ToolSearch + claude-mem 連携を追加
- claude-mem 未設定時は従来の Grep ベースで完全動作（オプショナル依存）

### 0.8.0

- **Agent Teams 全面移行**: Task tool subagent → TeammateTool (spawnTeam + teammates) に移行
- **peer-to-peer 通信**: teammates 間でメッセージ交換による自律的協調
- **Token Efficiency**: Opus 1M 対応（0.5% → 0.1%）
- **ultrawork**: Agent Teams による teammate 並列 spawn
- **review**: code-reviewer + security-reviewer が peer-to-peer で議論
- **plan**: Phase 0.5 + 1 を並列 teammates で実行
- **新 hooks**: TeammateIdle（idle teammate への再割り当て）、TaskCompleted（進捗・アンブロック通知）
- **agent memory**: 8 エージェントに `memory: project` 追加（プロジェクト知見の永続記憶）

### 0.7.0

- **新エージェント**: debugger（体系的デバッグ）、learnings-researcher（過去の学び検索）
- **新コマンド**: `/install`（グローバル設定）、`/audit`（品質監査）、`/learn`（学び記録）、`/promote`（スキル昇格）
- **新hooks**: agent-rules.json（エージェント自動提案）、suggest-agent.sh
- **security-reviewer 強化**: Trail of Bits パターン（Rationalizations、Insecure Defaults、Sharp Edges）
- **code-reviewer 強化**: Blast Radius 分析（変更の影響範囲定量化）
- **ワンショット改善**: scout の「必ず質問で終わる」を廃止、plan/init/audit の不要な確認を削除
- **plan 簡素化**: Step 0-2（コンテキスト管理・ブレインストーミング・実行方式確認）を削除、一括実行がデフォルト

### 0.6.0 (Breaking Change)

- **ディレクトリ構造変更**: `.claude/` → `spec/` に移行
  - `spec/standards/` - 技術規約
  - `spec/steering/` - プロジェクト文脈
  - `spec/rules/` - Sisyphus ルール
  - `spec/plan/` - 計画ファイル（requirements, design, tasks）
- `.claude/` 全体を gitignore 推奨（Claude Code 内部用）
- Token Efficiency セクションに初期読み込みコストを追加

### 0.5.x

- 初期リリース
- Sisyphus Loop、SDD フロー、13 エージェント

## Inspired By

- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)
- [ralph-wiggum](https://ghuntley.com/ralph/)

## License

MIT
