# o-m-cc - Project Configuration

> **このファイルは毎ターン再注入される** ため、設計思想と判断ルールのみに絞る。
> 詳細なディレクトリ構造・Hooks 一覧・スキル一覧は [README.md](README.md) を参照。

## プロジェクト概要
Claude Code 用マルチエージェントプラグイン。Agent Teams (TeamCreate/SendMessage) による peer-to-peer マルチエージェント協調。Sisyphus Loop（タスク完了まで止まらないワークフロー）と仕様駆動開発（SDD）フローを提供。14 の専門エージェント + 15 スキル + hooks による自動化。

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

### データレイヤー（スキル間で共有される状態）

スキルはコンテキストではなくファイル/ネイティブ状態を介して連携する:

| 場所 | Writer | Reader | 用途 |
|---|---|---|---|
| `.claude/atoms.csv` | `bin/atoms add` / 手動 | atom-suggest | アイデアバックログ（kawai 氏 atoms 相当）|
| `.claude/pipeline.csv` | `bin/atoms promote` | atom-suggest, designer | 要件化フェーズ（atoms ↔ plan/*.md の橋渡し）|
| `.claude/outputs.csv` | `bin/atoms complete` | atom-suggest | 完了履歴（成果物 path + outcome + metric）|
| `plan/requirements.md` | discovery-council, deep-interview | designer, critic, quality-gate | 要件定義（FR-X 形式）|
| `plan/design.md` | designer | planner, critic, quality-gate | アーキテクチャ設計 |
| `plan/archive/<timestamp>-<slug>/` | sisyphus Step 0B | — | 旧 plan の履歴保全（rm しない）|
| `plan/progress.md` | experiment | experiment (次 iteration) | 試行履歴（keep/revert 判断）|
| TaskCreate / TaskUpdate | planner, sisyphus | 全 teammate | ネイティブタスクリスト（Claude Code 機能）|
| `.claude/journal.md` | handoff | session-resume.sh, 別マシン | EC2 跨ぎ引き継ぎ（Recap + Next Actions）|
| `.claude/memory/` | Claude Code auto-memory | 全スキル次回セッション | auto-memory（ユーザープロファイル・フィードバック・プロジェクト知見）|
| Gotchas セクション（各 SKILL.md） | evolve | 次回スキル起動時 | スキル固有の実行経験から抽出した学び |
| `.editorial/round-N/` | editorial-swarm | editorial-swarm (次 round) | 記事レビューの findings / diff 履歴 |
| `${CLAUDE_PLUGIN_DATA}/skill-usage.csv` | skill-usage-log.sh / skill-prompt-log.sh hooks | atom-suggest, evolve | スキル使用履歴（CSV: timestamp,skill,trigger,session_id,effort。trigger ∈ claude-proactive/user-slash。session_id は v2.1.132+、effort は v2.1.133+ で記録）|
| `${CLAUDE_PLUGIN_DATA}/skill-duration.csv` | skill-duration-log.sh hook | atom-suggest | スキル実行時間（CSV: timestamp,skill,duration_ms）|
| `${CLAUDE_PLUGIN_DATA}/agent-duration.csv` | agent-duration-log.sh hook | atom-suggest | subagent dispatch 実行時間（CSV: timestamp,agent_type,duration_ms。v2.1.144+ の SubagentStop hook input から取得）|

**原則**: コンテキスト（会話履歴）に依存しない。別スキル/別セッション/別マシンから再開できる状態を必ずファイルに書く。

**Mac/EC2 跨マシン同期** (オプショナル): 上 3 つの CSV (skill-usage / skill-duration / agent-duration) は `${CLAUDE_PLUGIN_DATA}` 配下に置かれるため per-machine になる。`bin/sync-plugin-data setup` で `~/dotfiles/claude/.claude/plugins/data/o-m-cc-kok1eee/` に実体を移して symlink 化すると dotfiles の git 同期に乗る（`.gitattributes` の `merge=union` で append-only 行を両側保持）。詳細は README「跨マシン同期」セクション参照。

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
| **Progressive Disclosure** | frontmatter → 本文 → 参照ファイルの 3 段階でトークン消費を最小化。**ツールを増やさず機能を拡張する**（Anthropic 公式のツール設計哲学に準拠: 判断負荷を増やさず能力を広げる） | 全情報を 1 ファイルに詰め込む、エージェント定義の肥大化、独自ツール追加で Claude Code のネイティブ ~20 ツール判断負荷を増やす |
| **Plugin ネイティブ** | Claude Code のプラグインシステムに準拠。settings.json で自動設定 | プラグイン外でのグローバル設定変更を前提とする設計 |
| **エージェント自律性** | 各エージェントは専門家として自律的に判断・行動する | エージェントの行動を細かくスクリプト化して自由度を奪う |

## Skill 発動ガイドライン（Opus 4.7 + auto mode 対応）

**重要: o-m-cc の skill は「action の加速装置」であって「planning の遅延装置」ではない。**

Opus 4.7 は指示を文字通り解釈する傾向があるため、auto mode の「prefer action over planning」を過剰解釈して o-m-cc skill の発動を抑制しがち。これは誤り:

- `/sisyphus` = 新機能を **実装まで一気通貫で走らせる** action skill（内部に planning phase はあるが成果物は動作するコード）。**明示起動推奨**（auto mode での自動発動は実質機能しない）
- built-in `/goal` = 完了条件を設定してターン跨ぎで継続する native action。**auto mode でも発動する**。Agent Teams・quality-gate 不要な多ターン継続タスクはまずこれ
- `/quality-gate` = コミット前に品質検証する action skill（CI 代わり）
- `/discovery-council` = 要件を即座に確定する action skill（analyst/researcher/scout を並列実行）
- `/ui-polish` = UI を複数画面連続で修正する action skill
- `/editorial-swarm` = 記事を並列レビュー＋修正する action skill
- `/deep-interview` = 曖昧要件を即座に解像度上げる action skill
- `/experiment` = 試行錯誤を自動ループで回す action skill
- `/handoff` = journal.md に action の引き継ぎ記録を書く action skill

**auto mode でもこれらは抑制せず、該当状況にマッチしたら積極発動すること**。

唯一の例外: 「planning」的なもの（built-in `/plan` や自前の計画立案）は auto mode で抑制される。これは正しい挙動。

### 発動判定の優先順

1. ユーザーが明示指定（`/o-m-cc:sisyphus` 等） → 必ず発動
2. skill description のトリガーフレーズが含まれる → 発動
3. **状況がテーブルの行にマッチする → 発動**（Opus 4.7 で効きにくくなっているので特に意識）
4. auto mode でも 3 は有効。「action である」と明示されている skill は抑制しない

## Subagent / Agent Teams の発動（auto mode でも必須）

**subagent spawn と Agent Teams は「並列 action」であり、planning ではない。auto mode でも必ず使うこと。**

Opus 4.7 + auto mode で subagent / Agent Teams の発動が抑制されがちだが、これは誤り。subagent は:
- **メイン context の汚染を避けるための並列実行**（Read 大量 / Grep / WebSearch 等）
- **独立視点でのレビュー**（security-reviewer / critic、コード品質一般は built-in `Skill: simplify`）
- **バイアスなしの検証**（Verifier パターン）
- **情報の事前整備**（architecture-mapper / code-explorer / convention-scout）

いずれも**手動でやるより速い action**。planning ではない。

### Subagent を積極発動すべき場面

| 状況 | 発動する subagent |
|---|---|
| コード全体を把握したい（3 ファイル以上の Read が見込まれる） | `Explore` or `general-purpose` |
| 類似機能を辿りたい | `code-explorer` |
| アーキテクチャ / 抽象境界を把握したい | `architecture-mapper` |
| 命名規則 / テストパターン調査 | `convention-scout` |
| コード品質レビュー | built-in `Skill: simplify`（旧 `code-reviewer` agent は v0.58.0 で削除） |
| セキュリティレビュー | `security-reviewer` |
| 計画の妥当性検証 | `critic` |
| 曖昧な部分の調査 | `researcher` |
| バグ / テスト失敗の根本原因特定 | `debugger` |
| 実装後の独立検証 | 別 subagent を spawn（自分でテストすると確認バイアスで見落とす） |

### Agent Teams（peer-to-peer 協調）を使うべき場面

| 状況 | チーム構成 |
|---|---|
| 要件を並列分析したい | discovery-council（researcher + analyst + scout）|
| 品質を多角レビューしたい | quality-gate skill（`Skill: simplify` + 条件付き Council: security-reviewer / critic）|
| 記事を多視点で推敲したい | editorial-swarm（anti-ai-slop + fact-checker + narrative-critic + reader-advocate）|

**これらは sisyphus / quality-gate / editorial-swarm skill 内で自動構築されるが、手動でも積極使用可**。

### auto mode での anti-pattern

- ❌ 3 ファイル以上の Read を main agent が自分でやる（subagent に delegate すべき）
- ❌ 大きな実装を main agent だけで完結させる（Verifier subagent を spawn しない）
- ❌ レビューを「後でやる」と先送り（`Skill: simplify` を即実行すべき）
- ✅ 並列 agent spawn で context 節約 + 速度向上

## ワークフロー判断

| 状況 | アクション |
|------|-----------|
| ピンポイントな修正（typo, 1ファイル変更） | そのまま実行 |
| 複数ファイルにまたがる変更 | `/plan` で計画してから実行 |
| 要件が曖昧・何を作るか不明確 | `/deep-interview` で掘り下げてから `/sisyphus` |
| 新機能・設計判断が必要な変更 | `/sisyphus` で要件→設計→タスク分解→実装 |
| 複数ターンかかる実装・継続タスク（設計判断・Agent Teams 不要） | built-in `/goal <完了条件>` で継続（auto mode でも発動。Agent Teams・quality-gate なし）。大型新機能で Agent Teams + quality-gate が必要なら明示的に `/o-m-cc:sisyphus` |
| 最適化・リファクタリング・試行錯誤 | `/experiment` で実験駆動ループ（試す→測る→保持 or revert） |
| 完了を宣言する前 | `/verification` で証拠確認（テスト実行、動作確認） |
| 次に何をやるか迷う・atom が溜まってきた・放置案件が気になる・skill 使用統計を見たい | `/atom-suggest` で atoms/pipeline/outputs/skill-usage/skill-duration を統合分析（backlog 俯瞰 + skill ヘルス）|
| 思いついたアイデア・構想を保存したい | `bin/atoms add "<source>" "<内容>" "<次アクション>"` で `.claude/atoms.csv` に 1 行追記。kawai 氏型の analytics ループの起点 |
| ドキュメントの数値（agents/skills 数 / version）が一貫してるか確認 | `bin/check-consistency`（CLAUDE.md / README / plugin.json / marketplace.json を横断検証） |
| 長くなって区切りたい・新セッションに引き継ぎたい・**別マシン(EC2)に渡したい** | `/handoff` で journal.md に Recap + Next Actions を追記。同一マシンは `/recap` 併用、別マシンは VCS 同期で journal.md の最新エントリから復元（ホスト識別子 `[hostname]` 付き） |
| permission prompts が頻繁に出る・allowlist を育てたい | `/less-permission-prompts`（built-in）で直近 transcripts から read-only bash/MCP の allowlist を提案させ `.claude/settings.json` に追加 |
| PR レビューが欲しい | `/ultrareview <PR#>`（built-in, クラウド並列多エージェント）。ローカル＋静的解析込みなら `/quality-gate`（o-m-cc）|
| UI polish・複数画面 redesign・a11y 対応・CSS 統一 | `/ui-polish` で軽量ループ（Council なし、tsc/lint のみゲート）。新規デザインをゼロから生成するなら外部プラグイン `frontend-design` |
| 技術記事の最終推敲・Zenn 記事レビュー・AI 定型句除去・fact-check・読者視点チェック | `/editorial-swarm` で 4 並列レビュー Council（anti-ai-slop / fact-checker / narrative-critic / reader-advocate）。severity 付き findings を一括承認して最大 3 ラウンドで収束 |
| Sonnet/Haiku 実行時に自動で上位モデル相談を入れたい（Sisyphus 長ループで詰まり予防） | **セッション開始時に一度だけ `/advisor`（built-in beta）を実行**して有効化すれば、以後は同一リクエスト内で Opus advisor が自動 sub-inference（毎回手動プロンプトなし、Sisyphus の「止まらない」原則と両立）。SWE-bench +2.7pt / コスト -11.9%。Opus executor には効果薄。Vertex / Bedrock 非対応 |
| クロスモデルレビューで別視点が欲しい・Claude の盲点を別モデルに突かせたい | `/codex:review` or `/codex:adversarial-review`（[openai/codex-plugin-cc](https://github.com/openai/codex-plugin-cc)）。Node.js + Codex CLI + ChatGPT アカウント（無料可）必要。o-m-cc Review Council と補完関係（同モデル複数視点 vs 別モデル）|

**実装完了時のフロー:**
1. `/simplify` — コードを整理（ネイティブスキル。重複コード削除、不要コメント除去等）
2. Review Council — セキュリティ関連の変更、新規ファイル3つ以上、100行以上の変更がある場合
3. lint（`bin/lint`）— 常に実行

**原則: 迷ったら `/plan` に入る。** 計画なしで進むと後戻りが大きい。

**エスカレーション:** 想定より複雑だと判明したら上位ワークフローに切り替え。小さく始めて必要に応じて上げる。
- そのまま実行 → 複数ターンかかりそう → built-in `/goal <完了条件>`
- `/goal` → 設計判断・Agent Teams が必要と判明 → 明示的に `/o-m-cc:sisyphus`

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
