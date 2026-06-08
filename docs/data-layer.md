# データレイヤー（スキル間で共有される状態）

> CLAUDE.md から段階的開示（Progressive Disclosure）で分離。スキル間で共有される状態の
> writer / reader / 用途、`O_M_CC_DATA_DIR` による公開/私的データ分離、跨マシン同期の詳細。

スキルはコンテキストではなくファイル/ネイティブ状態を介して連携する:

> **データ層の置き場 (`O_M_CC_DATA_DIR`)**: `atoms.csv` / `pipeline.csv` / `outputs.csv` は個人の開発バックログであり、公開される o-m-cc repo にコミットすべきではない。環境変数 **`O_M_CC_DATA_DIR`** を私的リポのパスに設定すると、`bin/atoms` / `bin/atom-suggest` / `bin/edd-check` はそこを読み書きする（未設定なら後方互換で `<repo root>/.claude`）。これにより「公開プラグイン（機構）」と「私的データ（バックログ）」を分離し、私的リポの git で cross-machine 同期・定期改善を回す。下表の `.claude/*.csv` は `O_M_CC_DATA_DIR` 設定時はそのディレクトリを指す。

| 場所 | Writer | Reader | 用途 |
|---|---|---|---|
| `.claude/atoms.csv` | `bin/atoms add` / 手動 | atom-suggest | アイデアバックログ（kawai 氏 atoms 相当）|
| `.claude/pipeline.csv` | `bin/atoms promote` | atom-suggest, designer | 要件化フェーズ（atoms ↔ plan/*.md の橋渡し）|
| `.claude/outputs.csv` | `bin/atoms complete [--metric]` | atom-suggest, edd-check | 完了履歴（成果物 path + outcome + metric）。metric 列は EDD 構造化フォーマット `key:value;key:value`（標準 key: fr_coverage / duration_ms / status / token_cost）。自由テキストとの後方互換あり（FR-2）|
| `plan/requirements.md` | discovery-council, deep-interview | designer, critic, quality-gate | 要件定義（FR-X 形式）|
| `plan/design.md` | designer | planner, critic, quality-gate | アーキテクチャ設計 |
| `plan/archive/<timestamp>-<slug>/` | sisyphus Step 0B | — | 旧 plan の履歴保全（rm しない）|
| `plan/progress.md` | experiment | experiment (次 iteration) | 試行履歴（keep/revert 判断）|
| TaskCreate / TaskUpdate | planner, sisyphus | 全 teammate | ネイティブタスクリスト（Claude Code 機能）。atoms backlog 由来の実装はタスク `metadata` に `pipeline_id`/`atom_id` を付与して業務状態（CSV）と橋渡し（12-factor Factor 5、CSV への複製はしない軽量規約）|
| `.claude/journal.md` | handoff | session-resume.sh, 別マシン | EC2 跨ぎ引き継ぎ（Recap + Next Actions）|
| `.claude/memory/` | Claude Code auto-memory | 全スキル次回セッション | auto-memory（ユーザープロファイル・フィードバック・プロジェクト知見）|
| Gotchas セクション（各 SKILL.md） | evolve | 次回スキル起動時 | スキル固有の実行経験から抽出した学び |
| `.editorial/round-N/` | editorial-swarm | editorial-swarm (次 round) | 記事レビューの findings / diff 履歴 |
| `${CLAUDE_PLUGIN_DATA}/skill-usage.csv` | skill-usage-log.sh / skill-prompt-log.sh hooks | atom-suggest, evolve | スキル使用履歴（CSV: timestamp,skill,trigger,session_id,effort,token_cost。trigger ∈ claude-proactive/user-slash。session_id は v2.1.132+、effort は v2.1.133+、token_cost は EDD FR-4 で列定義のみ先行・実値は /usage Desktop 対応後）|
| `${CLAUDE_PLUGIN_DATA}/skill-duration.csv` | skill-duration-log.sh hook | atom-suggest | スキル実行時間（CSV: timestamp,skill,duration_ms）|
| `${CLAUDE_PLUGIN_DATA}/agent-duration.csv` | agent-duration-log.sh hook | atom-suggest | subagent dispatch 実行時間（CSV: timestamp,agent_type,duration_ms。v2.1.144+ の SubagentStop hook input から取得）|

**原則**: コンテキスト（会話履歴）に依存しない。別スキル/別セッション/別マシンから再開できる状態を必ずファイルに書く。

**Mac/EC2 跨マシン同期** (オプショナル): 上 3 つの CSV (skill-usage / skill-duration / agent-duration) は `${CLAUDE_PLUGIN_DATA}` 配下に置かれるため per-machine になる。`bin/sync-plugin-data setup` で `~/dotfiles/claude/.claude/plugins/data/o-m-cc-kok1eee/` に実体を移して symlink 化すると dotfiles の git 同期に乗る（`.gitattributes` の `merge=union` で append-only 行を両側保持）。詳細は README「跨マシン同期」セクション参照。
