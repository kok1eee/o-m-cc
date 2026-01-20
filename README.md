# o-m-cc

**Sisyphus Loop for Claude Code** - TODOが完了するまで止まらないマルチエージェントワークフロー

## Overview

o-m-cc は、Claude Codeに「不屈の開発者」マインドセットを注入するプラグインです。

- **Sisyphus哲学**: タスク完了まで決して止まらない
- **TODOドリブン**: 明確なタスクリストに基づいて作業
- **仕様駆動開発**: 要件 → 設計 → タスク → 実装の構造化フロー
- **Prometheus式インタビュー**: 計画前にギャップ分析で漏れを発見

## Quick Start

```bash
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

並列エージェントで最速実行：

```bash
/o-m-cc:ultrawork "認証機能を実装"

# コンテキスト整理してから実行
/o-m-cc:ultrawork-compact "大規模リファクタリング"
/o-m-cc:ultrawork-clear "新機能実装"
```

## Commands

### セットアップ

| コマンド | 説明 |
|---------|------|
| `/o-m-cc:init` | プロジェクト初期化（CLAUDE.md作成 + Sisyphus有効化） |

> 既存プロジェクト（CLAUDE.md あり）でも `/o-m-cc:init` でOK。Sisyphusセクションのみ追加されます。

### 計画フェーズ（複雑なタスク用）

| コマンド | 説明 | Context |
|---------|------|---------|
| `/o-m-cc:requirements <task>` | 要件定義（SDD Phase 1） | - |
| `/o-m-cc:design` | 設計書作成（SDD Phase 2） | - |
| `/o-m-cc:tasks` | タスク分解（SDD Phase 3） | - |
| `/o-m-cc:plan <task>` | 上記を一括実行（scout によるギャップ分析含む） | fork |

### 実行

| コマンド | 説明 | Context |
|---------|------|---------|
| `/o-m-cc:ultrawork <task>` | 並列エージェントで最大パフォーマンス実行 | fork |
| `/o-m-cc:ultrawork-compact <task>` | /compact 後に ultrawork | fork |
| `/o-m-cc:ultrawork-clear <task>` | /clear 後に ultrawork | fork |

### 品質

| コマンド | 説明 | Context |
|---------|------|---------|
| `/o-m-cc:review [files]` | コードレビュー（security-guidance連携 + code-simplifier提案） | fork |

> **Context: fork** - サブエージェント実行時のコンテキスト汚染を防止。探索結果やレビュー詳細がメイン会話を汚さない。

## Workflow

### 初回セットアップ

```
/o-m-cc:sisyphus
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
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Phase 1     │───▶│  Phase 1.5   │───▶│  Phase 2     │───▶│  Phase 3     │───▶│  Phase 4     │
│  要件定義    │    │  ギャップ    │    │  設計        │    │  タスク分解  │    │  レビュー    │
│  (analyst)   │    │  (scout)     │    │  (designer)  │    │  (planner)   │    │  (critic)    │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
       │                   │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼                   ▼
 requirements.md     追加質問で          design.md          tasks.md           計画の検証
                     要件を補完
```

**Phase 1.5 (scout) の特徴:**
- Prometheus式インタビュー
- **必ず質問で終わる**（パッシブ終了禁止）
- 要件の漏れ・曖昧さを発見
- Critical な質問が解決するまで続行

### 実装フェーズ

```
「実装開始して」または /o-m-cc:ultrawork
  → TODO → 並列実装 → レビュー → 簡素化提案 → 完了
```

## Dependencies

`/o-m-cc:sisyphus` 実行時に推奨プラグインをインストール。

```bash
# マーケットプレイス追加（初回のみ）
claude plugin marketplace add anthropics/claude-plugins-official
```

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

| Agent | 役割 | Model | Permission |
|-------|------|-------|------------|
| @analyst | 現状分析・要件定義 | sonnet | write |
| @scout | ギャップ分析・追加質問（必ず質問で終わる） | sonnet | **plan** |
| @designer | アーキテクチャ設計 | opus | write |
| @planner | タスク分解 | sonnet | write |
| @critic | 計画レビュー | sonnet | **plan** |

### Analysis Agents（分析系）

| Agent | 役割 | Model | Permission |
|-------|------|-------|------------|
| @advisor | デバッグ・戦略相談 | opus | **plan** |
| @researcher | ドキュメント調査 | sonnet | **plan** |
| @explore | 高速コード探索 | haiku | **plan** |
| @vision | PDF/画像分析 | sonnet | **plan** |

### Implementation Agents（実装系）

| Agent | 役割 | Model | Permission |
|-------|------|-------|------------|
| @frontend | UI/UXコンポーネント作成 | sonnet | write |
| @document-writer | ドキュメント作成 | sonnet | write |

### Quality Agents（品質系）

| Agent | 役割 | Model | Permission |
|-------|------|-------|------------|
| @code-reviewer | コードレビュー | sonnet | default |

> **Permission**:
> - `plan`: 読み取り専用モード（permissionMode: plan）。権限確認なしで高速動作
> - `write`: 書き込み可能（Write/Edit ツール使用）
> - `default`: Bashなど特殊ツール使用のため標準権限

## Output Files

計画フェーズで以下のファイルが生成されます：

```
.plan/
├── brainstorm.md    # ブレインストーミング結果（オプション）
├── requirements.md  # 要件定義（FR-X, NFR-X）
├── design.md        # 設計書（コンポーネント、API）
└── tasks.md         # 実装タスク（依存関係、見積もり）
```

## Standards & Steering

プロジェクト固有の規約とコンテキストを `.claude/` 配下で管理：

```bash
# セットアップ（プロジェクトルートで実行）
bash ~/.claude/plugins/o-m-cc/scripts/setup-project.sh
```

### Standards（技術規約）

実装時にエージェントが参照する技術規約：

```
.claude/standards/
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
.claude/steering/
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

## Structure

```
o-m-cc/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/                    # サブエージェント定義
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
│   └── code-reviewer.md       # コードレビュー
├── commands/                  # スラッシュコマンド
│   ├── init.md                # プロジェクト初期化
│   ├── requirements.md        # 要件定義
│   ├── design.md              # 設計
│   ├── tasks.md               # タスク分解
│   ├── plan.md                # 計画（オーケストレーター）
│   ├── review.md              # コードレビュー
│   ├── ultrawork.md           # 並列実行
│   ├── ultrawork-compact.md
│   └── ultrawork-clear.md
├── hooks/                     # フック
│   ├── hooks.json
│   ├── stop-guard.sh          # Stop Hook（ループ制御）
│   ├── archive-plans.sh       # プランアーカイブ
│   ├── block-unnecessary-docs.sh
│   └── warn-console-log.sh
├── templates/                 # Standards/Steering テンプレート
│   ├── standards/
│   │   ├── global/
│   │   ├── frontend/
│   │   ├── backend/
│   │   └── testing/
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

## Inspired By

- [cc-sdd](https://github.com/gotalab/cc-sdd)
- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)
- [ralph-wiggum](https://ghuntley.com/ralph/)

## License

MIT
