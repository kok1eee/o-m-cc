# Researcher Agent Memory

## 調査済み外部ツール

### Ralph Loop / Ralph Wiggum (2026-03-09 調査)
- **概要**: Stop hook を使ってエージェントの停止をブロックし、タスク完了まで自律ループさせる手法
- **公式プラグイン**: `anthropics/claude-code` リポジトリの `plugins/ralph-wiggum/` に同梱
- **コマンド**: `/ralph-loop "<prompt>" --max-iterations <n> --completion-promise "<text>"`
- **仕組み**: Stop hook が終了を検知 → completion-promise が出力されていなければ exit 2 でブロック → 同じプロンプトを再供給
- **stop_hook_active フラグ**: Stop hook の JSON 入力に含まれる。`true` なら既にループ中なので無限ループ防止に使う
- **o-m-cc の stop-guard との関係**: 同じ Stop hook パターン。o-m-cc では `<promise>DONE</promise>` + quality-gate マーカーで条件付き制御
- **詳細**: [ralph-loop-investigation.md](ralph-loop-investigation.md)

### wevm/incur (2026-02-28 調査)
- **概要**: AIエージェント向けCLIフレームワーク（TypeScript）
- **リポジトリ**: https://github.com/wevm/incur
- **詳細**: [incur-investigation.md](incur-investigation.md)
- **要点**: create/command/serve の3関数API、TOON出力形式、skills add で自己登録
