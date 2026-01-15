# o-m-cc

**Sisyphus Loop for Claude Code** - TODOが完了するまで止まらないマルチエージェントワークフロー

## Overview

o-m-cc は、Claude Codeに「不屈の開発者」マインドセットを注入するプラグインです。

- **Sisyphus哲学**: タスク完了まで決して止まらない
- **TODOドリブン**: 明確なタスクリストに基づいて作業
- **仕様駆動開発**: 要件 → 設計 → タスク → 実装の構造化フロー

## Quick Start

```bash
# 1. プラグインをインストール
/plugin install o-m-cc@your-marketplace

# 2. Sisyphus モードを有効化（初回のみ）
/sisyphus

# 3. あとは普通に作業するだけ
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
/plan "認証システムを実装"

# 方法2: 段階的に実行
/requirements "認証システムを実装"
/design
/tasks
```

計画が完了したら、普通に実装を依頼：

```
「計画に沿って実装を開始して」
```

## Commands

### セットアップ

| コマンド | 説明 |
|---------|------|
| `/sisyphus` | Sisyphus モードを有効化（CLAUDE.md に追記） |

### 計画フェーズ（複雑なタスク用）

| コマンド | 説明 | 次のステップ |
|---------|------|-------------|
| `/requirements <task>` | 要件定義（SDD Phase 1） | → /design |
| `/design` | 設計書作成（SDD Phase 2） | → /tasks |
| `/tasks` | タスク分解（SDD Phase 3） | → 実装開始 |
| `/plan <task>` | 上記3つを一括実行 | → 実装開始 |

### 品質

| コマンド | 説明 |
|---------|------|
| `/review [files]` | コードレビュー |

## Workflow

```
┌──────────────────────────────────────────────────────────┐
│ 初回セットアップ                                         │
├──────────────────────────────────────────────────────────┤
│ /sisyphus  →  CLAUDE.md に Sisyphus 原則を追加          │
└──────────────────────────────────────────────────────────┘
                         │
                         ▼
┌──────────────────────────────────────────────────────────┐
│ 簡単なタスク                                             │
├──────────────────────────────────────────────────────────┤
│ 「○○を修正して」→ TODO → 実装 → レビュー → 完了       │
└──────────────────────────────────────────────────────────┘

┌──────────────────────────────────────────────────────────┐
│ 複雑なタスク                                             │
├──────────────────────────────────────────────────────────┤
│ /plan → 要件 → 設計 → タスク分解                        │
│              ↓                                           │
│ 「実装開始して」→ TODO → 実装 → レビュー → 完了        │
└──────────────────────────────────────────────────────────┘
```

## Agents

### Planning Agents（計画系）

| Agent | 役割 | Model |
|-------|------|-------|
| @analyst | 現状分析・要件定義 | sonnet |
| @designer | アーキテクチャ設計 | opus |
| @planner | タスク分解 | sonnet |
| @critic | 計画レビュー | sonnet |

### Analysis Agents（分析系）

| Agent | 役割 | Model |
|-------|------|-------|
| @advisor | デバッグ・戦略相談 | opus |
| @researcher | ドキュメント調査 | sonnet |
| @explore | 高速コード探索 | haiku |
| @vision | PDF/画像分析 | sonnet |

### Implementation Agents（実装系）

| Agent | 役割 | Model |
|-------|------|-------|
| @frontend | UI/UXコンポーネント作成 | sonnet |
| @document-writer | ドキュメント作成 | sonnet |

### Quality Agents（品質系）

| Agent | 役割 | Model |
|-------|------|-------|
| @code-reviewer | コードレビュー | sonnet |

## Output Files

計画フェーズで以下のファイルが生成されます：

```
.plan/
├── requirements.md  # 要件定義（FR-X, NFR-X）
├── design.md        # 設計書（コンポーネント、API）
└── tasks.md         # 実装タスク（依存関係、見積もり）
```

## Structure

```
o-m-cc/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── analyst.md         # 要件定義
│   ├── designer.md        # アーキテクチャ設計
│   ├── planner.md         # タスク分解
│   ├── critic.md          # 計画レビュー
│   ├── advisor.md         # 戦略アドバイザー
│   ├── researcher.md      # 調査スペシャリスト
│   ├── explore.md         # 高速探索
│   ├── frontend.md        # UI/UXエンジニア
│   ├── document-writer.md # テクニカルライター
│   ├── vision.md          # マルチモーダル分析
│   └── code-reviewer.md   # コードレビュー
├── commands/
│   ├── sisyphus.md        # モード有効化
│   ├── requirements.md    # 要件定義
│   ├── design.md          # 設計
│   ├── tasks.md           # タスク分解
│   ├── plan.md            # 計画（オーケストレーター）
│   └── review.md          # コードレビュー
├── hooks/
│   ├── hooks.json
│   └── stop-guard.sh
├── examples/
│   └── CLAUDE.md.example
└── README.md
```

## Inspired By

- [cc-sdd](https://github.com/gotalab/cc-sdd)
- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)
- [ralph-wiggum](https://ghuntley.com/ralph/)

## License

MIT
