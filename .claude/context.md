# Context

> compaction で失われる文脈を保存。compaction summary と合わせて復元に使用。
> Learnings に長期的価値があれば MEMORY.md に反映すること。

### Snapshot (03/14 19:00, manual)

**Intent:** o-m-cc v0.21→v0.23 — sisyphus ワークフロー改善、公式プラグイン連携、hooks 整理

**Outcomes:** v0.23.0 リリース
- Agent Teams name/team_name 必須化（全スキル）
- stop-guard: plan/ を diff カウントから除外
- sisyphus: foreground spawn 明記、TeamCreate 前に TeamDelete cleanup
- SessionEnd/PreCompact timeout 10s→30s
- 公式プラグイン連携: security-guidance に委譲（独自 hook 削除）、claude-md-management（init/handover）、hookify/plugin-dev/playground
- init: LSP 自動検出、推奨プラグインインストール
- review スキルを quality-gate に統合（5スキルに）
- PostCompact hook 新設（compaction 後の状態リマインド）
- 承認ゲート削除 → 差し戻しパターン（Council 検証 + SendMessage）
- teammate-idle hook 削除（固定役割 spawn では不要）
- Phase 間 TeamDelete（Council 先走り防止）
- [TRACKING] プレフィックス（Phase タスク誤認防止）
- Headless モード（CLAUDE_NON_INTERACTIVE=1）
- 記事: Agent Teams リーダー必須性 + name の落とし穴

**Learnings:**
- TeamCreate でタスクスコープが切り替わる → タスク登録は TeamCreate の後
- Council teammate は Phase 完了時に TeamDelete で終了させないと先走る
- 承認ゲートは Council の peer-to-peer 検証と二重チェック → 不要
- 公式プラグインは「ネイティブ活用」原則に合致 → 独自実装より委譲

**Friction:**
- SessionEnd hook が 10s timeout で大きな transcript を処理できずキャンセル → 30s に延長
- designer を background spawn すると fork が「やることない」と止まろうとする → foreground 明記

**Next Steps:**
- sisyphus を実際に v0.23.0 で実行して TeamDelete/TRACKING の効果を検証
- PostCompact hook の実環境でのテスト
- skill-creator での description 最適化（未完了）
