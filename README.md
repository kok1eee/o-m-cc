# o-m-cc v0.58.0

[English](README_en.md)

**Sisyphus Loop for Claude Code** - TODOが完了するまで止まらないマルチエージェントワークフロー

## Overview

o-m-cc は、Claude Code に仕様駆動開発（SDD）ワークフローを追加するプラグインです。

- **Skill Chain**: 要件分析 → 設計 → タスク分解 → 実装 → 品質ゲートを独立スキルとして chain 実行。各フェーズのコンテキストが分離される
- **Agent Teams**: peer-to-peer マルチエージェント協調。14 の専門エージェントが SendMessage で相互検証（コード品質一般は built-in `Skill: simplify` に委譲）
- **Monitor 統合**: experiment/quality-gate/sisyphus で Monitor ツールを活用し、長時間処理を非同期化
- **二段階検証**: verification（自己エビデンス収集）+ Verifier agent（独立 adversarial 検証）で実装者バイアスを排除
- **Progressive Disclosure**: エージェント定義を3層に分離し、常時ロードは全体の約10%に抑制

## 動作環境

- **macOS / Linux**: フルサポート
- **Windows**: WSL (Windows Subsystem for Linux) 経由で使用してください
- **Claude Code v2.1.108+**: built-in `/recap` をセッション文脈の復元に利用します。v2.1.110+ なら telemetry 無効環境（Bedrock / Vertex / `DISABLE_TELEMETRY`）でも `/recap` が動作します
- **jq**: hooks 用（`brew install jq` / `apt install jq`）

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

合計 15 スキル（セットアップ 1 + 計画 6 + 検証 2 + 実験・学習 2 + 運用 4）。

### セットアップ

| スキル | 説明 | 自動発動 |
|--------|------|----------|
| `/o-m-cc:install` | プロジェクト初期化（CLAUDE.md作成 + Sisyphus有効化） | 手動のみ |

> 既存プロジェクト（CLAUDE.md あり）でも `/o-m-cc:install` でOK。Sisyphusセクションのみ追加されます。

### 計画フェーズ

| スキル | 説明 | Context | 自動発動 |
|--------|------|---------|----------|
| `/o-m-cc:deep-interview <idea>` | ソクラテス式要件掘り下げ → discovery-council にハンドオフ | - | 「要件が曖昧」「掘り下げて」「インタビュー」で発動 |
| `/o-m-cc:feature-flow <feature>` | web アプリ機能を 5 フェーズで構造化（2 モード + 並列 3 エージェント Prior Art + Reader Test） | - | 「機能を考えたい」「web アプリ作りたい」「機能から設計」で発動 |
| `/o-m-cc:sisyphus <task>` | 計画→実装→品質ゲートまで止まらない Sisyphus ワークフロー | fork | 「計画して」「この機能を実装したい」で発動 |
| `/o-m-cc:discovery-council <task>` | 3エージェント並列要件分析 Council | fork | 「要件を整理して」「要件定義して」で発動 |
| `/o-m-cc:design` | designer によるアーキテクチャ設計 | - | 「設計して」で発動 |
| `/o-m-cc:task-decomposition` | planner によるタスク分解 | - | 「タスクに分解して」で発動 |

> **棲み分け**: `deep-interview`（曖昧アイデア → 5軸サマリー） → `feature-flow`（機能 → 構造化 spec） → `discovery-council`（複数機能 → requirements.md）の順で詳細度が上がる。単一機能なら `feature-flow` から、要件統合まで必要なら `discovery-council` も使う。

### 検証

| スキル | 説明 | Context | 自動発動 |
|--------|------|---------|----------|
| `/o-m-cc:quality-gate [files]` | Review Council + 静的解析（Monitor 並列ストリーミング） | fork | 「レビューして」「品質チェックして」で発動 |
| `/o-m-cc:verification` | 完了宣言前の証拠収集（Iron Law: 実行し出力を確認するまで成功と言わない） | - | 「完了前チェック」「本当に動く？」「検証して」で発動 |

### 実験・学習

| スキル | 説明 | Context | 自動発動 |
|--------|------|---------|----------|
| `/o-m-cc:experiment <goal>` | autoresearch 方式の反復改善ループ（試す→測る→保持 or revert） | - | 「最適化して」「試行錯誤して」で発動 |
| `/o-m-cc:evolve` | スキルの自己進化（auto-memory から学びを抽出し各スキルの Gotchas に反映） | - | PreCompact hook が CTA、手動でも呼び出し可 |

### 運用

| スキル | 説明 | Context | 自動発動 |
|--------|------|---------|----------|
| `/o-m-cc:handoff` | **EC2 など別マシンへの引き継ぎの中核**。Recap（LLM 要約）+ Next Actions を `.claude/journal.md`（VCS 共有）に追記。built-in `/recap` はローカル端末固有で補えない跨マシン引き継ぎの役割を担う。同一マシンのセッション区切りにも使える | - | 「EC2 に引き継ぎ」「別マシンに渡したい」「handoff」「引き継ぎ」で発動 |
| `/o-m-cc:ui-polish <target>` | 既存画面の UI polish / 複数画面の redesign 統一 / a11y 対応 / CSS 一貫性修正を軽量ループで実装（Council なし、tsc/lint のみゲート）。新規デザイン生成は外部プラグイン `frontend-design` | - | 「UI polish」「画面統一」「a11y 対応」「CSS 統一」で発動 |
| `/o-m-cc:editorial-swarm <article>` | 4 エージェント並列による記事推敲 Council（anti-ai-slop / fact-checker / narrative-critic / reader-advocate）。severity 付き findings → low 自動 apply、medium/high は一括承認 → 最大 3 ラウンドで収束 | fork | 「記事レビュー」「editorial swarm」「編集会議」「記事推敲」「記事添削」で発動 |
| `/o-m-cc:atom-suggest` | atoms.csv / pipeline.csv / outputs.csv / skill-usage.csv / skill-duration.csv / context.md を統合分析。Backlog issues（stale / promote-ready / stuck / orphan）+ Skill health（top / duration-stats / unused）+ Activity pulse（直近 7 日）を 1 レポートで提示 | - | 「次に何やる？」「atom 整理」「放置案件」「振り返り」「retro」「skill 使用統計」「unused skill」「atom-suggest」で発動 |

> **Context: fork** — Council 系スキル（quality-gate, discovery-council, sisyphus）が fork コンテキストで動くため、teammate のやり取りがメイン会話を汚さない。

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
※ 実装後、push 前に PreToolUse(Bash) hook が quality-gate を促す CTA を表示
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
          │  Skill: simplify (built-in)                │
          │     ↓                                      │
          │  lint + ty (Monitor 並列)                   │
          │     ↓                                      │
          │  条件付き Council:                          │
          │    security-reviewer (security 系変更時)   │
          │    critic (plan/requirements.md ありのみ)  │
          └──────────────────────────────────────────┘
```

**Phase 1 は Discovery Council（peer-to-peer）、Phase 2-3 は Pipeline（順次）**

> **推奨モデル**: Claude Code v2.1.111+ の Max 契約なら **Opus 4.7 + Auto mode** が `/o-m-cc:sisyphus` のような長時間ループと相性が良い（`--enable-auto-mode` は不要）。`/effort xhigh` で速度と知能のバランス調整も可能。

### 実装フェーズ

```
「実装開始して」
  → Agent Teams → teammate 並列 spawn → レビュー → 完了
```

## Architecture

### Guides × Sensors（Harness Engineering の 2 軸）

o-m-cc は Harness Engineering の「事前制御 / 事後検知」2 軸で設計されている:

| 軸 | 役割 | o-m-cc の実装 |
|---|---|---|
| **Guides**（前方制御） | 行動を事前に方向づける | CLAUDE.md / skill 定義 / agent description / TaskCreate |
| **Sensors**（後方制御） | 結果を事後に検知して軌道修正 | `quality-gate-cta.sh`（push 前 CTA） / `subagent-verify.sh` / `bin/validate-plan`（Layer 1 形式チェック） / `evolve`（Gotchas 自動反映） |

Guides だけでは「誘導したつもり」になりがちなので、重要な判断ポイントには必ず Sensors を配置する（例: sisyphus Step 0A は Guides、quality-gate の実装範囲検証は Sensors）。

### データレイヤー（スキル間で共有される状態）

スキルはコンテキスト（会話履歴）ではなく、**ファイルとネイティブ状態** を介して連携する。これにより別セッション / 別マシン / 別スキルから再開できる:

| 場所 | Writer | Reader | 用途 |
|---|---|---|---|
| `.claude/atoms.csv` | `bin/atoms add` / 手動 | atom-suggest | アイデア・構想バックログ（kawai 氏 atoms 相当）|
| `.claude/pipeline.csv` | `bin/atoms promote` | atom-suggest, designer | 要件化フェーズ（atoms ↔ plan/*.md の橋渡し）|
| `.claude/outputs.csv` | `bin/atoms complete` | atom-suggest | 完了履歴（成果物 path + outcome + metric）|
| `plan/requirements.md` | discovery-council, deep-interview | designer, critic, quality-gate | 要件定義（FR-X 形式） |
| `plan/design.md` | designer | planner, critic, quality-gate | アーキテクチャ設計 |
| `plan/archive/<timestamp>-<slug>/` | sisyphus Step 0B | — | 旧 plan の履歴保全（v0.45.0 以降、rm しない） |
| `plan/progress.md` | experiment | experiment（次 iteration） | 試行履歴（keep/revert 判断） |
| TaskCreate / TaskUpdate | planner, sisyphus | 全 teammate | ネイティブタスクリスト（Claude Code 機能） |
| `.claude/journal.md` | handoff | session-resume.sh, 別マシン | EC2 跨ぎ引き継ぎ（Recap + Next Actions） |
| `.claude/memory/` | Claude Code auto-memory | 全スキル次回セッション | auto-memory（プロファイル・フィードバック・プロジェクト知見） |
| Gotchas セクション（各 SKILL.md） | evolve | 次回スキル起動時 | スキル固有の実行経験から抽出した学び |
| `.editorial/round-N/` | editorial-swarm | editorial-swarm（次 round） | 記事レビューの findings / diff 履歴 |
| `${CLAUDE_PLUGIN_DATA}/skill-usage.csv` | skill-usage-log.sh / skill-prompt-log.sh hooks | atom-suggest, evolve | スキル使用履歴（CSV: timestamp,skill,trigger,session_id,effort。trigger ∈ claude-proactive / user-slash。session_id は Claude Code v2.1.132+、effort は v2.1.133+ で記録）|
| `${CLAUDE_PLUGIN_DATA}/skill-duration.csv` | skill-duration-log.sh hook | atom-suggest | スキル実行時間（CSV: timestamp,skill,duration_ms）|

**原則**: コンテキスト再構築コストをゼロにする。A スキルの出力を B スキルが読むとき、A の文脈を知る必要はなく、成果物ファイルだけで完結する。

> ⚠️ **`claude project purge` は破壊的**: このコマンドは `.claude/` 配下を物理削除する。`.claude/atoms.csv` / `.claude/pipeline.csv` / `.claude/outputs.csv` / `.claude/journal.md` は kawai 氏型 analytics ループと跨マシン handoff の中核データなので、**purge 前に必ず VCS にコミットして退避**すること。誤って purge した場合は `jj op log` / `git reflog` から `.claude/` をチェックアウトし直して復旧できる（VCS にコミット済みであれば）。`.claude/memory/`（auto-memory）も同様。プロジェクトを完全リセットする目的でない限り `purge` は使わない。

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

### 品質ゲート CTA

品質チェックのリマインドは hooks で自動化されている:

```
quality-gate-cta.sh（PreToolUse:Bash hook）
  → push 系コマンド（jj git push / git push / gh pr create 等）を検知
  → 変更があれば "/quality-gate 実行済みですか？" と stderr に CTA 表示
  → 強制はしない（non-blocking）、ユーザー判断を尊重

subagent-verify.sh（SubagentStop hook）
  → サブエージェント成果物の検証
```

Monitor ツール（Claude Code 2.1.98+）と組み合わせて、lint/test を並列ストリーミング実行。

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

> **Note**: quality-gate は PreToolUse(Bash) hook の CTA と verification skill の組み合わせで発動。強制はしない non-blocking 設計。

## Agents

合計 14 エージェント（計画 5 + 分析 2 + 品質 1 + Prior Art 6）+ capabilities（メタ：選択・ディスパッチの参照ドキュメント）。コード品質一般は built-in `Skill: simplify` に一任（v0.58.0 で旧 code-reviewer agent を削除）。

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
| @researcher | コードベース探索・外部調査 | sonnet | **plan** | project |
| @debugger | 体系的デバッグ | sonnet | default | project |

### Quality Agents（品質系）

| Agent | 役割 | Model | Permission | Memory |
|-------|------|-------|------------|--------|
| @security-reviewer | セキュリティレビュー（OWASP Top 10、認証認可、入力検証） | sonnet | default | project |

> **コード品質一般**は v0.58.0 から built-in `Skill: simplify` に一任（重複・hacky・効率・不要コメント）。旧 `code-reviewer` agent は同 version で削除。

### Prior Art Agents（feature-flow Phase B 専用）

新規 web アプリ機能を作る前の **Prior Art 並列調査** で起動される。3 体ずつ 2 グループ。

**Mode 1（最初から / 外向き）**

| Agent | 役割 | Model | Permission | Memory |
|-------|------|-------|------------|--------|
| @market-researcher | 商用 SaaS / 既製アプリ調査（作る vs 買う判断） | sonnet | **plan** | project |
| @oss-scout | OSS / GitHub の類似実装調査（依存 / フォーク / 参考 / 不採用判定） | sonnet | **plan** | project |
| @pattern-observer | UI/UX パターン観察（共通 / 差別化 / アンチパターン分類） | sonnet | **plan** | project |

**Mode 2（途中から / 内向き）**

| Agent | 役割 | Model | Permission | Memory |
|-------|------|-------|------------|--------|
| @code-explorer | 既存類似機能のエントリポイントから実装をトレース | sonnet | **plan** | project |
| @architecture-mapper | 既存抽象境界・データモデルのマッピングと配置候補提示 | sonnet | **plan** | project |
| @convention-scout | 命名・配置・テスト・コーディング規約の抽出 | sonnet | **plan** | project |

### Meta

| Agent | 役割 |
|-------|------|
| @capabilities | エージェント選択とディスパッチ戦略の参照ドキュメント |

> **Permission**:
> - `plan`: 読み取り専用モード（permissionMode: plan）。権限確認なしで高速動作
> - `write`: 書き込み可能（Write/Edit ツール使用）
> - `default`: Bashなど特殊ツール使用のため標準権限
>
> **Memory**: `project` スコープのエージェントはプロジェクト固有の知見（パターン、規約、過去の判断）を永続的に記憶
>
> **削除されたエージェント**（v0.27.0 ADR-0008）: @advisor, @vision, @frontend。機能は他エージェントに統合、あるいは公式プラグイン（frontend-design 等）に委譲

## Output Files

計画フェーズで以下のファイルが生成されます：

```
plan/
├── YYYY-MM-DD-feature-<slug>.md  # 機能 spec（feature-flow が生成、日付付き）
├── requirements.md                # 要件定義（Discovery Council が生成）
└── design.md                      # 設計書（designer が生成）

TaskCreate                          # 実装タスク（planner がネイティブタスクシステムに登録）
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
- **Monitor 非同期化**: 長時間の lint/test を Monitor で並列ストリーミング。待ち時間中に次の作業を進められる

## Agent Capabilities

エージェント選択とディスパッチ戦略の詳細は `agents/capabilities.md` を参照。

## Hooks

o-m-cc は hooks を使って以下の自動化を提供します。

### 概要

| イベント | Matcher | Hook | 説明 |
|---------|---------|------|------|
| SessionStart | - | `check-dependencies.sh` | 依存コマンド（jq 等）の確認 |
| SessionStart | - | `archive-plans.sh` | 古い plan/ ファイルをアーカイブ |
| SessionStart | - | `session-resume.sh` | `.claude/journal.md` の最新エントリ（Recap + Next Actions）を表示（resume 時は built-in `/recap` も併用可） |
| SessionStart | - | `memory-digest.sh` | サブエージェント Memory ダイジェスト |
| SessionStart | - | `plugin-data-init.sh` | `CLAUDE_PLUGIN_DATA` 初期化 |
| SessionStart | - | `dotfiles-pull.sh` | dotfiles repo を24h throttle で自動 pull（bg 実行） |
| PreToolUse | `Skill` | `skill-usage-log.sh` | スキル使用ログを記録（/atom-suggest で集計可能） |
| PreToolUse | `Bash` | `quality-gate-cta.sh` | push 系コマンド前に quality-gate を促す CTA |
| PreToolUse | `Bash` | `simplify-diff-gate.sh` | push 系コマンド前に diff 行数をチェック。閾値（default 500、`SIMPLIFY_DIFF_THRESHOLD` で上書き可）を超え かつ 最終コミット以降に `/simplify` 未実行なら **exit 2 で block**（強制 gate） |
| PostToolUse | `ExitPlanMode` | `plan-mode-exit-cta.sh` | plan 完了時に /o-m-cc:sisyphus 実行を促す CTA |
| SubagentStop | - | `subagent-verify.sh` | サブエージェント成果物の検証 |
| TaskCreated | - | `task-created-log.sh` | タスク作成ログ（/atom-suggest で集計可能） |
| TaskCompleted | - | `task-completed.sh` | タスク完了通知・依存タスクアンブロック |
| PermissionDenied | - | `permission-denied.sh` | 拒否ログ + 代替提案 |

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

### Hook の型（Claude Code 仕様）

Claude Code の hook は **4種類の型** をサポート（公式ドキュメントで確認、2025年末の流出コード分析で言及された「5種類」は不正確）:

| 型 | 用途 | o-m-cc の使用 |
|---|---|---|
| `command` | シェルコマンド実行 | ✅ 全 hook（13個）で使用 |
| `prompt` | LLM による文脈判断・注入 | ⚪ 未使用（決定的処理なので `command` で十分） |
| `agent` | サブエージェントによる検証ループ | ⚪ 未使用（spawn コスト高） |
| `http` | Webhook POST | ⚪ 未使用 |

o-m-cc の hook は全て決定的（deterministic）処理なので `command` 型で最適。`prompt` 型が有効なのは「LLM 判断が必要」なケース（例: コンテンツモデレーション、状況に応じた動的文脈注入）のみ。

## Structure

```
o-m-cc/
├── .claude-plugin/
│   ├── plugin.json            # version, name, description
│   ├── marketplace.json       # git marketplace 配布設定
│   └── settings.json          # プラグインデフォルト設定（spinnerVerbs, permissions）
├── facets/                    # エージェント横断の共通ポリシー（Faceted Prompting）
│   ├── policies/
│   │   └── confidence-scoring.md  # Confidence Scoring 共通基準
│   └── references/                # Progressive Disclosure 用リファレンス（10個）
│       ├── code-review-criteria.md    # レビュー優先順位・Blast Radius
│       ├── debugging-methodology.md   # 4フェーズ方法論・Red Flags
│       ├── design-template.md         # design.md 出力テンプレート
│       ├── frontend-design.md         # デザイン哲学・AI Slop回避・実装パターン
│       ├── gap-analysis.md            # スコープ確認フォーマット・出力テンプレート
│       ├── plan-review-checklist.md   # 完全性・実現可能性・リスク管理チェック
│       ├── requirements-template.md   # requirements.md 出力テンプレート
│       ├── research-depth.md          # 調査深度レベル・回答フォーマット
│       ├── security-checklist.md      # OWASP Top 10・Rationalizations・Insecure Defaults
│       └── task-quality.md            # タスクテンプレート・見積もり基準・品質基準
├── agents/                    # 14 エージェント定義 + capabilities (meta)
│   ├── capabilities.md        # エージェント能力サマリー + キーワード
│   ├── analyst.md             # 要件定義
│   ├── scout.md               # ギャップ分析（Prometheus式）
│   ├── designer.md            # アーキテクチャ設計
│   ├── planner.md             # タスク分解
│   ├── critic.md              # 計画レビュー
│   ├── researcher.md          # コードベース探索・外部調査
│   ├── debugger.md            # 体系的デバッグ
│   └── security-reviewer.md   # セキュリティレビュー（OWASP / 認証認可）
├── bin/                       # CLI ユーティリティ（Bash tool から直接実行可能）
│   ├── validate-plan          # plan ドキュメントの形式検証
│   ├── lint                   # 言語別 lint 一括実行
│   ├── check-consistency      # agents/skills 数 + version 表記の一貫性検証
│   ├── atoms                  # atoms.csv / pipeline.csv / outputs.csv 操作（add/promote/complete/archive）
│   └── atom-suggest           # backlog 分析と次アクション提案（macro 視点）
├── skills/                    # 15 スキル定義
│   ├── install/SKILL.md
│   ├── deep-interview/SKILL.md
│   ├── feature-flow/SKILL.md
│   ├── sisyphus/SKILL.md
│   ├── discovery-council/SKILL.md
│   ├── design/SKILL.md
│   ├── task-decomposition/SKILL.md
│   ├── quality-gate/SKILL.md
│   ├── verification/SKILL.md
│   ├── experiment/SKILL.md
│   ├── evolve/SKILL.md
│   ├── handoff/SKILL.md
│   ├── ui-polish/SKILL.md
│   ├── editorial-swarm/SKILL.md
│   └── atom-suggest/SKILL.md
├── hooks/                     # 11 フック + hooks.json
│   ├── hooks.json             # フックイベントマッピング
│   ├── lib/                   # 共通ライブラリ
│   ├── check-dependencies.sh
│   ├── archive-plans.sh
│   ├── session-resume.sh      # journal.md の最新エントリ（Recap + Next）を表示
│   ├── memory-digest.sh
│   ├── plugin-data-init.sh
│   ├── dotfiles-pull.sh       # dotfiles を 24h throttle で自動 pull
│   ├── skill-usage-log.sh     # スキル使用ログ
│   ├── quality-gate-cta.sh    # push 前の quality-gate CTA
│   ├── plan-mode-exit-cta.sh  # plan mode 終了時に sisyphus を促す
│   ├── subagent-verify.sh     # サブエージェント成果物検証
│   ├── task-created-log.sh    # タスク作成ログ
│   ├── task-completed.sh      # タスク完了通知・アンブロック
│   ├── permission-denied.sh
│   └── reset-state.sh         # 状態リセットツール
├── docs/
│   ├── adr/                   # Architecture Decision Records
│   ├── hooks-guide.md
│   └── hooks-errors.md
├── templates/                 # 初期セットアップ用テンプレート
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

ただし正直に言うと、全体すべてが常に必要なわけではない。実際のタスクで頻繁に使うのは analyst, designer, planner, researcher の4〜5体。残りは特定の状況（セキュリティ監査、デバッグ、ギャップ分析等）で呼ばれる専門家だ。常時ロードは frontmatter のみ（全体の約10%）なので、存在コストは低い。コード品質一般のレビューは built-in `Skill: simplify` に一任（旧 code-reviewer agent は v0.58.0 で削除）。

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

- **小規模タスク**: `/o-m-cc:sisyphus` を使わず、普通に指示するか `/o-m-cc:experiment` で試行錯誤
- **大規模タスク**: `/o-m-cc:sisyphus` は途中で compaction が走る前提で設計されている
- **コストを意識する場合**: エージェントの `model` を `sonnet` に統一（デフォルト）。`opus` は designer、quality-gate、sisyphus（200k 超のコンテキスト）

> **Note (Claude Code v2.1.128+)**: sub-agent progress summary の prompt cache が修正され、Council 系スキル（`discovery-council` / `quality-gate` / `editorial-swarm`）の `cache_creation` トークンが **約 3 倍削減**された。上記の見積もりは v2.1.127 以前のもので、最新版では Council コストはより低くなる傾向。

## Configuration

特別な環境変数の設定は不要。主な動作は plugin.json + settings.json + hooks.json で完結。

| 環境変数 | 用途 |
|---|---|
| `CLAUDE_NON_INTERACTIVE=1` | Headless モード。AskUserQuestion をスキップして先に進む |
| `O_M_CC_DEBUG=1` | hooks のデバッグ出力を有効化 |

### Headless モード（`claude -p` / `CLAUDE_NON_INTERACTIVE=1`）

Headless モードでは AskUserQuestion が使えないため、中間成果物の品質チェックで問題が検出されても人間に確認せず先に進む。不足点は `## 既知の不足` として成果物に追記され、下流エージェント（designer, planner）に伝播するが、quality-gate はこれをレビュー対象外とする（解決不能な問題でループさせない設計）。

通常モードでは品質が崩れた時点で AskUserQuestion で人間に判断を委ねる。

### 推奨 settings.json（`~/.claude/settings.json`）

o-m-cc を快適 / 安全に使うための推奨設定:

```jsonc
{
  // [v2.1.133+] worktree.baseRef のデフォルトが fresh (origin/<default>) に
  // revert されたため、isolation: worktree を使う o-m-cc エージェント
  // (designer / planner / debugger) で unpushed commits が dropped される。
  // head に明示しておくと従来通り local HEAD を起点に worktree が切られる
  "worktree": {
    "baseRef": "head"
  },

  // [v2.1.136+] auto mode で「絶対拒否」のルール。permissions.deny は
  // user 確認を経由しうるが、autoMode.hard_deny は user intent / allow
  // exceptions に関係なく block。Sisyphus 自動ループ中の暴走を二重防御
  "autoMode": {
    "hard_deny": [
      "Bash(rm -rf /*)",
      "Bash(sudo rm -rf /*)",
      "Bash(dd if=/dev/zero of=*)",
      "Bash(mkfs.:*)",
      "Bash(git push --force*)",
      "Bash(git reset --hard origin*)",
      "Bash(*--no-verify*)"
    ]
  }
}
```

`hard_deny` の中身は環境ごとに調整。CI / 個人 dev 環境で必要な操作まで block しないよう、最初は最小限から始めて、Sisyphus が誤実行しそうなコマンドを観測しながら追加する。

## CLAUDE.md のベストプラクティス

Claude Code の CLAUDE.md は **毎ターン再注入される** 特殊な位置付けのファイル（2025年末の流出コード分析で判明）。o-m-cc では以下の運用を推奨:

### 階層構造

| ファイル | 用途 | VCS |
|---|---|---|
| `~/.claude/CLAUDE.md` | グローバル：個人のコーディングスタイル・好み | dotfiles git |
| `./CLAUDE.md` | プロジェクト：アーキテクチャ判断、設計原則、アンチパターン警告 | project git |
| `.claude/rules/*.md` | モジュール化ルール（言語別、ツール別） | project git（任意で dotfiles 共有）|
| `CLAUDE.local.md` | 個人メモ、一時的な注意点（`.gitignore` 対象） | **gitignore** |

### サイズの目安

- **上限**: 40,000 文字程度（Claude Code 内部仕様）
- **推奨**: 2,000〜5,000 文字（トークン効率とのバランス）
- **o-m-cc 本体**: 93 行 / 約 7KB（v0.38.1 でスリム化済み）

### 書くべき内容（永続的なルール）

- 設計思想・アンチパターン警告（変更提案時の照合基準）
- ワークフロー判断（どの skill をいつ使うか）
- コミット規約、テスト規約
- 「絶対にこうするな」のルール

### 書かないべき内容

- 詳細な API 仕様、ディレクトリ構造の全体（→ docs/ へ）
- バージョン履歴（→ Changelog へ）
- 一回きりの TODO（→ TaskCreate へ）
- コード実例（→ skills/ や references/ へ）

毎ターン再注入されることを意識して、**「どの決定にも関わる永続的な判断基準」だけ** を残すのがコツ。

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

### 0.57.0

- **`hooks/simplify-diff-gate.sh` 新設（強制 simplify gate）** — PreToolUse Bash matcher で `jj git push` / `git push` を検知時に diff 行数（main@origin..@- の insertion + deletion 合計）を計算。閾値（環境変数 `SIMPLIFY_DIFF_THRESHOLD` で上書き可、default 500）を超え かつ 最終コミット以降に `/simplify` 実行履歴がなければ **exit 2 で block**。`/simplify` で整理してから再 push する運用を強制。`skill-usage.csv` の simplify エントリ（最終 timestamp）を参照して通過判定
- **`skills/sisyphus/SKILL.md` description を action 化** — auto mode classifier が「planning」と誤分類して抑制しないよう、冒頭を「新機能を実装まで一気通貫で走らせる action skill」に書き換え。「`auto mode でも planning ではなく action として積極発動`」を明示。`実装して` / `作って` / `追加して` 等の action verb キーワードを先頭に追加（旧来の「計画して」も互換のため後方に維持）

### 0.56.0

- **skill-usage.csv に `effort` 列追加（v2.1.133 対応）** — `$CLAUDE_EFFORT` env var を `hooks/skill-usage-log.sh` / `skill-prompt-log.sh` で 5 列目に記録（env var 優先 / hook input `.effort.level` にフォールバック）。旧 2/3/4 列スキーマからの自動 migration（既存行は空欄）。`bin/atom-suggest` に **Effort breakdown** セクション追加（xhigh / high / medium / low 別の skill 起動分布、`sisyphus は xhigh で重く、quality-gate は medium で軽く` のような使い分けパターンを可視化）
- **README に「推奨 settings.json」セクション追加** — `worktree.baseRef: "head"`（v2.1.133 で default が fresh に revert され、`isolation: worktree` エージェントで unpushed commits dropped 問題を防ぐため）と `autoMode.hard_deny`（v2.1.136 の auto mode 専用無条件 block ルール、Sisyphus 自動ループの安全装置二重化）の推奨設定例を提示

### 0.55.0

- **skill-usage.csv に `session_id` 列追加（v2.1.132 対応）** — `CLAUDE_CODE_SESSION_ID` env var を `hooks/skill-usage-log.sh` / `skill-prompt-log.sh` で 4 列目に記録（env var 優先 / hook input JSON にフォールバック）。旧 2 列 / 3 列スキーマからの自動 migration（既存行は空欄）。`bin/atom-suggest` に **Session stats** セクション追加（top 5 セッションごとの skill 起動数）
- **unused-skills × `skillOverrides` 連携（v2.1.129 対応）** — `bin/atom-suggest` の Unused skills 出力に推奨アクションを併記（`off` / `user-invocable-only` / `keep`）。さらに末尾に `~/.claude/settings.json` 追記用の `skillOverrides` JSON 例を生成（`keep` 以外のみ列挙）。proactive=0 で slash≥1 → `user-invocable-only`、total=0 → `off` の判定で actionable に
- **README Token & Cost に Council コスト改善メモ追加（v2.1.128 観測）** — sub-agent progress summary の prompt cache 修正で discovery-council / quality-gate / editorial-swarm の `cache_creation` トークンが約 3 倍削減された旨を Note 段落として明記

### 0.54.1

- **`bin/atoms complete` のステータス更新バグ修正** — `atom_id` を直接渡したとき atoms.csv の `status` が `atom` のまま残り、atom-suggest の promote-ready に出続けていた。`A` プレフィックスで判別して atoms.csv を `output` に直接更新するよう修正（pipeline 経由は従来通り）
- **`bin/atom-suggest find_gotcha_ranking` の誤検出修正** — `<!-- AUTO-GOTCHAS -->` を SKILL.md のドキュメント例（コードブロック内）で言及している skill（evolve など）が「累計 N 件」と誤判定されていた。`rfind` で最後のマーカー以降を真のセクションとして扱い、かつ `[YYYY-MM-DD]` プレフィックスを持つ bullet のみカウントするよう修正

### 0.54.0

- **skill-usage.csv に `trigger` 列追加 + user-slash 起動の取りこぼし修正**
  - 既存 `hooks/skill-usage-log.sh` (PreToolUse Skill matcher) は Claude proactive 発動でしか発火せず、`/skill` 直接入力（user-slash）が**構造的に記録漏れ**していた既存バグを修正
  - `hooks/skill-prompt-log.sh` 新設: UserPromptExpansion で user-slash 起動を補完。built-in slash command (`/clear` 等) と非 slash expansion はスキップ
  - CSV スキーマ: `timestamp,skill` → `timestamp,skill,trigger`（trigger ∈ `claude-proactive` / `user-slash`）。既存ファイルは hook 内で 1 行目だけ自動 migration、データ行は trigger 空欄で残る（後方互換）
  - `bin/atom-suggest find_unused_skills` を `(total, proactive, slash)` の 3 Counter 化。「proactive=0 で slash≥1 → description 改善候補」「total=0 → 削除候補」を 1 行で判別可能に
  - 着想: Claude Code v2.1.126 で `claude_code.skill_activated` OTel イベントに `invocation_trigger` 属性が追加されたリリースノートを読んでいて発見
- **README データレイヤー表に `claude project purge` 警告セクション追加**
  - `.claude/atoms.csv` / `.claude/pipeline.csv` / `.claude/outputs.csv` / `.claude/journal.md` が purge で消失するリスクと、`jj op log` / `git reflog` による復旧手段を明記

### 0.53.1

- **editorial-swarm を Council JSON schema 準拠に統一**
  - 4 reviewer (anti-ai-slop / fact-checker / narrative-critic / reader-advocate) が `facets/policies/council-output-schema.md` 準拠の JSON オブジェクトを返すよう書き換え
  - `confidence` (0-100) を追加し、Step 4 の自動 apply を「low かつ confidence ≥ 70」に厳格化（ノイズ流入抑制）
  - Step 5 の AskUserQuestion で `severity / confidence / category` を表示して優先度判断を補助
  - schema 違反 reviewer は再実行 1 回 → スキップ（1 reviewer 失敗で全体停止しない）

### 0.53.0

- **kawai 氏型 analytics ループ導入: atoms/pipeline/outputs CSV 3 層**
  - `.claude/atoms.csv`（アイデア backlog）/ `.claude/pipeline.csv`（要件化）/ `.claude/outputs.csv`（完了履歴 + outcome + metric）の 3 層を新設
  - kawai 氏のマーケ部門事例（@kawai_design）を OSS dev 文脈に翻案。データの永続化と「次にやるべき」の判断支援を仕組み化
- **`/o-m-cc:atom-suggest` 新規 skill 追加（`/o-m-cc:retro` を吸収して合計 15 スキル）**
  - Backlog issues: stale-atoms（30 日以上放置）/ promote-ready（next が具体的）/ stuck-pipeline（14 日進捗なし）/ orphan-next（context.md にあるが atoms に未登録）
  - Skill health: top-skills / duration-stats（count / avg_ms / max_ms / sum_ms）/ unused-skills（累計 ≤ 1 回）
  - Activity pulse: 直近 7 日の atoms 追加と top skills
  - 旧 `/o-m-cc:retro` の機能は本 skill に統合（atoms 体系があれば retro と分ける必要がなく、1 レポートで backlog + skill ヘルスを俯瞰できる）
- **`bin/` ヘルパー 3 種追加**
  - `bin/atoms`: atoms.csv / pipeline.csv / outputs.csv の add / promote / complete / archive / list / show / stats（Python + csv module で正しい quoting）
  - `bin/atom-suggest`: 上記 4 カテゴリの分析エンジン
  - `bin/check-consistency`: agents/skills 数 + version 表記の一貫性検証（CLAUDE.md / README / plugin.json / marketplace.json 横断）
- **既存ログを CSV に統一**
  - `skill-usage.log` → `skill-usage.csv`（header: timestamp,skill）
  - `skill-duration.log` → `skill-duration.csv`（header: timestamp,skill,duration_ms）
  - 旧 .log は .log.bak で保持。reader（retro / evolve / session-resume / quality-gate-cta）も CSV 対応
- **ドキュメント数値乖離 6 件を fix（`bin/check-consistency` の初回実行で検出）**
  - CLAUDE.md / README.md / plugin.json / marketplace.json の agents/skills 数を実数（15 specialized + 16 skills）に揃える

### 0.52.0

- **skill 実行時間の記録機能を新設** — Claude Code 2.1.119 の PostToolUse hook `duration_ms` 追加を活用
  - `hooks/skill-duration-log.sh` 新規: PostToolUse:Skill で `skill-duration.log` に `timestamp TAB skill_name TAB duration_ms` を記録
  - `/retro` スキルに実行時間分析セクション追加: 平均 / 最大 / 合計実行時間を skill 別に集計
  - 「遅いスキル → context: fork 導入 / Progressive Disclosure 強化 / reference 分離」の改善判断材料を提供
  - Claude Code 2.1.118 以下では duration_ms が無いので 0 が記録される（実害なし）

### 0.51.0

- **design.md template に「File Structure Plan」セクション追加** — 新規作成 / 変更 / **触らない（Boundary）** の 3 カテゴリでファイル一覧を明示
- **task description に `Boundary` フィールド追加** — タスクが触らない領域を明示してスコープクリープを防ぐ
- **Similar Projects に cc-sdd を追加** — クロスプラットフォーム SDD（Claude Code / Codex / Cursor / Copilot / Windsurf / OpenCode / Gemini CLI / Antigravity 8 対応）、Kiro 互換
- **出典**: [gotalab/cc-sdd](https://github.com/gotalab/cc-sdd)（3.1k⭐）の `_Boundary:_` / `_Depends:_` アノテーション概念を o-m-cc に翻訳

### 0.50.0

- **`/o-m-cc:install` Step 7.5 新設** — R12 スタイル保護 deny ルールを opt-in で追加
  - force push / hook bypass (--no-verify) / reset --hard origin / rm -rf 系を `.claude/settings.json` の `permissions.deny` に追加
  - デフォルトは「追加しない」（個人開発・利便性優先）
  - チーム開発・共有リポジトリ向けに AskUserQuestion で明示選択
  - 出典: Claude Harness "Hokage" R12 deny ルールから必要最小限を抽出（ブランチ保護 / 履歴改変 / FS 破壊）
  - 動機: Claude Code 2.1.98+ で Bash bypass は大半修正済みだが、defense-in-depth の二層目として
- **Similar Projects に Claude Harness "Hokage" を追加** — 重装甲ガードレール + Go バイナリ + `harness.toml` SSOT という別戦略のプラグイン。o-m-cc（Lightweight + マルチエージェント Council）との棲み分けを明記
- **Architecture に「データレイヤー」表を追加** — スキル間で共有される plan/ / journal.md / TaskCreate / auto-memory / Gotchas / .editorial/ 等 10 種を一覧化
- **Architecture に Guides × Sensors の 2 軸フレーミングを導入** — Harness Engineering の前方制御/後方検知を明示
- **`editorial-swarm` anti-ai-slop に曖昧語ブラックリストを具体化** — 「正しく」「適切に」「することができます」等の具体フレーズを列挙（tokium_dev QA ハーネス記事の style-guide パターンを参考）
- **Progressive Disclosure 原則を強化** — 「ツールを増やさず機能を拡張」という Anthropic 公式ツール設計哲学を明記
- **`/o-m-cc:retro` に「モデル進化時のガード再評価」項目を追加** — sisyphus Step 0 系などの特定事故対応防御がモデル世代交代で過剰化していないか定期チェック

### 0.49.0

- **`/o-m-cc:editorial-swarm` 新設** — 技術記事の並列推敲 Council（4 エージェント並列 + severity 付き findings 集約 + 一括承認 + 最大 3 ラウンド）
  - anti-ai-slop（AI 定型句 / 過剰箇条書き / 曖昧な「など」検出）
  - fact-checker（API 名 / version / コマンド構文を WebFetch で公式照合）
  - narrative-critic（導入→結論の糸 / buried leads / weak transitions）
  - reader-advocate（対象読者視点の jargon / 前提知識ギャップ）
  - discovery-council の「文章版」という位置付け（同じ Agent Teams + fork context 構造）
  - 動機: 記事執筆で繰り返すレビューサイクル（anti-ai-slop → fact-check → narrative → 読者視点）を並列化。Zenn 等のドラフト完成後の最終推敲で使用
  - 既存 global の `writing-skills` / `doc-coauthoring` とは棲み分け: o-m-cc 側は「並列オーケストレーション」、global 側は「個別の文章ガイドライン」

### 0.48.0

- **quality-gate に「実装範囲の整合性検証」を追加（P2）**
  - Step 1.1 新設: `plan/requirements.md` が存在する場合、記述された対象ファイル/範囲と `jj diff --stat` の実変更を照合
  - **対象ファイルが 1 つも変更されていない**（完全乖離）→ 致命エラー + `PushNotification`、AskUserQuestion で判断委ね
  - 一部未変更（部分実装）→ 警告のみ（[NOTE] 記録）で先に進む
  - requirements.md がない / 対象範囲抽出不能 → スキップ
  - 動機: 過去に sisyphus が「5 画面 Refined Editorial は前コミットで適用済み」と**嘘の完了報告**をした事故を Phase 5 で検出できるようにする
- **sisyphus に「軽量タスク誘導チェック」を追加（P3）**
  - Step 0A-lite 新設: $ARGUMENTS に「UI polish」「a11y」「CSS 統一」「redesign」等の軽量キーワードがあり、かつ変更規模が 2 ファイル以下 / 50 行未満程度なら、`AskUserQuestion` で `/ui-polish` / 普通の Edit / sisyphus 続行 の 3 択を提示
  - 動機: UI polish のような軽量タスクに重量級 Council を呼ぶと、オーバーヘッド大 & 実装との乖離リスク増大（今日の事故の一因）
  - Council オーバーヘッドを避けつつ、sisyphus を使いたい場合は C 選択でこれまで通り進める
- 双方ともガードは保守的（False positive を最小化）: quality-gate は「完全乖離」のみ致命エラー、sisyphus は「ユーザーが C 選べば続行」

### 0.47.0

- **`/o-m-cc:handoff` を EC2 / 跨マシン引き継ぎの中核として再定義**
  - Description を EC2 引き継ぎ第一用途にリフレーム。同一マシンのセッション区切りは副次用途扱い
  - SKILL.md 本文に「**なぜ handoff が必要か**」を明記: built-in `/recap` はローカル端末固有で別マシンから参照できない。そのギャップを埋めるのが handoff の役割
  - README / CLAUDE.md の説明文・導線を EC2 中心に書き換え
- **`.claude/chronicle.md` / `.claude/context.md` / `.claude/context-archive.md` を `.gitignore` に再追加**
  - これらは v0.42.0 で廃止済みだが、古い hook を持つ他マシン環境で resume 時に書き戻される事例があり、VCS で競合を起こしていた
  - VCS 共有は `.claude/journal.md`（`/handoff` で更新）のみに一本化
  - 残骸として残っていたファイルも削除
- 動機: 個人で EC2 A ↔ B を行き来して作業再開するユースケースを正式サポートするため、handoff を中核として位置づけ、chronicle / context の VCS 競合ノイズを遮断する

### 0.46.0

- **スキル側の Headless モード判定を削除**（別ハーネス対応のための汎用化）
  - `CLAUDE_NON_INTERACTIVE=1` / `-p` 検出に依存していた AskUserQuestion 抑制ロジックを全スキルから削除。モデル（Opus 4.7 はデフォルトで質問抑制・推測優先）の自律判断に委ねる
  - `## Headless モード` セクションを sisyphus / discovery-council / feature-flow / deep-interview から削除
  - 「Headless モードでなければ AskUserQuestion」→「**critical なら AskUserQuestion**、それ以外は仮定/記録で進む」に閾値を引き上げ
  - `feature-flow` / `deep-interview` は対話前提スキルとして明示（AskUserQuestion が使えない環境ではエラー終了）
  - PushNotification 条件から `EC2 バックグラウンド` 等の固有表現を一般化（「バックグラウンド実行が想定される」）
  - hooks（`session-resume.sh` / `permission-denied.sh` / `quality-gate-cta.sh` / `lib/common.sh`）は Claude Code 固有のため変更なし
  - 対象: 9 スキルファイル（+19 / -39 行の純減）
  - 動機: o-m-cc スキルを Claude Code 以外のハーネスでも動かすため、env var 依存を除去
  - 副作用: Claude Code の `claude -p` 実行時に AskUserQuestion が呼ばれハングするリスクが理論上復活するが、閾値を critical に引き上げたため発動率は低い

### 0.45.0

- **sisyphus の安全性強化**
  - **P0: 既存 plan/ を `rm` ではなく `mv` で退避**（Step 0B）
    - `plan/archive/YYYYMMDD-HHMMSS-<topic-slug>/` に既存 `plan/requirements.md` / `plan/design.md` を退避
    - `# Requirements: <topic>` から topic 抽出、slug 化（日本語保持）して archive ディレクトリ名に
    - 完了済み機能の plan documentation を喪失するリスクを根本解消（事故事例: COMPANION 案件統合の完成 plan を別セッションで上書きしかけた）
  - **P1: 曖昧引数の再検出**（Step 0A 冒頭）
    - `- A. 前の提案で` / `A` / `#` のような**文脈前提の断片**は空文字同等として扱い、推測フローに fallthrough
    - 判定は Claude の自然文判断（Bash 正規表現は空文字チェックのみ）。False negative でも 0A の推測 AskUserQuestion が出るだけで破壊的変更にならない
- **新スキル `/ui-polish` を追加**
  - 既存画面の UI polish / 複数画面の redesign 統一 / a11y 対応 / CSS 一貫性修正用の軽量実装ループ
  - Council を使わず `bin/lint` → `npm run lint` → `npx tsc --noEmit` の順でゲート。1 対象ずつ Read → Edit → 静的チェック
  - `effort: low`、`context: fork` なし、PushNotification なし
  - 外部プラグイン `frontend-design` との棲み分け: ui-polish は**既存 UI の統一・修正**、frontend-design は**新規デザイン生成**。description と本文の使い分け表で明示
  - 動機: sisyphus の Council が UI polish 5 画面のような定型作業に対してオーバーヘッド大で不向きだった（今回の事故原因の一つ）
- **ドキュメント数値不整合の是正**
  - CLAUDE.md の「10 の専門エージェント + 12 スキル」が feature-flow 追加以降ずれていたのを実数（15 エージェント + 14 スキル）に更新
  - README.md / README_en.md の Skills 総数・Agents 総数・skills/ ディレクトリコメントを合わせる

### 0.44.0

- **`sisyphus` を引数なしで呼んだときの挙動を改善**
  - Step 0 を 0A（引数確認 + 文脈推測）/ 0B（plan 掃除 + タスク登録）に分割
  - `$ARGUMENTS` が空の場合、変更統計・最近のコミット・既存 `plan/` ・TaskList から **候補を 2〜5 件推測**して AskUserQuestion で確認してから進む（盲目的に `discovery-council` を呼ばない）
  - 候補例: 「未コミット変更を feature 化」「既存 plan の続きを実装」「新規タスクを入力」「sisyphus 不要」
  - 「既存 plan の続き」を選んだ場合は `plan/requirements.md` / `plan/design.md` を **保持**（削除しない）
  - Headless モードで判断不能なら**エラーで停止**（推測で無理やり走らせない）
  - 動機: 引数なしで sisyphus が呼ばれると、無関係な requirements.md が生まれて既存 plan を破壊するリスクがあった

### 0.43.0

- **PushNotification を sisyphus / experiment / quality-gate に組み込み**
  - Claude Code v2.1.110+ の built-in `PushNotification` tool を利用。Remote Control 有効時はモバイルへの push、未設定時はデスクトップ通知
  - `sisyphus` Step 7（完了）: 長時間実行（目安 10 分以上）or `CLAUDE_NON_INTERACTIVE=1` / EC2 バックグラウンド実行時に結果サマリを通知
  - `experiment` Step 3（収束）: 同条件で通知
  - `quality-gate` Step 8 新設: Critical 停止（ユーザー判断待ち）、Review Council が 10 分以上、lint Error 残存時に通知
  - ポリシー: **err toward not sending**。短時間＆ユーザー在席時は送らない。メッセージは行動可能な情報でリード（200 文字以内）
  - ユースケース: EC2 で sisyphus を走らせて完了をスマホで受ける

### 0.42.0

- **セッション引き継ぎを /recap 中心に再設計（破壊的変更）**
  - 削除ファイル: `.claude/context.md` / `.claude/chronicle.md` / `.claude/context-archive.md`
  - 削除 hook: `pre-compact-handover.sh` / `post-compact-resume.sh` / `session-title.sh` / `resolve-conflicts.sh` / `post-vcs-resolve.sh`
  - 削除 CLI: `bin/resolve-conflicts`
  - 削除 hook イベント: `PreCompact` / `PostCompact` / `SessionEnd` / `UserPromptSubmit`（それぞれ単一 hook のみだったため）
  - 新設: `.claude/journal.md`（Recap + Next Actions の時系列アーカイブ、append-only、ホスト識別子付き）
  - `/o-m-cc:handoff` は `.claude/journal.md` の先頭に **Recap（現セッションの LLM 要約 2〜4 文）+ Next Actions（1〜5 件）** を追記する役割に変更。Intent/Outcomes/Blockers/Working Dir/MEMORY.md 反映/Skill 提案等の旧フローは全廃
  - `session-resume.sh` は journal.md の最新 1 エントリ全体（Recap + Next）と skill-usage ログを表示
  - **EC2 など別マシンへの引き継ぎに対応**: journal.md は VCS 同期で別マシンから読めるため、`/recap`（ローカル端末固有）では不可能な跨マシン引き継ぎが可能。日付見出しに `[hostname]` を付与して発生元を識別
  - 動機: Claude Code v2.1.108+ の built-in `/recap` が Intent/Outcomes の LLM 要約を高品質で提供するため、独自実装を廃止。`pre-compact-handover.sh` の Intent 抽出バグ（transcript 空時に既存 context.md から読み戻す循環で chronicle.md に壊れた Intent を蓄積）を根本解消
  - トークンコスト純減: SessionStart 固定出力が context.md + chronicle.md → journal.md 最新 1 エントリのみに
  - 後方互換なし: 既存 context.md / chronicle.md は VCS 履歴で参照可能（o-m-cc 側は触らない）
  - プライバシー注記: `hostname -s` が EC2 内部 IP を返す場合、public repo では `.gitignore` に `.claude/journal.md` を追加するか private repo 運用を推奨

### 0.41.0

- **`feature-flow` スキル追加** — 新規 web アプリ機能を構造化する 5 フェーズワークフロー
  - 2 モード（最初から / 途中から）対応。Phase B で並列 3 エージェントによる Prior Art 調査、Phase E で Reader Test を行うことで spec の質を担保
  - `deep-interview`（5軸）/ `discovery-council`（複数機能統合）と棲み分け、単一機能の構造化 spec という空白フェーズを担当
  - 公式 feature-dev / brainstorming / doc-coauthoring の設計パターンを参考
- **Prior Art Agents 6 体追加** — `architecture-mapper` / `code-explorer` / `convention-scout` / `market-researcher` / `oss-scout` / `pattern-observer`（エージェント総数 9 → 15）

### 0.40.1

- **README に CLAUDE.md ベストプラクティスセクション追加** — 流出コード分析の知見を反映
  - 階層構造（global / project / rules / CLAUDE.local）、サイズ目安（推奨 2k-5k 文字、上限 40k）、書くべき/書かないべき内容
- **Hook の型セクション追加** — 公式仕様の 4 種類（`command` / `prompt` / `agent` / `http`）を明記
  - 流出分析で言及された「5種類」は不正確（`function` 型は存在しない）
  - o-m-cc は全 hook で `command` 型が最適である理由を説明

### 0.40.0

- **`audit` スキル削除** (13 → 12 skills)
  - retro での使用頻度分析で 30日間 0 回使用、他スキルからの chain 参照もなしと判明
  - 実態は Claude 向けのプロンプトテンプレート（コード自体は静的チェックリスト）
  - 同等の監査作業は Claude に直接依頼すれば OK。独立スキルとして保持する価値が低い
  - discoverability 改善: 残り 12 スキルの役割がより明確に

### 0.39.0

- **`/evolve` に Quality Gate 追加** — oh-my-claudecode の `/learner` にインスパイア
  - Step 2.5 新設: 追記前に 3 質問で検証（Googleable？ / codebase 固有？ / 試行錯誤で発見？）
  - 価値ある Gotchas の4条件（Non-Googleable / Context-Specific / Actionable with Precision / Hard-Won）
  - Anti-Patterns 明記（Generic patterns / Refactoring techniques / Library 使用例 等は追記しない）
  - Core Principle: 「コードスニペット」ではなく「考え方のヒューリスティック」を残す
- **README に Similar Projects セクション追加**: oh-my-claudecode との立ち位置の違いを明記（Lightweight vs TypeScript、Claude Code ネイティブ vs 多モデル）

### 0.38.1

- **CLAUDE.md をスリム化** (143行 → 93行、9.4KB → 7KB、**-26%**)
  - 流出コードの分析で CLAUDE.md が毎ターン再注入されることが判明。長いほどトークンコストが嵩む
  - 削除: ディレクトリ構造（README に完全版あり、重複）、Hooks テーブル（同）、テスト・検証コマンド、デプロイ手順
  - 維持: 設計思想と強み、ワークフロー判断、コミットメッセージ Trailers — 毎ターン必要な「永続的ルール」
- **`docs/RELEASING.md` 新設**: テスト・デプロイ手順、バージョン規約を CLAUDE.md から分離
- 「10エージェント」「13スキル」に表記統一（従来 "9" のまま残っていた箇所を修正）

### 0.38.0

- **`.claude/` メタファイル auto-resolve の jj 3-way conflict 対応**
  - `resolve-conflicts.sh`: jj 形式 (`%%%%%%%` / `+++++++`) のマーカーを認識・解決
    - chronicle.md: diff section の `+- [...]` 行も entry として拾って union
    - context.md: side #2（通常 remote）を verbatim 採用
  - 既存の git 形式もそのまま動く（後方互換）
- **PostToolUse(Bash) 自動トリガー追加** (`hooks/post-vcs-resolve.sh`)
  - `jj rebase` / `jj git fetch` / `git pull` / `git merge` / `git rebase` 直後に auto-resolve
  - これまで SessionStart でしか動かなかった auto-merge が session 中にも発動
- **`bin/resolve-conflicts` 追加**: 手動で auto-resolve を呼び出す口
- **安全策**: 対象は `.claude/chronicle.md` と `.claude/context.md` の **2ファイル固定**。他のファイル（Sdtabfile.toml など実データ）は絶対に触らない

### 0.37.0

- **dotfiles 自動同期 hook 追加** (`hooks/dotfiles-pull.sh`)
  - 複数マシン（Mac/EC2 等）で dotfiles を共有している場合の軽量な自動同期
  - SessionStart で `~/dotfiles` を 24h throttle 付きで `git pull`
  - バックグラウンド実行で SessionStart をブロックしない（~200ms）
  - `~/dotfiles` がなければ no-op（他プロジェクト影響なし）
  - `O_M_CC_DOTFILES` env var で path override 可
  - 代替案（sdtab/launchd）との比較: Claude Code を毎日開く運用ならこれで十分、セットアップは plugin install だけで完結

### 0.36.0

- **Sisyphus 自動発動 CTA**: plan mode → 実装の流れで sisyphus を起動しやすく
  - `PostToolUse(ExitPlanMode)` hook: Claude Code built-in plan mode 終了時、plan file が5行以上あれば `/o-m-cc:sisyphus` を促す stderr CTA を表示
  - `PostCompact` hook: compaction 後、`plan/requirements.md` or `plan/design.md` があれば sisyphus 再開を促す CTA を追加
- non-blocking 設計: CTA はリマインダーに留まり、Claude の判断を尊重

### 0.35.1

- **PreCompact safety block**: Claude Code 2.1.105 で PreCompact hook が compaction を block できるようになったのを活用。`pre-compact-handover.sh` で context.md 保存失敗時に exit 2 で block し、文脈喪失を防ぐ
- **verification を sisyphus Step 5 に組み込み**: 実装後に `Skill: verification` を明示的に呼び、自己エビデンス収集を強制。retro で「30日間 0 回呼び出し」を観測したのが動機
- **retro の awk バグ修正**: `$1 >= d` が Claude Code の `!`command`` 評価で `$1` が shell 引数として解釈される問題を、`substr($0, 1, 10)` への置換で回避

### 0.35.0

- **Monitor ツール統合**: Claude Code 2.1.98 の新ツール Monitor を experiment/quality-gate/sisyphus に組み込み
  - `experiment`: 10秒超のテストを Monitor で非同期測定（待ち時間に次の仮説検討）
  - `quality-gate`: lint (ruff/shellcheck/tsc/clippy) を Monitor で並列ストリーミング（tag prefix で出力識別）
  - `sisyphus`: Verifier のテスト実行をストリーミング
- opt-in 設計（短時間テストは従来方式）、fallback 保持

### 0.34.0

- **chronicle.md / context.md コンフリクト自動解決 hook**: 跨マシン同期（Mac ⇄ EC2 等）でコンフリクトが頻発していた問題を SessionStart hook（`resolve-conflicts.sh`）で自動解決
- **UserPromptSubmit hook で sessionTitle 自動設定**: Claude Code 2.1.94 の sessionTitle 機能を活用し、新セッション開始時に context.md の Intent を pane title として設定

### 0.33.0

- **handover 機構の改善 + `/handoff` スキル追加**: Intent 抽出ロジックを修正、明示スキル化（旧 `/handover` から改名）
- Sisyphus Step 7 の /evolve 自動呼び出しを整理

### 0.32.0

- **PreToolUse(Bash) hook で quality-gate CTA 追加**: push 系コマンド（`jj git push` / `git push` / `gh pr create` 等）実行前に「/quality-gate 実行済みですか？」を stderr で問いかける non-blocking CTA

### 0.31.1 / 0.31.0

- **headless 検出を `CLAUDE_NON_INTERACTIVE` に統一**: 全スキル横断で判定ロジックを統一

### 0.30.0

- **`bin/` executables 導入**: `validate-plan`、`lint` を bare command として Bash tool から直接実行可能に。スクリプト経由の間接化を廃止

### 0.29.0

- **`/evolve` スキル追加**: auto-memory から学びを抽出し、各スキルの Gotchas に自動追記（L3 inspired）
- **旧 handover スキル削除** → PreCompact hook で /evolve を自動 CTA
- **Sisyphus Step 7 に /evolve 組み込み**: 実行完了後に自動で学びを反映

### 0.28.1

- **`/experiment` を autoresearch 方式に改修**: イテレーション間の記憶は `progress.md`、各イテレーションを独立サブエージェントで実行（コンテキスト劣化防止）
- **stop-guard 撤去**: diff 強制の quality-gate を廃止（後続で PreToolUse(Bash) の quality-gate-cta hook に置き換え）
- **CoDD inspired staleness check**: `validate-plan.sh` に上流ドキュメント変更時の下流検証を追加
- **Anti-Slop Bias + reviewer コンテキスト遮断原則**: reviewer が実装者のバイアスに影響されないよう設計
- **スキルの Progressive Disclosure**: `reference.md` 分離でトークン消費を削減
- **PermissionDenied hook 追加**（2.1.88 対応）
- **独自 simplify → ネイティブ `/simplify` に委譲**
- **deep-interview スキル追加**、SubagentStop hook 追加、commit trailers 追加

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

## Similar Projects / 関連プロジェクト

Claude Code のマルチエージェント協調領域には他にも選択肢があります。位置付けの違いを明記:

### [oh-my-claudecode (OMC)](https://github.com/Yeachan-Heo/oh-my-claudecode)
- **28k⭐ / TypeScript / npm+plugin**
- 機能豊富：Team / ccg / Autopilot / Ultrawork / Ralph / Pipeline など **9種類のオーケストレーションモード**
- マルチモデル対応：tmux 経由で Claude + Codex + Gemini を並列起動
- HUD statusline、通知統合（Telegram/Discord/Slack）、Rate limit auto-resume
- **向いている人**: 多機能・多モデルが欲しい、TypeScript runtime 許容、Discord コミュニティ

### [cc-sdd](https://github.com/gotalab/cc-sdd)
- **3.1k⭐ / TypeScript / npm パッケージ（`npx cc-sdd@latest`）**
- **8 プラットフォーム対応**: Claude Code / Codex / Cursor / Copilot / Windsurf / OpenCode / Gemini CLI / Antigravity
- Kiro IDE の仕様駆動方法論と互換（`kiro` 命名規約）
- 17 の Agent Skills（`/kiro-discovery`, `/kiro-spec-init/requirements/design/tasks`, `/kiro-impl` 等）
- タスク境界 `_Boundary:_` / `_Depends:_` アノテーションで依存とスコープを明示
- TDD を `/kiro-impl` で RED→GREEN 明示
- **向いている人**: 複数エージェント（Claude + Codex + Cursor 等）を跨いで同じ spec を使いたい、Kiro IDE ユーザー、TypeScript 許容、npm 配布でよい

> **o-m-cc で取り込んだ要素**: cc-sdd の `_Boundary:_` 概念を参考に、design.md template に「File Structure Plan（新規作成 / 変更 / 触らない）」セクションと、task description に `Boundary` フィールドを追加（v0.51.0）。スコープクリープ防止が狙い。

### [Claude Harness "Hokage"](https://github.com/Chachamaru127/claude-code-harness)
- **Go ネイティブバイナリ / Node.js 依存ゼロ / `harness.toml` SSOT**
- ガードレール最重視の重装甲型：R12 deny ルール（git push --force / rm -rf / 保護ブランチ直 push / --no-verify bypass）
- Bash permission bypass 二層目防御（Claude Code 2.1.98 脆弱性対応）
- Plan → Work → Review 自律運用を専用エージェントで実装
- フック実行 ~10ms（Go バイナリ化で 30 倍高速化）
- **向いている人**: AI の危険操作ブロックを重装甲で固めたい、`harness.toml` 1 本で設定を一元管理したい、Go バイナリ許容

### o-m-cc（このプロジェクト）
- **Markdown + Shell のみ / Claude Code ネイティブ**
- Lightweight 原則：ビルド不要、ランタイム依存最小
- Claude Code ネイティブ活用：TaskCreate / Agent Teams / auto-memory をそのまま
- マルチエージェント Council 型：discovery-council / Review Council / editorial-swarm の並列協調
- 設計思想明文化：アンチパターン警告を含めて CLAUDE.md に明記
- **向いている人**: 軽量さを重視、Claude Code 専用で十分、マルチエージェント協調を中心に据えたい、設計原則を大切にしたい

> **参考にしている部分**:
> - OMC の `/learner` quality gates（3 questions + 4 criteria）を v0.39.0 で `/evolve` に取り込み
> - Claude Harness の Bash permission bypass 二層目防御は今後調査対象（Claude Code 脆弱性情報の追跡）

---

## Inspired By

- [oh-my-opencode](https://github.com/code-yeongyu/oh-my-opencode) — マルチエージェントの原型。中央オーケストレーター型を peer-to-peer に再設計
- [ralph-wiggum](https://ghuntley.com/ralph/) — Stop Hook によるループ継続パターン

## License

MIT
