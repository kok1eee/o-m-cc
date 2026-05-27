# Troubleshooting — ランタイムの落とし穴

o-m-cc 固有の問題ではないが、o-m-cc（Agent Teams / 高 effort skill / 長セッション）を回していると踏みやすい Claude Code / モデル側の事象と対処をまとめる。

---

## `The model's tool call could not be parsed (retry also failed).`

### 症状
ツール呼び出しの直後（Bash / Edit / MCP など種類を問わず）に上記エラーが出て作業が止まる。retry しても同じ。`/clear` しても数ターンで再発。**`/context` に空きがあっても発生する**。

### 真因（利用者側の問題ではない）
**Opus 4.7（1M context バリアント）+ extended thinking（default `xhigh`）のモデル応答ストリーミングバグ**（Anthropic Issue [#24662](https://github.com/anthropics/claude-code/issues/24662)）。

セッションの jsonl（`~/.claude/projects/<proj>/<session-id>.jsonl`）を見ると、parse 失敗直前の assistant メッセージが壊れている:
1. `content` に空の `thinking` ブロックしかない（text / tool_use が続かない）
2. `thinking` が空文字 `""`
3. `stop_reason: "tool_use"` なのに `tool_use` ブロックが存在しない

Claude Code の parser は「`stop_reason: tool_use` なら `tool_use` ブロックがあるはず」という前提なので parse 不能 → retry も同じ壊れた応答が返り `retry also failed`。

| 要因 | 寄与度 |
|---|---|
| Opus 4.7 応答ストリーミングのバグ | 核心 |
| extended thinking が default `xhigh`（thinking-heavy） | 大 |
| 1M context バリアント | 中 |
| 長期セッション（cache_read 大） | 中 |

> **コンテキスト使用率・MCP 数は主因ではない**。出力（モデル応答）側の構造バグなので、入力容量の対策（`/compact` 等）は効かない。

### 対処（効果順）
1. **`/effort medium`**（または `low`）で thinking を抑える — 根本に近い対症療法。⚠️ o-m-cc の `quality-gate` / `discovery-council` / `design` / `sisyphus` は意図的に `effort: high`。品質とのトレードオフがあるため、バグが頻発するときの一時退避として使う
2. **`CLAUDE_CODE_DISABLE_1M_CONTEXT=1 claude`** で 1M context バリアントを無効化（標準 200k に戻す）— 再現条件を 1 つ潰す
3. **壊れたセッションは `--resume` / `--continue` しない**。壊れた assistant メッセージが履歴に残ると再開のたびに再送され、同じエラーが続く。→ **`/o-m-cc:handoff` で `journal.md` に状態をスナップショットし、新規セッションで再開する**（これは記事推奨の復帰策そのもの。o-m-cc は標準で持っている）
4. **`claude update`** — 2.1.148→152 と stream-handling 修正が継続投入されている（v2.1.152 の「stale thinking-block signatures を先回り除去 + retry 安全網」もこの系列）。完治はモデル側の修正待ち
5. **`/bug`** で Anthropic に報告（session ID + request_id 添付）。モデル/ストリーミング側のバグなのでこれが最も価値が高い

### 効かない対処
- `/clear`（一時的に止まるが数ターンで再発。原因は履歴でなくモデル応答）
- `/compact`（コンテキストは主因でないため無意味）
- MCP を切る（元々小さければ寄与なし）

### o-m-cc 運用での位置づけ
o-m-cc は **Agent Teams + 高 effort skill + 長セッション**が前提なので、上表の寄与条件（thinking-heavy / 長期）を踏みやすい側にある。一方で **復帰策（`/handoff` → `journal.md` → 新規セッション再開）を標準装備**しているのが強み。バグを踏んだら粘らず handoff して切り替えるのが最短。

---

## その他
- hooks のエラー: `.claude/hooks-error.log` を確認（[docs/hooks-errors.md](hooks-errors.md)）
- 旧 Claude Code での未知 skill エラー: v0.59.0 は CC v2.1.146+ 必須（`/code-review` 依存）。旧 CC では v0.58.0 を pin
