# o-m-cc - Project Configuration

## プロジェクト概要
Claude Code 用マルチエージェントプラグイン。Agent Teams (TeammateTool) による peer-to-peer マルチエージェント協調。Sisyphus Loop（タスク完了まで止まらないワークフロー）と仕様駆動開発（SDD）フローを提供。14の専門エージェント + hooks による自動化。

## 技術スタック
- Shell scripts (Bash) - hooks, scripts
- Python - セキュリティフック
- Markdown - エージェント定義, コマンド定義, ドキュメント
- JSON - プラグイン設定, hooks設定
- YAML - ハンドオフ

## アーキテクチャ
- **Agent Teams**: TeammateTool (spawnTeam + teammates) による並列エージェント協調
- **peer-to-peer 通信**: teammates 間でメッセージ交換
- **共有タスクリスト**: TaskCreate/TaskUpdate で teammates が自律的にタスク管理
- **HANDOVER.md VCS 履歴**: セッション引き継ぎの VCS 履歴をナレッジベースとして活用

## 開発ガイドライン
- hooks スクリプトは `set -euo pipefail` + 共通ライブラリ (`hooks/lib/common.sh`) を使用
- エージェント数・コマンド数を変更したら `plugin.json`, `marketplace.json`, `README.md`, `capabilities.md` を同期
- バージョンは `plugin.json` を正とし、他ファイルも合わせる
