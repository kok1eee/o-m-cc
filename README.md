# o-m-cc v0.32.0

[English](README_en.md)

**Sisyphus Loop for Claude Code** - TODOが完了するまで止まらないマルチエージェントワークフロー

## Overview

o-m-cc は、Claude Code に仕様駆動開発（SDD）ワークフローを追加するプラグインです。

- **Skill Chain**: 要件分析 → 設計 → タスク分解 → 実装 → 品質ゲートを独立スキルとして chain 実行。各フェーズのコンテキストが分離される
- **Agent Teams**: peer-to-peer マルチエージェント協調。9の専門エージェントが SendMessage で相互検証
- **diff ベース品質強制**: Stop hook が変更行数を検知し、閾値超過時に quality-gate を自動強制。Claude の出力に依存しない
- **Progressive Disclosure**: エージェント定義を3層に分離し、常時ロードは全体の約10%に抑制

## 動作環境

- **macOS / Linux**: フルサポート
- **Windows**: WSL (Windows Subsystem for Linux) 経由で使用してください

## Quick Start

```bash
# 1. marketplace 追加
claude plugin marketplace add kok1eee/o-m-cc

# 2. プラグインインストール
claude plugin install o-m-cc@kok1eee

# 3. プロジェクト初期化（CLAUDE.md作成 + Sisyphus有効化）
/o-m-cc:install

# 4. あとは普通に作業するだけ
「ログインボタンのバグを修正して」
→ 自動的に Sisyphus モードで動作
```

> Agent Teams は plugin の settings.json で自動的に有効化されます。手動での環境変数設定は不要です。

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
/o-m-cc:sisyphus "認証システムを実装"
```

計画→実装→品質ゲートまで自動で進行。

## Skills

### セットアップ

| スキル | 説明 | 自動発動 |
|--------|------|----------|
| `/o-m-cc:install` | プロジェクト初期化（CLAUDE.md作成 + Sisyphus有効化） | 手動のみ |

> 既存プロジェクト（CLAUDE.md あり）でも `/o-m-cc:install` でOK。Sisyphusセクションのみ追加されます。

### 計画フェーズ

| スキル | 説明 | Context | 自動発動 |
|--------|------|---------|----------|
| `/o-m-cc:deep-interview <idea>` | ソクラテス式要件掘り下げ → discovery-council にハンドオフ | - | 「要件が曖昧」「掘り下げて」「インタビュー」で発動 |
| `/o-m-cc:sisyphus <task>` | 計画→実装→品質ゲートまで止まらない Sisyphus ワークフロー | fork | 「計画して」「この機能を実装したい」で発動 |
| `/o-m-cc:discovery-council <task>` | 3エージェント並列要件分析 Council | fork | 「要件を整理して」「要件定義して」で発動 |
| `/o-m-cc:design` | designer によるアーキテクチャ設計 | - | 「設計して」で発動 |
| `/o-m-cc:task-decomposition` | planner によるタスク分解 | - | 「タスクに分解して」で発動 |

### 品質・運用

| スキル | 説明 | Context | 自動発動 |
|--------|------|---------|----------|
| `/o-m-cc:quality-gate [files]` | Review Council + 静的解析で品質最終確認 | fork | 「レビューして」「品質チェックして」で発動 |
| `/o-m-cc:audit [target]` | エージェント・スキルの品質監査 | - | 手動のみ |
| `/o-m-cc:handover` | セッション文脈を `.claude/context.md` に保存 | - | 「引き継ぎ」「保存して」「今日はここまで」で発動 |

> **Context: fork** — Council 系スキルが fork コンテキストで動くため、teammate のやり取りがメイン会話を汚さない。

## Workflow

### 初回セットアップ

```
/o-m-cc:install
  → CLAUDE.md 作成（既存なら Sisyphus セクション追加）
  → .claude/agents/sisyphus.md 配置（デフォルトエージェント）
  → .gitignore、推奨パーミッション設定
```

### 簡単なタスク

```
「○○を修正して」→ TODO → 実装 → レビュー → 完了
※ stop-guard が diff 変更量を検知し、閾値以上なら /quality-gate を強制
```

### 複雑なタスク（/o-m-cc:sisyphus）

```
Agent Teams (Council + Pipeline ハイブリッド):
┌─────────────────────────────────────────────────────┐
│              Phase 1: Discovery Council               │
│     researcher ◄──► analyst ◄──► scout                │
│         peer-to-peer で findings を共有               │
└─────────────────────────────────────────────────────┘
          │ requirements.md
          ▼
  Phase 2 (designer) → Phase 3 (planner)
  design.md             TaskCreate
                           │
          ┌──────────────────────────────────────────┐
          │         Phase 4: 実装                      │
          │         Phase 5: Quality Gate              │
          │  code-reviewer ◄──► security-reviewer      │
          │         ◄──► critic                        │
          └──────────────────────────────────────────┘
```

**Phase 1 は Discovery Council（peer-to-peer）、Phase 2-3 は Pipeline（順次）**

### 実装フェーズ

```
「実装開始して」
  → Agent Teams → teammate 並列 spawn → レビュー → 完了
```

## Architecture

### Skill Chain（コンテキスト分離）

`/o-m-cc:sisyphus` は各フェーズを独立スキルとして chain 実行する:

```
sisyphus（オーケストレーター）
  → Skill: discovery-council  ← context: fork で分離
  → Skill: design             ← 前フェーズのコンテキストを引き継がない
  → Skill: task-decomposition
  → 実装（メインコンテキスト）
  → Skill: quality-gate       ← context: fork で分離
```

各スキルが `context: fork` で実行されるため、Council の大量のメッセージ交換がメインコンテキストを消費しない。フェーズ間の受け渡しは `plan/requirements.md`、`plan/design.md`、`TaskCreate` というファイル/タスクベース。

### diff ベース品質強制

品質ゲートの強制は Claude の出力に一切依存しない:

```
stop-guard.sh（Stop hook）
  → jj diff --stat で変更行数を取得
  → セッションベースライン（開始時の既存差分）を差し引く
  → SISYPHUS_MIN_DIFF（デフォルト500行）以上なら quality-gate を強制
  → quality-gate 通過は proof ファイル（.claude/quality-gate-proof.json）で検証
```

LLM のトークン消費ゼロで品質チェックの実行を保証する。

### peer-to-peer Council

Council パターン（Discovery Council、Review Council）では全 teammate が対等:

- Lead ロールなし（v0.20.0 で廃止）
- 全員が独立に分析し、SendMessage で findings を相互共有
- 相互検証を経た findings のみを最終報告

## Dependencies

`/o-m-cc:install` 実行時に推奨プラグインをインストール。

```bash
# マーケットプレイス追加（初回のみ）
claude plugin marketplace add anthropics/claude-plugins-official
```

### 開発支援（共通）

| プラグイン | 用途 |
|-----------|------|
| frontend-design | フロントエンド設計支援 |
| feature-dev | 機能開発ワークフロー |
| security-guidance | セキュリティレビュー支援 |

### LSP（言語に応じて選択）

| 言語 | プラグイン | インストール |
|------|-----------|-------------|
| TypeScript/JS/React | vtsls | `claude plugin install vtsls` |
| Python | pyright | `claude plugin install pyright` |
| Go | gopls | `claude plugin install gopls` |
| Rust | rust-analyzer | `claude plugin install rust-analyzer` |

> **Note**: stop-guard は diff の変更量ベースで quality-gate を強制。Claude の出力に依存しない設計。外部プラグイン不要。

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
| @researcher | コードベース探索・外部調査 | sonnet | **plan** | project |
| @debugger | 体系的デバッグ | sonnet | default | project |
| @vision | PDF/画像分析 | sonnet | **plan** | - |

### Implementation Agents（実装系）

| Agent | 役割 | Model | Permission | Memory |
|-------|------|-------|------------|--------|
| @frontend | UI/UXコンポーネント作成 | sonnet | write | project |

### Quality Agents（品質系）

| Agent | 役割 | Model | Permission | Memory |
|-------|------|-------|------------|--------|
| @code-reviewer | コードレビュー | sonnet | default | project |
| @security-reviewer | セキュリティレビュー | sonnet | default | project |

> **Permission**:
> - `plan`: 読み取り専用モード（permissionMode: plan）。権限確認なしで高速動作
> - `write`: 書き込み可能（Write/Edit ツール使用）
> - `default`: Bashなど特殊ツール使用のため標準権限
>
> **Memory**: `project` スコープのエージェントはプロジェクト固有の知見（パターン、規約、過去の判断）を永続的に記憶

## Output Files

計画フェーズで以下のファイルが生成されます：

```
plan/
├── requirements.md     # 要件定義（Discovery Council が生成）
└── design.md           # 設計書（designer が生成）

TaskCreate               # 実装タスク（planner がネイティブタスクシステムに登録）
```

## Token Efficiency

> o-m-cc のトークン管理は、"Everything is Context" ([arXiv:2512.05470](https://arxiv.org/abs/2512.05470)) の **Context Constructor**（トークン予算内で選択的にコンテキストをロード）と **Bounded Reasoning**（有限なコンテキスト窓での戦略的取捨選択）を実践的に実装したものです。

### コンテキスト消費（実測値）

| 層 | サイズ | トークン概算 | ロードタイミング |
|---|---|---|---|
| **Layer 1**: frontmatter | ~10KB | ~3,300-5,000 | 常時（セッション開始時） |
| **Layer 2**: エージェント本文 | ~48KB | ~16,000-24,000 | エージェント spawn 時のみ |
| **Layer 3**: facets/references | ~40KB | ~13,500-20,000 | 必要時に Read |

常時ロード（Layer 1）は全層の約 **10%**。残り 90% はエージェント起動時に必要な分だけロードされる。

> **Note**: 上記は o-m-cc プラグイン自体の消費。実行時には CLAUDE.md、Memory files、他プラグインのコンテキストが加算される。`/clear` 後の表示で確認可能。

### Progressive Disclosure（段階的開示）

エージェント定義を3層に分離し、必要な時だけ深い情報をロードする:

```
Layer 1: frontmatter（常時ロード）  → description, tools, model 等
Layer 2: 本文（エージェント起動時）   → 詳細な振る舞い定義
Layer 3: facets/references/（必要時に Read） → ポリシー、チェックリスト、テンプレート
```

### 実行時の効率化

- **Skill Chain**: 各フェーズが `context: fork` で分離され、Council の大量メッセージがメインコンテキストを消費しない
- **要約返却**: teammate は処理した情報の要約のみを返却（生出力を返さない）
- **diff ベース判定**: stop-guard は hooks だけで完結し、LLM のトークン消費ゼロで品質ゲートを強制

## Agent Capabilities

エージェント選択とディスパッチ戦略の詳細は `agents/capabilities.md` を参照。

## Hooks

o-m-cc は hooks を使って以下の自動化を提供します。

### 概要

| イベント | Hook | Timeout | 説明 |
|---------|------|---------|------|
| SessionStart | `check-dependencies.sh` | 3s | 依存コマンド（jq）の確認 |
| SessionStart | `archive-plans.sh` | 5s | 古いプランファイルをアーカイブ |
| SessionStart | `session-resume.sh` | 3s | `.claude/context.md` + `chronicle.md` の文脈表示 |
| SessionStart | `memory-digest.sh` | 3s | サブエージェント Memory ダイジェスト表示 |
| SessionStart | `session-baseline.sh` | 5s | セッション開始時の diff ベースライン記録 |
| Stop | `stop-guard.sh` | 10s | Sisyphus ガード（diff ベース quality-gate 強制） |
| PreCompact | `pre-compact-handover.sh` | 30s | compaction 時の文脈自動保存（3層分離） |
| PostCompact | `post-compact-resume.sh` | 5s | compaction 後のプロジェクト状態リマインド |
| TaskCompleted | `task-completed.sh` | 5s | タスク完了時の進捗表示・依存タスクアンブロック |
| SessionEnd | `pre-compact-handover.sh` | 30s | セッション終了時の文脈自動保存 |

> **Note**: Claude Code 2.1.50+ では `WorktreeCreate` / `WorktreeRemove` フックイベントが利用可能です。非 git VCS（jj 等）で worktree 分離を使う場合のカスタムセットアップに活用できます。

### デバッグモード

```bash
export O_M_CC_DEBUG=1
claude
```

### エラーログ

hooks のエラーは `.claude/hooks-error.log` に記録されます。

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
│   ├── marketplace.json
│   └── settings.json          # プラグインデフォルト設定（spinnerVerbs, permissions）
├── facets/                    # エージェント横断の共通ポリシー（Faceted Prompting）
│   ├── policies/
│   │   └── confidence-scoring.md  # Confidence Scoring 共通基準
│   └── references/                # 段階的開示（Progressive Disclosure）用リファレンス
│       ├── frontend-design.md     # デザイン哲学・AI Slop回避・実装パターン
│       ├── security-checklist.md  # OWASP Top 10・Rationalizations・Insecure Defaults
│       ├── task-quality.md        # タスクテンプレート・見積もり基準・品質基準
│       ├── gap-analysis.md        # スコープ確認フォーマット・出力テンプレート
│       ├── design-template.md     # design.md 出力テンプレート
│       ├── requirements-template.md # requirements.md 出力テンプレート
│       ├── debugging-methodology.md # 4フェーズ方法論・Red Flags
│       ├── code-review-criteria.md  # レビュー優先順位・Blast Radius
│       ├── thinking-frameworks.md   # First Principles・Inversion・5 Whys
│       ├── plan-review-checklist.md # 完全性・実現可能性・リスク管理チェック
│       ├── vision-formats.md        # 画像/PDF分析フォーマット
│       └── research-depth.md        # 調査深度レベル・回答フォーマット
├── agents/                    # エージェント定義（teammate spawn 時に参照）
│   ├── capabilities.md        # エージェント能力サマリー + キーワード
│   ├── analyst.md             # 要件定義
│   ├── scout.md               # ギャップ分析（Prometheus式）
│   ├── designer.md            # アーキテクチャ設計
│   ├── planner.md             # タスク分解
│   ├── critic.md              # 計画レビュー
│   ├── advisor.md             # 戦略アドバイザー
│   ├── researcher.md          # コードベース探索・外部調査
│   ├── frontend.md            # UI/UXエンジニア
│   ├── vision.md              # マルチモーダル分析
│   ├── debugger.md             # 体系的デバッグ
│   ├── code-reviewer.md       # コード品質レビュー
│   ├── security-reviewer.md   # セキュリティレビュー（並列 spawn 推奨）
├── skills/                    # スラッシュコマンド（スキル）
│   ├── init/SKILL.md          # プロジェクト初期化
│   ├── audit/SKILL.md         # 品質監査
│   ├── sisyphus/SKILL.md      # Sisyphus ワークフロー（計画→実装→品質ゲート）
│   ├── discovery-council/SKILL.md  # 3エージェント並列要件分析 Council
│   ├── design/SKILL.md        # アーキテクチャ設計
│   ├── task-decomposition/SKILL.md  # タスク分解
│   ├── quality-gate/SKILL.md  # 品質ゲート（Review Council + Lint）
│   └── handover/SKILL.md      # セッション文脈保存・引き継ぎ
├── hooks/                     # フック
│   ├── hooks.json             # フック設定
│   ├── lib/
│   │   └── common.sh          # 共通ライブラリ
│   ├── check-dependencies.sh  # 依存コマンド確認
│   ├── archive-plans.sh       # プランアーカイブ
│   ├── session-resume.sh      # 文脈表示（context.md + chronicle.md）
│   ├── memory-digest.sh       # エージェント Memory ダイジェスト
│   ├── pre-compact-handover.sh # compaction 時の文脈自動保存
│   ├── stop-guard.sh          # Sisyphus ガード
│   ├── session-baseline.sh    # セッション開始時の diff ベースライン
│   ├── post-compact-resume.sh # compaction 後の状態リマインド
│   ├── task-completed.sh      # タスク完了時の進捗・アンブロック（Agent Teams）
│   └── reset-state.sh         # 状態リセットツール
├── docs/                      # ドキュメント
│   ├── hooks-guide.md         # Hooks 使い方ガイド
│   └── hooks-errors.md        # エラーリファレンス
├── templates/                 # テンプレート
│   ├── agents/
│   │   └── sisyphus.md        # Sisyphus デフォルトエージェント
│   ├── rules/
│   │   ├── sisyphus.md        # Sisyphus ルール
│   │   └── plan-or-act.md     # Plan or Act ルール
│   └── agent-output-mode.md   # エージェント出力モード設定
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

### なぜマルチエージェントか

「単一セッション内でロールプレイさせれば同じでは？」— 正当な疑問だ。技術的に3つの差異がある：

1. **コンテキスト分離**: 各エージェントは独立コンテキストで動く。単一セッションのロールプレイでは全情報が同一コンテキストに混ざり、analyst の視点で見るべき情報に security-reviewer のバイアスが入る。エージェント分離はこれを防ぐ
2. **並列実行**: Agent Teams で3体同時に分析できる。Discovery Council（researcher + analyst + scout）は並列 spawn で時間コストを削減する。ロールプレイは直列実行しかできない
3. **永続メモリ**: `memory: project` を持つエージェントはプロジェクト固有の知見（パターン、規約、過去の判断）を蓄積する。次のセッションでも引き継がれる。ロールプレイのコンテキストはセッション終了で消える

ただし正直に言うと、12体すべてが常に必要なわけではない。実際のタスクで頻繁に使うのは analyst, designer, planner, code-reviewer, researcher の5〜6体。残りは特定の状況（セキュリティ監査、UI 実装、デバッグ等）で呼ばれる専門家だ。常時ロードは frontmatter のみ（全体の約10%）なので、存在コストは低い。

## Token & Cost

Sisyphus Loop は「止まらない」ことが特徴だが、止まらないことにはコストがある。

### 見積もり

| 設定 | 1イテレーションあたり | 最大（50イテレーション） |
|------|---------------------|----------------------|
| **ループ（メイン）** | ~10K-50K tokens | ~500K-2.5M tokens |
| **Council（Agent Teams）** | ~50K-200K tokens/Council | 計画+レビューで ~400K tokens |
| **合計（大規模タスク）** | — | ~1M-3M tokens |

Max plan（$200/月）でも、大規模タスクを1日に何本も回すとコンテキストが問題になりえる。

### コスト管理の推奨

```bash
# イテレーション数を制限（デフォルト: 50）
export SISYPHUS_MAX_ITERATIONS=20

# quality-gate の閾値を調整（デフォルト: 500行）
export SISYPHUS_MIN_DIFF=500
```

- **小規模タスク**: `MAX_ITERATIONS=10` で十分
- **大規模タスク**: デフォルト（50）のまま。ただし途中で compaction が走る前提で設計されている
- **コストを意識する場合**: エージェントの `model` を `sonnet` に統一する（デフォルト）。`opus` は advisor、designer、quality-gate スキル（200k 超のコンテキスト）

## Configuration

```bash
# quality-gate 強制の最小変更行数（デフォルト: 500行）
export SISYPHUS_MIN_DIFF=500

# 最大イテレーション数（デフォルト: 50）
export SISYPHUS_MAX_ITERATIONS=30
```

### Headless モード（`claude -p` / `CLAUDE_NON_INTERACTIVE=1`）

Headless モードでは AskUserQuestion が使えないため、中間成果物の品質チェックで問題が検出されても人間に確認せず先に進む。不足点は `## 既知の不足` として成果物に追記され、下流エージェント（designer, planner）に伝播するが、quality-gate はこれをレビュー対象外とする（解決不能な問題でループさせない設計）。

通常モードでは品質が崩れた時点で AskUserQuestion で人間に判断を委ねる。

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

### 0.27.0

- **verification スキル**: 完了宣言前に証拠を要求。Adversarial な検証姿勢で「動くはず」を信用しない
- **experiment スキル**: 実験駆動の反復改善ループ（autoresearch パターン）。1回1変更 → Verifier 検証 → 保持 or revert
- **retro スキル**: スキル使用状況・タスク作成ログの分析。未使用スキルの改善/削除判断に
- **全タスク Verifier 必須化**: sisyphus の実装ループで全タスクに Verifier（adversarial 検証）を適用。S/M-L 分岐を廃止
- **3エージェント方式**: Implementer → Verifier → Debugger の役割分離。確認バイアスの構造的排除
- **designer 複数案自律評価**: 内部で3案（Minimal/Clean/Pragmatic）を検討し最良案を自律選択
- **discovery-council 曖昧点確認**: Step 3 に独立した曖昧点確認ステップを追加（スキップ禁止）
- **researcher 重要ファイルリスト**: 調査結果に「メインが Read すべきファイル」5-10件を含める
- **動的コンテキスト注入**: sisyphus/quality-gate/discovery-council に `!`command`` で前処理注入
- **Gotchas セクション**: sisyphus/quality-gate/discovery-council/verification に失敗パターンを追加
- **lint スクリプト化**: quality-gate の静的解析を `bin/lint` として独立コマンド化。ツール未インストール時のスキップ対応
- **スキル使用ログ**: PreToolUse hook で Skill 使用を CLAUDE_PLUGIN_DATA に記録
- **TaskCreated hook**: タスク作成をログし /retro で分析可能に
- **paths glob**: quality-gate/experiment にコードファイルのみ発動する paths 制限
- **セッション横断累積カウント**: stop-guard が CLAUDE_PLUGIN_DATA で未検証行数を引き継ぎ
- **stop-guard 段階制**: 500行〜推奨（初回ブロック）、1000行〜強制
- **diff から .md 除外**: stop-guard/session-baseline のカウントから .md ファイルを除外
- **effort/disallowedTools/maxTurns**: 全エージェント・スキルに frontmatter 拡張を適用
- **session-resume 最適化**: 出力 -41.8%（752→438 bytes）、jq 依存排除
- **memory 蓄積指示**: Verifier/reviewer に繰り返し発見したパターンの memory 保存を指示
- **memory-digest 強化**: 過去の失敗パターンをプロアクティブに表示
- **/init → /install リネーム**: 公式 /init との競合回避。/install は o-m-cc 固有アドオンに特化
- **エージェント整理**: vision/advisor/frontend を削除（12→9体）。ADR-0008
- **ADR 導入**: docs/adr/ に設計判断を記録（8件）
- **initialPrompt**: sisyphus テンプレートエージェントに自動開始プロンプト追加

### 0.23.0

- **review スキルを quality-gate に統合**: review（Review Council のみ）を削除し、quality-gate に吸収。「レビューして」で quality-gate がフルパイプライン実行。スキル数 6→5、トリガー競合解消
- **PostCompact hook 新設**: compaction 後にプロジェクト状態（Intent, 変更行数, Quality Gate, sisyphus フェーズ）を動的取得して system message として出力。compaction summary と重複しない補完情報
- **sisyphus Headless モード**: `-p`（headless）モードで全承認ゲートを自動スキップ。ambient-task-agent 等の headless 環境で完全自律動作

### 0.22.0

- **公式プラグイン連携**: security-guidance, claude-md-management, hookify, plugin-dev, playground と連携。init で自動インストール
- **security hook を公式に委譲**: 独自の `security_reminder_hook.py`（229行）を削除し、公式 `security-guidance` プラグインに一本化。Lightweight 原則の徹底
- **LSP 自動検出**: init でプロジェクト言語（Python/TS/Rust/Go 等 12言語）を検出し、対応 LSP プラグインを自動インストール
- **CLAUDE.md 自動改善**: handover で `/revise-claude-md`（セッション学び反映）、init で `claude-md-improver`（品質監査）を実行
- **security-reviewer 強化**: 公式 security-guidance の検出パターンを参照し、該当パターンの Confidence +10 で優先報告
- **frontend + playground**: frontend エージェントが playground プラグインと連携し HTML プレビュー可能に

### 0.21.2

- **条件付き承認ゲート**: sisyphus 計画フェーズ（要件・設計・タスク分解）に承認ゲート導入。曖昧点がある場合のみ AskUserQuestion で確認、明確な場合は自動承認して進む
- **stop-guard plan/ 除外**: 計画成果物（plan/ 配下）を diff カウントから除外。requirements.md/design.md の生成で quality-gate が誤発火する問題を修正
- **foreground spawn 明記**: Phase 2-3 の designer/planner を foreground で spawn する指示を追加。background spawn による premature stop を防止
- **TeamCreate cleanup**: 全スキル（sisyphus/review/quality-gate）で TeamCreate 前に TeamDelete を実行。前回の残骸による "Already leading team" エラーを防止
- **hook タイムアウト延長**: SessionEnd/PreCompact の pre-compact-handover.sh タイムアウトを 10s → 30s に延長。長いセッションでの Hook cancelled を修正
- **Agent Teams teammate name 必須化**: 全スキルの Agent spawn に name/team_name を明示指定。未指定時の SendMessage silent loss を防止
- **CLAUDE.md 改善**: ディレクトリ構造、Hooks テーブル、テスト・検証コマンドを追加。エージェント数修正（13→12）

### 0.20.1

- **TeammateIdle hook 再有効化**: テストで hooks なしでもフロー成立を確認した上で、TeammateTool 利用時の idle ループ防止として安全弁的に再有効化
- **TaskCompleted hook 削除**: ネイティブ動作で十分と判断し削除。focus-guard, auto-verify も tasks.md 依存のため削除済み

### 0.20.0

- **tasks.md 廃止 → TaskCreate 統一**: `plan/tasks.md` を廃止し、Claude Code ネイティブの `TaskCreate`/`TaskList` に完全移行。planner は TaskCreate のみで出力。hooks は tasks.md 不在時に自動スキップ（graceful degradation）
- **Lead パターン廃止**: 全 Council（Discovery Council, Review Council）から Lead ロールを除去。全 teammate が対等に peer-to-peer で相互検証する設計に統一
- **ワークフロー判断ガイド**: CLAUDE.md に「通常 → `/plan` → `/sisyphus`」の段階的エスカレーションパスを追加。迷ったら `/plan` に入る原則
- **設計原則追加**: 「ネイティブであるほど美しい」— Claude Code ネイティブ機能の積極活用を明文化
- **stop-guard 段階的ブロック**: 初回は decision:block で CTA、2回目以降は exit 2 でハードブロック
- **quality-gate 実行中マーカー**: `.claude/quality-gate-running` で stop-guard の誤ブロック防止
- **Review Council 強化**: HIGH SIGNAL ポリシー（偽陽性排除）、CLAUDE.md コンプライアンスチェック追加

### 0.19.5

- **`/plan → /sisyphus` リネーム**: ビルトイン `/plan`（2.1.72 で引数対応）との競合回避。`skills/plan/` → `skills/sisyphus/` に変更し、sisyphus エージェントのデフォルトを plan モードに反転
- **sisyphus フェーズタスク管理**: SKILL.md に5フェーズの `TaskCreate` 登録（Step 0）、フェーズ遷移テーブル、実装中のタスク管理ルール（Step 6）を追加
- **セッションベースライン差分**: `session-baseline.sh` を SessionStart hook に追加。セッション開始時の diff 行数を記録し、既存の未コミット差分で stop-guard が誤発火するのを防止
- **hooks 出力の公式仕様準拠**: stop-guard を exit 2 → exit 0 + JSON `decision:block` に変更。全 hooks の stdout/stderr を Claude Code の hooks 公式仕様に合わせて整理
- **`SISYPHUS_MIN_DIFF` 閾値変更**: デフォルトを 50 → 200 に変更。CTA をプレーンテキストに簡素化
- **SessionEnd で context.md 自動保存**: `pre-compact-handover.sh` を SessionEnd でも実行し、セッション終了時に文脈を自動保存
- **focus-guard JSON 出力簡素化**: JSON パース失敗による UserPromptSubmit hook error を解消

### 0.19.6

- **quality-gate proof ファイルベース化**: 文字列ベースの `<proof>` マーカーを廃止し、`.claude/quality-gate-proof.json` ファイル書き込み + タイムスタンプ検証に変更。ゲーミング対策
- **stop-guard quality-gate 通過ベースライン**: `passed_at_diff` を state に記録し、quality-gate 通過後の小変更で stop-guard が再発火しない設計。`SISYPHUS_MIN_DIFF` デフォルトを 200 → 500 に変更
- **stop-guard コミット検出リセット**: diff 行数が `passed_at_diff` を下回ったらコミットと判断し state リセット。新セッション開始時に state ファイル削除
- **quality-gate 静的解析ゲート**: proof bash コマンドに Python/Shell/TypeScript/Rust の静的解析を組み込み。`/simplify` とは別ステップであることを明示し Review Council のスキップを防止
- **stop-guard 段階的ブロック**: 初回は exit 0 + JSON `decision:block` で CTA 提示、2回目以降は exit 2 でハードブロック
- **quality-gate 実行中マーカー**: `.claude/quality-gate-running` ファイルで実行状態を伝達し、stop-guard の誤ブロックを防止

### 0.19.4

- **stop-guard diff ベース判定**: `<promise>DONE</promise>` マーカー依存を廃止。`jj diff` / `git diff` の変更行数（デフォルト500行以上）で `/quality-gate` を自動強制する設計に切り替え。Claude の出力に依存しない、hooks だけで完結する品質ゲート
- **stop-guard 簡素化**: 160行 → 82行。スロットリング・transcript フォールバック・複雑な state 管理を削除。ralph-loop 並みのシンプルさで2段チェック（diff + proof）を維持
- **DONE マーカー除去**: templates, skills, hooks, README から `<promise>DONE</promise>` への依存を全面除去
- **`SISYPHUS_MIN_DIFF`**: quality-gate 強制の最小変更行数を環境変数で設定可能（デフォルト: 500行）

### 0.18.1

- **`/simplify` 統合**: Claude Code 2.1.63 で追加された `/simplify`（再利用・品質・効率の自動レビュー+修正）を Sisyphus ワークフローに組み込み。実装 → `/simplify` → レビュー → 完了の流れに
- **`/batch` 対応**: 大規模一括変更用の `/batch` を Sisyphus テンプレートに追加
- **Worktree auto-memory 共有**: 2.1.63 で worktree 間の auto-memory 共有が実装されたことを agent-memory-guidance に反映
- **auto-verify.sh 改善**: 検証成功時に `/simplify` → `/review` の実行を提案するメッセージに変更

### 0.18.0

- **CONTEXT.md 3層アーキテクチャ**: `CONTEXT.md`（1ファイル蓄積）→ `.claude/context.md`（最新1スナップショット）+ `.claude/chronicle.md`（直近30件）+ `.claude/context-archive.md`（全量アーカイブ）の3層分離。PreCompact hook で自動ローテーション
- **explore → researcher 統合**: explore エージェントを researcher に統合。コードベース探索（内部）と外部ドキュメント調査を1エージェントに一本化。エージェント数 13 → 12
- **Learnings → MEMORY.md 自動フロー**: `/o-m-cc:handover` スキルに Learnings チェック機能を追加。長期的価値のある知見を auto-memory に自動追記
- **Skill 提案**: `/o-m-cc:handover` スキルで繰り返しパターンを検知し、プロジェクト専用スキルを提案（自動作成はしない）
- **session-resume.sh**: SessionStart hook で `.claude/context.md` の最新文脈と `.claude/chronicle.md` の経緯を表示
- **pre-compact-handover.sh**: PreCompact hook で compaction 時の文脈を自動保存・3層ローテーション
- **plan スキル修正**: learnings-researcher（存在しないエージェント）→ researcher に統一。`.gitignore` の `plan/` → `/plan/` 修正（`skills/plan/` が VCS から除外されていた問題を解消）

### 0.17.2

- **README 乖離修正**: Quick Start から不要な `export` 削除、Token Efficiency のエージェント数・スキル数を実態に合わせて修正、README_en.md の hooks イベント誤記修正・resume-session 追加、Structure に templates/rules/ 追加
- **CLAUDE.md 設計思想セクション追加**: 7つの設計原則（Peer-to-peer 協調、VCS ベースのナレッジ等）とアンチパターンを明記。原則を損なう提案時に指摘するガード
- **`isolation: worktree` 正式サポート記述**: Claude Code 2.1.50+ で正式サポートされたことを反映
- **エージェントモデル変更**: explore, learnings-researcher を haiku → sonnet に変更

### 0.17.1

- **Hook exit code 2**: TeammateIdle（Stage 1）と TaskCompleted（残タスクあり）で exit code 2 を使用し、teammate に作業続行を直接指示。Lead 経由の再割り当てを待たず自律的にタスクをクレーム
- **`/install` スキル削除**: Plugin settings.json でスピナー・パーミッションが自動配信されるため不要に。`scripts/install-plugins.sh` も削除

### 0.17.0

- **Progressive Disclosure（段階的開示）**: 全エージェント（explore 除く13体）の詳細リファレンスを `facets/references/` に分離。エージェント合計 2107行 → 1403行（-33%）にスリム化し、必要時に Read で適用。13のリファレンスファイルを作成
- **Trigger Phrases**: 全13エージェントの description にユーザー発話例を追加（「レビューして」「セキュリティチェックして」等）。エージェント選択精度の向上
- **Negative Triggers**: 全13エージェントの description に「※〜は X を使う」を追加。類似エージェント間（code-reviewer/security-reviewer、debugger/advisor、analyst/scout 等）の誤発動を防止

### 0.16.0

- **Plugin settings.json**: spinnerVerbs と推奨パーミッションをプラグインデフォルト設定としてシップ
- **Agent `background: true`**: researcher, learnings-researcher, explore にバックグラウンド実行ヒントを追加（I/O集約的な調査を非同期化）
- **Agent `isolation: worktree`**: frontend, designer, planner, debugger に worktree 分離ヒントを追加（並列実行時のファイル競合防止）

### 0.15.0

- **Faceted Prompting**: `facets/policies/confidence-scoring.md` で Confidence Scoring ポリシーを一元管理。code-reviewer / security-reviewer が共通基準を参照
- **集約ロジック**: `all()`/`any()` による明示的な判定条件を review（`all("Critical なし")` → マージ可能）と plan（Phase 1 / Phase 4）に導入
- **spawn prompt 統一**: 全 teammate の spawn prompt を「エージェント定義 / 参照ポリシー / コンテキスト / 入力 / チーム連携 / 出力」の標準構造に統一

### 0.14.0

- **commands/ → skills/ 移行**: `commands/*.md`（フラットファイル）→ `skills/*/SKILL.md`（ディレクトリ構造）に移行
- **disable-model-invocation**: init/audit/promote の3スキルに `disable-model-invocation: true` を追加（意図しない自動発動を防止）
- **自動発動スキル**: plan（「計画して」）、review（「レビューして」）、handover（「引き継ぎ」）はモデル判断で自動発動

### 0.13.0

- **Cross-Project Skill Discovery**: `promote-checker` が繰り返しパターンを `~/.claude/skill-candidates.md` にグローバル蓄積
- **自動スキル昇格**: promote-checker が提案ではなく自動でスキル昇格を実行（複数プロジェクト → グローバルルール、単一プロジェクト → プロジェクトルール）
- **/promote クロスプロジェクト対応**: `~/.claude/skill-candidates.md`（クロスプロジェクト）+ HANDOVER.md VCS 履歴（ローカル）を統合して候補提示
- **/promote 昇格先拡張**: エージェント / コマンド / プロジェクトルール / グローバルルール（`~/.claude/CLAUDE.md`）の4択に

### 0.12.0

- **spec/ 簡素化**: `spec/standards/`, `spec/steering/`, `spec/rules/` を廃止。CLAUDE.md が唯一のプロジェクト規約・文脈のソース
- **エージェント更新**: 5つのエージェント（code-reviewer, designer, frontend, planner, analyst）から Standards/Steering 参照セクションを削除
- **/init 簡素化**: コードベース分析・ヒアリングによる spec/standards/ 等の生成を廃止。plan/ のみ作成
- **ultrawork / orchestration.yml 廃止**: capabilities.md のディスパッチ戦略 + ネイティブタスクシステムで代替
- **plan/logs/ 廃止**: teammate の出力はメッセージで Lead に返却する方式に統一
- **auto-verify.sh**: verify.json パスを `spec/steering/verify.json` → `.claude/verify.json` に変更

### 0.11.0

- **learned/ 廃止**: `spec/standards/learned/`、`/learn` コマンド、`pattern-detector.sh` hook を削除
- **HANDOVER.md VCS 管理化**: `.gitignore` から除外し、セッションごとの diff 履歴として教訓を蓄積
- **/promote 刷新**: learned/ 検索 → HANDOVER.md の VCS 履歴横断検索でパターン発見・スキル昇格
- **learnings-researcher 更新**: 検索対象を HANDOVER.md VCS 履歴 + claude-mem に変更（レガシー learned/ フォールバック付き）
- **code-reviewer / security-reviewer 簡素化**: learned/ 自動記録セクションを削除
- **promote-checker.sh**: Stop hook で HANDOVER.md VCS 履歴から繰り返しパターンを自動検出し `/promote` を提案
- **standards/steering テンプレート廃止**: 空テンプレートを削除。`/init` がコードベース分析またはヒアリングから生成
- **setup-project.sh 削除**: テンプレートコピーが不要になったため

### 0.10.0

- **Council + Pipeline ハイブリッド化**: `/plan` フローを Council 型と Pipeline 型の組み合わせに再構成
  - Phase 1: Discovery Council（learnings-researcher + analyst + scout が同時 spawn + peer-to-peer 共有）
  - Phase 4: Review Council（critic + advisor が同時 spawn + peer-to-peer 共有）
  - Phase 2-3: Pipeline（designer, planner）は変更なし
- **Sisyphus Default Agent**: `templates/agents/sisyphus.md` — 振る舞い定義を CLAUDE.md から分離
  - `claude --agent sisyphus` または settings.json の `"agent": "sisyphus"` で有効化
- **推奨パーミッション自動設定**: `/init` Step 6 で `.claude/settings.json` に事前承認を追加
- **Plan or Act ルール**: タスク複雑度による自動モード切替テンプレートを追加

### 0.9.0

- **claude-mem 連携**: セマンティックメモリ検索を全エージェントに提供
- **learnings-researcher 強化**: claude-mem セマンティック検索をプライマリに、Grep をフォールバックに
- ~~`/install` に claude-mem セットアップステップ追加~~（v0.17.0 で `/install` 削除）
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
- **新コマンド**: `/audit`（品質監査）、`/learn`（学び記録）、`/promote`（スキル昇格）
- **新hooks**: ~~agent-rules.json、suggest-agent.sh~~（v0.12.0 で削除、capabilities.md のディスパッチ戦略に統合）
- **security-reviewer 強化**: Trail of Bits パターン（Rationalizations、Insecure Defaults、Sharp Edges）
- **code-reviewer 強化**: Blast Radius 分析（変更の影響範囲定量化）
- **ワンショット改善**: scout の「必ず質問で終わる」を廃止、plan/init/audit の不要な確認を削除
- **plan 簡素化**: Step 0-2（コンテキスト管理・ブレインストーミング・実行方式確認）を削除、一括実行がデフォルト

### 0.6.0 (Breaking Change)

- **ディレクトリ構造変更**: `.claude/` → `spec/` に移行
  - `spec/standards/` - 技術規約
  - `spec/steering/` - プロジェクト文脈
  - `spec/rules/` - Sisyphus ルール
  - `plan/` - 計画ファイル（requirements, design, tasks）
- `.claude/` 全体を gitignore 推奨（Claude Code 内部用）
- Token Efficiency セクションに初期読み込みコストを追加

### 0.5.x

- 初期リリース
- Sisyphus Loop、SDD フロー、13 エージェント

## Inspired By

- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) — マルチエージェントの原型。中央オーケストレーター型を peer-to-peer に再設計
- [ralph-wiggum](https://ghuntley.com/ralph/) — Stop Hook によるループ継続パターン

## License

MIT
