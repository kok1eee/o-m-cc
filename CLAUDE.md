# o-m-cc - Project Configuration

> **このファイルは毎ターン再注入される** ため、設計思想と判断ルールのみに絞る。
> 詳細なディレクトリ構造・Hooks 一覧・スキル一覧は [README.md](README.md) を参照。

## プロジェクト概要
Claude Code 用マルチエージェントプラグイン。Agent Teams (TeamCreate/SendMessage) による peer-to-peer マルチエージェント協調。Sisyphus Loop（タスク完了まで止まらないワークフロー）と仕様駆動開発（SDD）フローを提供。15 の専門エージェント + 15 スキル + hooks による自動化。

## 技術スタック
- Shell scripts (Bash) - hooks, scripts
- Markdown - エージェント定義, スキル定義, ドキュメント
- JSON - プラグイン設定, hooks設定

## アーキテクチャ
- **Agent Teams**: TeamCreate + Agent spawn + SendMessage によるネイティブ並列エージェント協調
- **peer-to-peer 通信**: SendMessage で teammates 間のリアルタイムメッセージ交換
- **共有タスクリスト**: TaskCreate/TaskUpdate で teammates が自律的にタスク管理
- **ナレッジ蓄積**: Claude Code の auto-memory に委ねる（プラグイン独自のナレッジ管理は行わない）
- **Faceted Prompting**: `facets/policies/`（横断ポリシー）と `facets/references/`（段階的開示リファレンス）で共通基準を一元管理
- **Progressive Disclosure**: frontmatter → 本文 → 参照ファイルの3段階でトークン消費を最小化

### Guides × Sensors（Harness Engineering の 2 軸）

o-m-cc は Harness Engineering の 2 軸（事前制御 / 事後検知）で設計されている:

| 軸 | 役割 | o-m-cc での実装 |
|---|---|---|
| **Guides**（前方制御） | 行動を事前に方向づける | CLAUDE.md（設計思想・判断ルール）、skill 定義、agent description、TaskCreate |
| **Sensors**（後方制御） | 結果を事後に検知して軌道修正 | `quality-gate-cta.sh`（push 前 CTA）、`subagent-verify.sh`、`bin/validate-plan`（Layer 1 形式チェック）、`evolve`（Gotchas 自動反映） |

新機能追加時は「Guides で誘導するか、Sensors で検知するか」を意識する。Guides で誘導できないものは Sensors で検知する（例: sisyphus の Step 0A 曖昧引数検出は Guides、quality-gate の実装範囲整合性検証は Sensors）。

## エージェント実行ヒント
- `background: true` — I/O集約的な調査エージェント（researcher）にバックグラウンド実行ヒント
- `isolation: worktree` — ファイル変更を行うエージェント（designer, planner, debugger）に worktree 分離

## 品質保証の2層構造

「止まらない」と「品質保証」は矛盾しない。品質が維持されていれば止まる必要がなく、品質が崩れたら止まるべき。

| 層 | 仕組み | LLM 依存 |
|---|---|---|
| **Layer 1**: 形式チェック（`bin/validate-plan`） | requirements.md/design.md の必須セクション・FR 言及率を自動検証 | なし |
| **Layer 2**: CTA（sisyphus SKILL.md） | 元の要求との内容乖離を LLM が判断 | あり |

quality-gate はワークフローの自然なタイミング（コミット前、PR 前、実装完了時）で実行する。

## 設計思想と強み（変更提案時に必ず照合すること）

以下は o-m-cc の核となる設計思想。これらを損なう提案があった場合は、**必ず指摘して代替案を提示すること**。

| 原則 | 説明 | アンチパターン例 |
|------|------|-----------------|
| **Peer-to-peer 協調** | エージェント同士が対等に議論・共有する。中央オーケストレーターは置かない | 全エージェントを統括する「マスターエージェント」の導入 |
| **Claude Code ネイティブ活用** | ネイティブ機能（TaskCreate, auto-memory, hooks 等）を最大限活用し、独自の再実装を避ける | プラグイン独自のナレッジ管理、ネイティブ機能と重複するファイルベースの仕組み（例: tasks.md） |
| **Sisyphus（品質が維持される限り止まらない）** | 品質が維持されている限り人間の介入なしで走り続け、品質が崩れたら止まる。不完全な中間成果物で実装を走らせるのは無駄 | 品質チェックなしで突き進む設計、不完全な要件で実装を走らせること、過剰な承認ステップで不必要に止まる設計 |
| **Lightweight** | Markdown + Shell のみ。ビルド不要、ランタイム依存最小 | TypeScript/Python への書き換え、ビルドステップの導入 |
| **Progressive Disclosure** | frontmatter → 本文 → 参照ファイルの3段階でトークン消費を最小化 | 全情報を1ファイルに詰め込む、エージェント定義の肥大化 |
| **Plugin ネイティブ** | Claude Code のプラグインシステムに準拠。settings.json で自動設定 | プラグイン外でのグローバル設定変更を前提とする設計 |
| **エージェント自律性** | 各エージェントは専門家として自律的に判断・行動する | エージェントの行動を細かくスクリプト化して自由度を奪う |

## ワークフロー判断

| 状況 | アクション |
|------|-----------|
| ピンポイントな修正（typo, 1ファイル変更） | そのまま実行 |
| 複数ファイルにまたがる変更 | `/plan` で計画してから実行 |
| 要件が曖昧・何を作るか不明確 | `/deep-interview` で掘り下げてから `/sisyphus` |
| 新機能・設計判断が必要な変更 | `/sisyphus` で要件→設計→タスク分解→実装 |
| 最適化・リファクタリング・試行錯誤 | `/experiment` で実験駆動ループ（試す→測る→保持 or revert） |
| 完了を宣言する前 | `/verification` で証拠確認（テスト実行、動作確認） |
| 長くなって区切りたい・新セッションに引き継ぎたい・**別マシン(EC2)に渡したい** | `/handoff` で journal.md に Recap + Next Actions を追記。同一マシンは `/recap` 併用、別マシンは VCS 同期で journal.md の最新エントリから復元（ホスト識別子 `[hostname]` 付き） |
| permission prompts が頻繁に出る・allowlist を育てたい | `/less-permission-prompts`（built-in）で直近 transcripts から read-only bash/MCP の allowlist を提案させ `.claude/settings.json` に追加 |
| PR レビューが欲しい | `/ultrareview <PR#>`（built-in, クラウド並列多エージェント）。ローカル＋静的解析込みなら `/quality-gate`（o-m-cc）|
| UI polish・複数画面 redesign・a11y 対応・CSS 統一 | `/ui-polish` で軽量ループ（Council なし、tsc/lint のみゲート）。新規デザインをゼロから生成するなら外部プラグイン `frontend-design` |
| 技術記事の最終推敲・Zenn 記事レビュー・AI 定型句除去・fact-check・読者視点チェック | `/editorial-swarm` で 4 並列レビュー Council（anti-ai-slop / fact-checker / narrative-critic / reader-advocate）。severity 付き findings を一括承認して最大 3 ラウンドで収束 |

**実装完了時のフロー:**
1. `/simplify` — コードを整理（ネイティブスキル。重複コード削除、不要コメント除去等）
2. Review Council — セキュリティ関連の変更、新規ファイル3つ以上、100行以上の変更がある場合
3. lint（`bin/lint`）— 常に実行

**原則: 迷ったら `/plan` に入る。** 計画なしで進むと後戻りが大きい。

**エスカレーション:** 想定より複雑だと判明したら上位ワークフローに切り替え。小さく始めて必要に応じて上げる。
- そのまま実行 → 影響範囲が広がった → `/plan`
- `/plan` → 設計判断が多い・複数フェーズ必要 → `/sisyphus`

## コミットメッセージ Trailers

大規模変更・設計判断時のみ、trailers を付加:

| Trailer | 用途 |
|---------|------|
| `Constraint:` | 意図的に守った制約 |
| `Rejected:` | 検討して却下した代替案と理由 |
| `Scope-risk:` | 影響しうる範囲 |

- typo/1ファイル変更 → 不要
- 新機能/アーキテクチャ変更 → `Constraint:` + `Rejected:` 推奨
- 既存の振る舞いを変える変更 → `Scope-risk:` 推奨

## 開発ガイドライン
- hooks スクリプトは `set -euo pipefail` + 共通ライブラリ (`hooks/lib/common.sh`) を使用
- エージェント数・スキル数を変更したら `plugin.json`, `marketplace.json`, `README.md`, `capabilities.md` を同期
- バージョンは `plugin.json` を正とし、他ファイルも合わせる

> **テスト・デプロイ詳細**: [docs/RELEASING.md](docs/RELEASING.md) 参照
