# Ralph Loop / Ralph Wiggum 調査記録 (2026-03-09)

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

## 参考情報源

- [公式ドキュメント: Hooks reference](https://code.claude.com/docs/en/hooks)
- [公式プラグイン: plugins/ralph-wiggum](https://github.com/anthropics/claude-code/tree/main/plugins/ralph-wiggum)
- [Alibaba Cloud: From ReAct to Ralph Loop](https://www.alibabacloud.com/blog/from-react-to-ralph-loop-a-continuous-iteration-paradigm-for-ai-agents_602799)
- [Awesome Claude: Ralph Wiggum](https://awesomeclaude.ai/ralph-wiggum)
