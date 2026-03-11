# o-m-cc - Project Configuration

## プロジェクト概要
Claude Code 用マルチエージェントプラグイン。Agent Teams (TeammateTool) による peer-to-peer マルチエージェント協調。Sisyphus Loop（タスク完了まで止まらないワークフロー）と仕様駆動開発（SDD）フローを提供。13の専門エージェント + hooks による自動化。

## 技術スタック
- Shell scripts (Bash) - hooks, scripts
- Python - セキュリティフック
- Markdown - エージェント定義, スキル定義, ドキュメント
- JSON - プラグイン設定, hooks設定
## アーキテクチャ
- **Agent Teams**: TeammateTool (spawnTeam + teammates) による並列エージェント協調
- **peer-to-peer 通信**: teammates 間でメッセージ交換
- **共有タスクリスト**: TaskCreate/TaskUpdate で teammates が自律的にタスク管理
- **ナレッジ蓄積**: Claude Code の auto-memory に委ねる（プラグイン独自のナレッジ管理は行わない）

## Faceted Prompting
- `facets/policies/` - エージェント横断の共通ポリシー（Confidence Scoring 等）
- `facets/references/` - 段階的開示（Progressive Disclosure）用リファレンス。エージェント実行時に Read して適用
- エージェント定義（`agents/*.md`）から `facets/` を参照し、共通基準を一元管理

## エージェント実行ヒント
- `background: true` — I/O集約的な調査エージェント（researcher）にバックグラウンド実行ヒント
- `isolation: worktree` — ファイル変更を行うエージェント（frontend, designer, planner, debugger）に worktree 分離（2.1.50+ で正式サポート）

## 設計思想と強み（変更提案時に必ず照合すること）

以下は o-m-cc の核となる設計思想。これらを損なう提案があった場合は、**必ず指摘して代替案を提示すること**。

| 原則 | 説明 | アンチパターン例 |
|------|------|-----------------|
| **Peer-to-peer 協調** | エージェント同士が対等に議論・共有する。中央オーケストレーターは置かない | 全エージェントを統括する「マスターエージェント」の導入 |
| **Claude Code ネイティブ活用** | ネイティブであるほど美しい。Claude Code が提供する機能（TaskCreate, auto-memory, hooks 等）を最大限活用し、独自の再実装を避ける | プラグイン独自のナレッジ管理機構の導入、ネイティブ機能と重複するファイルベースの仕組み（例: tasks.md） |
| **Sisyphus（止まらない）** | タスク完了まで止まらない。hooks の exit code で制御 | 途中で確認を求めて止まる設計、過剰な承認ステップ |
| **Lightweight** | Markdown + Shell のみ。ビルド不要、ランタイム依存最小 | TypeScript/Python への書き換え、ビルドステップの導入 |
| **Progressive Disclosure** | frontmatter → 本文 → 参照ファイルの3段階でトークン消費を最小化 | 全情報を1ファイルに詰め込む、エージェント定義の肥大化 |
| **Plugin ネイティブ** | Claude Code のプラグインシステムに準拠。settings.json で自動設定 | プラグイン外でのグローバル設定変更を前提とする設計 |
| **エージェント自律性** | 各エージェントは専門家として自律的に判断・行動する | エージェントの行動を細かくスクリプト化して自由度を奪う |

## 開発ガイドライン
- hooks スクリプトは `set -euo pipefail` + 共通ライブラリ (`hooks/lib/common.sh`) を使用
- エージェント数・スキル数を変更したら `plugin.json`, `marketplace.json`, `README.md`, `capabilities.md` を同期
- バージョンは `plugin.json` を正とし、他ファイルも合わせる

## デプロイ
```bash
# 1. バージョンを更新（plugin.json, marketplace.json, README.md）
# 2. コミット＆プッシュ
jj describe -m "chore: bump to vX.Y.Z"
jj bookmark set main -r @
jj git push
# 3. プラグイン更新
claude plugin update o-m-cc@kok1eee
```
