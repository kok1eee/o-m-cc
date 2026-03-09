# Ralph Loop / Ralph Wiggum 調査記録 (2026-03-09, 更新: 2026-03-09)

## 概要

"Ralph Loop" は Claude Code の Stop hook を応用した自律的なエージェントループ手法。
Geoffrey Huntley が "Ralph Wiggum technique" として広めたことから命名。

## 公式対応状況

- Anthropic が `plugins/ralph-wiggum` を公式プラグインとして `anthropics/claude-code` リポジトリに同梱
- Claude Plugin Marketplace で `ralph-loop` として公開
- `/ralph-loop` コマンドで起動、`/cancel-ralph` でキャンセル

## 動作メカニズム

```
1. /ralph-loop "タスク" --completion-promise "DONE" を実行
2. Claude がタスクを実行
3. Claude が停止しようとする
4. Stop hook が起動
5. last_assistant_message に completion-promise が含まれるか確認
   - 含まれない → decision: "block" でブロック、同じプロンプトを再供給
   - 含まれる  → 許可して終了
6. 2 に戻る（max-iterations まで）
```

## 公式 Stop Hook の仕組み（code.claude.com/docs/en/hooks より）

### Stop イベントの入力スキーマ

```json
{
  "session_id": "abc123",
  "transcript_path": "~/.claude/projects/.../transcript.jsonl",
  "cwd": "/Users/...",
  "permission_mode": "default",
  "hook_event_name": "Stop",
  "stop_hook_active": true,   // ← 重要: 既にループ中かどうか
  "last_assistant_message": "I've completed the refactoring..."
}
```

### Stop hook の decision control

```json
{
  "decision": "block",
  "reason": "Must be provided when Claude is blocked from stopping"
}
```

- `decision: "block"` → Claude の停止を防ぐ
- `reason` → Claude に伝えるメッセージ（次に何をすべきか）
- exit code 2 も同様にブロック可（stderr がエラーメッセージとして Claude に渡る）

### stop_hook_active フラグ

- Stop hook の結果として Claude が継続している場合 `true` になる
- 無限ループ防止のためにこの値を確認することが推奨されている
- `SubagentStop` にも同じフィールドが存在する

## o-m-cc の stop-guard との比較

| 観点 | ralph-wiggum | o-m-cc stop-guard |
|------|-------------|-------------------|
| トリガー | completion-promise の欠如 | `<promise>DONE</promise>` の有無 |
| 品質ゲート | なし（ループのみ） | `<proof>QUALITY_GATE_PASSED</proof>` マーカー必須 |
| 安全弁 | --max-iterations | SISYPHUS_MAX_ITERATIONS（デフォルト50）+ 同一理由スロットリング |
| ブロック方法 | exit 2 または decision: "block" JSON | exit 2（stderr を CTA として出力） |
| subagent対応 | 不明 | agent_type チェックで subagent はスキップ |

## 関連するサードパーティ実装

- `snarktank/ralph`: 独立したプロセスとして複数イテレーション実行（Stop hook ではなく外部ループ）
- `frankbria/ralph-claude-code`: 二段階完了確認（ヒューリスティック + 明示的シグナル）

## 新機能: /loop と Cron スケジュールタスク（公式）

公式ドキュメント `code.claude.com/docs/en/scheduled-tasks` より:

- `/loop 5m check if the deployment finished` — セッション内の繰り返し実行
- CronCreate/CronList/CronDelete ツールを内部で使用
- 最大50タスク/セッション。3日で自動expire。セッション終了でキャンセル
- CLAUDE_CODE_DISABLE_CRON=1 で無効化可能
- Sisyphus ループとは用途が異なる（Stop hook → 品質ゲート付き完了保証 vs. /loop → ポーリング/監視用）

## 新しい hook タイプ（2026年追加）

公式ドキュメントより確認した新機能:

| タイプ | 用途 | 対応イベント |
|--------|------|------------|
| `type: "command"` | 従来のシェルコマンド | 全イベント |
| `type: "http"` | HTTP POST でイベントを外部サービスへ送信 | 一部イベント |
| `type: "prompt"` | LLM（Haiku）に判定させる。レスポンス: `{"ok": true/false, "reason": "..."}` | Stop, SubagentStop, TaskCompleted, PreToolUse等 |
| `type: "agent"` | サブエージェントを召喚し、Read/Grep/Glob でファイル検証 | 同上 |

### prompt hook の例（Stop に有用）

```json
{
  "hooks": { "Stop": [{ "hooks": [{
    "type": "prompt",
    "prompt": "Evaluate if all tasks are complete: $ARGUMENTS. Return {\"ok\": true} or {\"ok\": false, \"reason\": \"...\"}",
    "timeout": 30
  }]}]}
}
```

## 新しい hook イベント（o-m-cc が既にカバー済み）

| イベント | 用途 | o-m-cc での対応 |
|---------|------|----------------|
| `TeammateIdle` | teammate が idle になったとき | teammate-idle.sh 実装済み |
| `TaskCompleted` | タスク完了マーク時 | task-completed.sh 実装済み |
| `SubagentStop` | サブエージェント完了時 | stop-guard.sh の agent_type チェックでカバー |
| `ConfigChange` | 設定ファイル変更時 | 未実装（必要なら監査ログ用途） |
| `InstructionsLoaded` | CLAUDE.md ロード時 | 未実装（観測のみ、blocking不可） |

## o-m-cc 強化の検討ポイント

1. **stop-guard に `decision: "block"` JSON 形式を追加検討**: 現在は exit 2 のみ。JSON 形式だと `reason` をより構造的に渡せる（ただし既存の exit 2 でも機能しているため優先度低）
2. **prompt hook による Stop 判定**: `type: "prompt"` で LLM に品質チェックを委ねることも可能。ただし Lightweight 原則（シェルスクリプトのみ）から逸脱するため見送り
3. **async: true のポーリング活用**: PostToolUse に `async: true` を付けてバックグラウンドでテスト実行し、結果を次ターンで報告するパターンは auto-verify.sh の改善に使える
4. **TaskCompleted の exit 2 ブロック**: o-m-cc はすでに実装済み。task-completed.sh は残タスクがあれば exit 2 でブロック → Sisyphus に統合済み

## 参考情報源

- [公式ドキュメント: Hooks reference](https://code.claude.com/docs/en/hooks)
- [公式ドキュメント: Scheduled tasks](https://code.claude.com/docs/en/scheduled-tasks)
- [公式プラグイン: plugins/ralph-wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum)
- [Alibaba Cloud: From ReAct to Ralph Loop](https://www.alibabacloud.com/blog/from-react-to-ralph-loop-a-continuous-iteration-paradigm-for-ai-agents_602799)
- [Awesome Claude: Ralph Wiggum](https://awesomeclaude.ai/ralph-wiggum)
