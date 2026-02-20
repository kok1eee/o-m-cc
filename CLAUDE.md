# o-m-cc - Project Configuration

## プロジェクト概要
Claude Code 用マルチエージェントプラグイン。Agent Teams (TeammateTool) による peer-to-peer マルチエージェント協調。Sisyphus Loop（タスク完了まで止まらないワークフロー）と仕様駆動開発（SDD）フローを提供。14の専門エージェント + hooks による自動化。

## 技術スタック
- Shell scripts (Bash) - hooks, scripts
- Python - セキュリティフック
- Markdown - エージェント定義, スキル定義, ドキュメント
- JSON - プラグイン設定, hooks設定
- YAML - ハンドオフ

## アーキテクチャ
- **Agent Teams**: TeammateTool (spawnTeam + teammates) による並列エージェント協調
- **peer-to-peer 通信**: teammates 間でメッセージ交換
- **共有タスクリスト**: TaskCreate/TaskUpdate で teammates が自律的にタスク管理
- **HANDOVER.md VCS 履歴**: セッション引き継ぎの VCS 履歴をナレッジベースとして活用

## Faceted Prompting
- `facets/policies/` - エージェント横断の共通ポリシー（Confidence Scoring 等）
- `facets/references/` - 段階的開示（Progressive Disclosure）用リファレンス。エージェント実行時に Read して適用
- エージェント定義（`agents/*.md`）から `facets/` を参照し、共通基準を一元管理

## エージェント実行ヒント
- `background: true` — I/O集約的な調査エージェント（researcher, learnings-researcher, explore）にバックグラウンド実行ヒント
- `isolation: worktree` — ファイル変更を行うエージェント（frontend, designer, planner, debugger）に worktree 分離ヒント
- これらは Claude Code 2.1.49+ の実験的機能。未対応バージョンでは無視される

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
