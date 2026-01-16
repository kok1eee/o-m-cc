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

# 3. Sisyphus モードを有効化（初回のみ）
/o-m-cc:sisyphus

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
| `/o-m-cc:sisyphus` | Sisyphus モードを有効化（依存プラグイン確認 + CLAUDE.md設定 + hooks設定） |

### 計画フェーズ（複雑なタスク用）

| コマンド | 説明 | 次のステップ |
|---------|------|-------------|
| `/o-m-cc:requirements <task>` | 要件定義（SDD Phase 1） | → design |
| `/o-m-cc:design` | 設計書作成（SDD Phase 2） | → tasks |
| `/o-m-cc:tasks` | タスク分解（SDD Phase 3） | → 実装開始 |
| `/o-m-cc:plan <task>` | 上記を一括実行（scout によるギャップ分析含む） | → 実装開始 |

### 実行

| コマンド | 説明 |
|---------|------|
| `/o-m-cc:ultrawork <task>` | 並列エージェントで最大パフォーマンス実行 |
| `/o-m-cc:ultrawork-compact <task>` | /compact 後に ultrawork |
| `/o-m-cc:ultrawork-clear <task>` | /clear 後に ultrawork |

### 品質

| コマンド | 説明 |
|---------|------|
| `/o-m-cc:review [files]` | コードレビュー（security-guidance連携 + code-simplifier提案） |

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

`/o-m-cc:sisyphus` 実行時に以下のプラグインを確認・インストール：

| プラグイン | 用途 | インストール |
|-----------|------|-------------|
| ralph-wiggum | `<promise>DONE</promise>` までループ継続 | `claude plugin install ralph-wiggum@anthropics` |
| frontend-design | フロントエンド設計支援 | `claude plugin install frontend-design@claude-code-plugins` |
| feature-dev | 機能開発ワークフロー | `claude plugin install feature-dev@claude-code-plugins` |
| code-simplifier | コード簡素化（レビュー後提案） | `claude plugin install code-simplifier@claude-code-plugins` |
| security-guidance | セキュリティレビュー支援 | `claude plugin install security-guidance@claude-code-plugins` |
| pyright-lsp | Python エラー検出 | `claude plugin install pyright-lsp@claude-code-lsps` |
| typescript-lsp | TypeScript エラー検出 | `claude plugin install typescript-lsp@claude-code-lsps` |

## Agents

### Planning Agents（計画系）

| Agent | 役割 | Model |
|-------|------|-------|
| @analyst | 現状分析・要件定義 | sonnet |
| @scout | ギャップ分析・追加質問（必ず質問で終わる） | sonnet |
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
├── brainstorm.md    # ブレインストーミング結果（オプション）
├── requirements.md  # 要件定義（FR-X, NFR-X）
├── design.md        # 設計書（コンポーネント、API）
└── tasks.md         # 実装タスク（依存関係、見積もり）
```

## Structure

```
o-m-cc/
├── .claude-plugin/
│   ├── plugin.json
│   └── marketplace.json
├── agents/
│   ├── analyst.md         # 要件定義
│   ├── scout.md           # ギャップ分析（Prometheus式）
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
│   ├── sisyphus.md        # モード有効化（オンボーディング）
│   ├── requirements.md    # 要件定義
│   ├── design.md          # 設計
│   ├── tasks.md           # タスク分解
│   ├── plan.md            # 計画（オーケストレーター）
│   ├── review.md          # コードレビュー
│   ├── ultrawork.md       # 並列実行
│   ├── ultrawork-compact.md
│   └── ultrawork-clear.md
├── hooks/
│   ├── hooks.json
│   └── stop-guard.sh      # ralph-wiggum連携
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
