# o-m-cc v0.19.0

[English](README_en.md)

**Sisyphus Loop for Claude Code** - TODOが完了するまで止まらないマルチエージェントワークフロー

## Overview

o-m-cc は、Claude Codeに「不屈の開発者」マインドセットを注入するプラグインです。

- **Agent Teams**: TeammateTool による peer-to-peer マルチエージェント協調
- **Sisyphus哲学**: タスク完了まで決して止まらない
- **TODOドリブン**: 明確なタスクリストに基づいて作業
- **仕様駆動開発**: 要件 → 設計 → タスク → 実装の構造化フロー
- **Prometheus式インタビュー**: 計画前にギャップ分析で漏れを発見

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
/o-m-cc:init

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
/o-m-cc:plan "認証システムを実装"
```

計画が完了したら、普通に実装を依頼：

```
「計画に沿って実装を開始して」
```

## Skills

### セットアップ

| スキル | 説明 | 自動発動 |
|--------|------|----------|
| `/o-m-cc:init` | プロジェクト初期化（CLAUDE.md作成 + Sisyphus有効化） | 手動のみ |

> 既存プロジェクト（CLAUDE.md あり）でも `/o-m-cc:init` でOK。Sisyphusセクションのみ追加されます。

### 計画フェーズ（複雑なタスク用）

| スキル | 説明 | Context | 自動発動 |
|--------|------|---------|----------|
| `/o-m-cc:plan <task>` | 要件 → 設計 → タスク分解を一括実行（Agent Teams で並列化 + scout ギャップ分析） | fork | 「計画して」で発動 |

### 品質

| スキル | 説明 | Context | 自動発動 |
|--------|------|---------|----------|
| `/o-m-cc:review [files]` | Agent Teams でコードレビュー（peer-to-peer 議論） | fork | 「レビューして」で発動 |
| `/o-m-cc:quality-gate [files]` | /simplify + Review Council + 静的解析で品質最終確認 | fork | 「品質チェックして」で発動 |
| `/o-m-cc:audit [target]` | エージェント・スキルの品質監査 | - | 手動のみ |

> **Context: fork** - teammate 実行時のコンテキスト汚染を防止。探索結果やレビュー詳細がメイン会話を汚さない。

## Workflow

### 初回セットアップ

```
/o-m-cc:init
  → CLAUDE.md 作成（既存なら Sisyphus セクション追加）
  → .claude/agents/sisyphus.md 配置（デフォルトエージェント）
  → .gitignore、推奨パーミッション設定
```

### 簡単なタスク

```
「○○を修正して」→ TODO → 実装 → /simplify → レビュー → 完了
※ hooks により <promise>DONE</promise> まで自動継続
```

### 複雑なタスク（/o-m-cc:plan）

```
Agent Teams (Council + Pipeline ハイブリッド):
┌─────────────────────────────────────────────────────┐
│              Phase 1: Discovery Council               │
│     researcher ◄─► analyst (Lead) ◄─► scout          │
│         peer-to-peer で findings を共有               │
└─────────────────────────────────────────────────────┘
          │ requirements.md
          ▼
  Phase 2 (designer) → Phase 3 (planner)
  design.md             tasks.md
                           │
          ┌────────────────────────────────┐
          │    Phase 4: Review Council      │
          │    critic (Lead) ◄─► advisor    │
          └────────────────────────────────┘
```

**Phase 1 は Discovery Council、Phase 2-3 は Pipeline、Phase 4 は Review Council**

### 実装フェーズ

```
「実装開始して」
  → Agent Teams → teammate 並列 spawn → /simplify → レビュー → 完了
```

## Dependencies

`/o-m-cc:init` 実行時に推奨プラグインをインストール。

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
├── brainstorm.md       # ブレインストーミング結果（オプション）
├── requirements.md     # 要件定義（FR-X, NFR-X）
├── design.md           # 設計書（コンポーネント、API）
└── tasks.md            # 実装タスク（依存関係、見積もり）
```

## Token Efficiency

> o-m-cc のトークン管理は、"Everything is Context" ([arXiv:2512.05470](https://arxiv.org/abs/2512.05470)) の **Context Constructor**（トークン予算内で選択的にコンテキストをロード）と **Bounded Reasoning**（有限なコンテキスト窓での戦略的取捨選択）を実践的に実装したものです。

### 初期読み込みコスト

o-m-cc プラグインの初期トークン消費:

| カテゴリ | トークン数 | 内訳 |
|---------|-----------|------|
| エージェント | ~780 | 12 エージェント定義 |
| スキル | ~90 | 4 スキル定義 |
| **合計** | **~910** | Opus 1M の約 **0.1%** |

> **Note**: Memory files (CLAUDE.md等) や他プラグインは別途消費。`/clear` 後の表示で確認可能。

### Progressive Disclosure（段階的開示）

エージェント定義を3層に分離し、必要な時だけ深い情報をロードする:

```
Layer 1: frontmatter（常時ロード）  → ~60 tokens/agent
Layer 2: 本文（エージェント起動時）   → ~100-200 tokens/agent
Layer 3: facets/references/（必要時に Read） → ~200-500 tokens/file
```

これにより全情報を常時ロードする場合と比べ、**通常時のトークン消費を約 1/3 に削減**。

### 実行時の効率化

エージェントの出力は **要約 + ログ分離** でトークン消費を抑制。

### 仕組み

```
Teammate → 要約をメッセージで Lead に返却
```

### エージェント出力フォーマット

```markdown
## ✅ [agent-name] 完了

**結果**: 成功 / 失敗 / 要確認
**変更ファイル**:
- path/to/file.ts:45-67
**サマリー**: [1-2文で何をしたか]
```

## 推奨設定（Optional）

| 設定 | 説明 | 設定方法 |
|------|------|---------|
| `includeGitInstructions: false` | git 組み込み指示を無効化（jj 等の代替 VCS ユーザー向け）。システムプロンプトのトークン節約 | `claude config set includeGitInstructions false` |

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
| researcher | コードベース探索・外部調査 | 探索, 検索, どこ, 使い方, ベストプラクティス |
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
| SessionStart | `session-resume.sh` | `.claude/context.md` + `chronicle.md` の文脈表示 |
| SessionStart | `memory-digest.sh` | サブエージェント Memory ダイジェスト表示 |
| Stop | `stop-guard.sh` | Sisyphus ガード（レビュー確認） |
| UserPromptSubmit | `focus-guard.sh` | タスク進行中の脱線防止 |
| PreToolUse | `security_reminder_hook.py` | セキュリティパターン検出 |
| PreCompact | `pre-compact-handover.sh` | compaction 時の文脈自動保存（3層分離） |
| PostToolUse | `auto-verify.sh` | フェーズ完了時の自動検証 |
| TeammateIdle | `teammate-idle.sh` | idle teammate への残タスク再割り当て示唆 |
| TaskCompleted | `task-completed.sh` | タスク完了時の進捗表示・依存タスクアンブロック |

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
│   ├── plan/SKILL.md          # 計画（要件→設計→タスク一括、Agent Teams）
│   ├── quality-gate/SKILL.md  # 品質ゲート（/simplify + Review Council）
│   └── review/SKILL.md        # コードレビュー（Agent Teams 並列）
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
│   ├── auto-verify.sh         # フェーズ完了時の自動検証
│   ├── focus-guard.sh         # タスク進行中の脱線防止
│   ├── teammate-idle.sh       # Teammate idle 時の再割り当て（Agent Teams）
│   ├── task-completed.sh      # タスク完了時の進捗・アンブロック（Agent Teams）
│   ├── security_reminder_hook.py  # セキュリティチェック
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

- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode)
- [ralph-wiggum](https://ghuntley.com/ralph/)

## License

MIT
