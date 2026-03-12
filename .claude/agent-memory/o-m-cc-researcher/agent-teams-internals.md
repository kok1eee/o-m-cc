---
name: Agent Teams (TeammateTool) 内部仕様
description: Claude Code v2.1.74 の Agent Teams / TeammateTool の詳細仕様。config.json 構造、spawn CLI フラグ、inbox IK 関数、メッセージプロトコル、ツールセット差異、既知バグ
type: reference
---

# Agent Teams (TeammateTool) 内部仕様

調査日: 2026-03-12 (v2.1.74 バイナリ対象)
有効化: `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` in settings.json

## ディレクトリ構造

```
~/.claude/
├── teams/{team-name}/
│   ├── config.json
│   └── inboxes/{agent-name}.json  # メッセージ inbox
└── tasks/{team-name}/             # タスク一覧
```

## config.json 構造

```json
{
  "name": "team-name",
  "leadAgentId": "team-lead@team-name",
  "members": [{
    "agentId": "name@team-name",
    "name": "name",
    "agentType": "general-purpose",
    "model": "claude-opus-4-6",
    "color": "#hexcode",
    "backendType": "in-process|tmux|iterm2",
    "tmuxPaneId": "pane-ref"
  }]
}
```

## spawnTeammate の CLI コマンド（tmux バックエンド）

```bash
env CLAUDECODE=1 CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 \
  ~/.local/share/claude/versions/2.1.74 \
  --agent-id {name}@{team-name} \
  --agent-name {name} \
  --team-name {team-name} \
  --agent-color {color} \
  --parent-session-id {uuid} \
  --agent-type general-purpose \
  --model claude-opus-4-6
```

**重要**: `CLAUDE_CONFIG_DIR` が引き継がれない（issue #24989）。カスタム config dir 使用時は `tmux set-environment -g CLAUDE_CONFIG_DIR` が必要。

## spawnInProcessTeammate（in-process バックエンド）

- 同一 Node.js プロセス内で `SessionPrompt.loop()` を非同期起動
- AbortController でライフサイクル管理
- 即座に `{ sessionID, label }` を返す（fire-and-forget）

## TaskツールとTeammateToolの関係

```
Task(prompt, team_name, name) → teammate として spawn（TeammateTool の実体）
Task(prompt)                  → 従来の subagent
```

## ツールセット差異

| ツール | メインセッション | subagent | teammate |
|--------|----------------|----------|----------|
| Agent (spawn) | ○ | ○ | **×** |
| TeamCreate/Delete | ○ | ○ | **×** |
| Cron系 | ○ | ○ | **×** |
| AskUserQuestion | ○ | × | **×** |
| EnterPlanMode | ○ | × | **×** |
| SendMessage | ○ | ○ | ○ |
| TaskCreate/Update/List | ○ | ○ | ○ |

teammate (20ツール) < subagent (25ツール) < main (26+ツール)

## SendMessage メッセージタイプ

- `message`: 単一 recipient への直接送信
- `broadcast`: 全 teammate へ（高コスト、多用禁止）
- `shutdown_request`: `shutdown-{timestamp}@{recipient}` の requestId を生成
- `shutdown_response`: approved フラグ + reason
- `plan_approval_response`: planContent + requestId

## メッセージ inbox のフォーマット

```json
[{
  "from": "sender-name",
  "text": "...",
  "summary": "短いプレビュー",
  "timestamp": "ISO8601",
  "color": "#hex",
  "read": false
}]
```

プロトコルメッセージは text フィールド内に JSON を埋め込む。

## IK（injectMessage）関数

メッセージ配信は2層：
1. inbox ファイルに append（source of truth、.lock でファイルロック）
2. 対象セッションのコンテキストに inject

受信側レンダリング（XML タグ形式）:
```xml
<teammate_message teammate_id="{from}" color="{color}" summary="{summary}">
  {text}
</teammate_message>
```

`read` フラグは prompt loop 完了時に一括 markRead（メッセージ毎でなくバッチ処理）。

## in-process vs tmux の特性差異

| 観点 | in-process | tmux |
|------|-----------|------|
| メッセージ配信 | event-driven（即時） | ファイルポーリング |
| プロセス境界 | 同一 Node.js | 別プロセス |
| 安定性 | 高（推奨） | 既知バグ多数 |
| VS Code | 使用可 | 不可 |

## 制約（ハード）

- 1セッション = 1チームのみ
- ネスト不可（teammate は spawn できない）
- リーダー固定（昇格・委譲なし）
- `/resume` で in-process teammate は復元されない

## 既知バグ（v2.1.74 時点）

- **issue #25135**: SendMessage の recipient バリデーションが空文字チェックのみ。存在しない名前へも `success: true` で silent loss
- **issue #24989**: tmux モードで `CLAUDE_CONFIG_DIR` が非継承
- **issue #24771**: tmux モードで inbox ポーリングが切断
- **issue #23572**: iTerm2 検出失敗時のサイレント in-process フォールバック
- **feature gating**: `I9() && qFB()` の両方が true の時のみ有効。`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` でアンロック

## o-m-cc との関連

- Agent Teams は hub-and-spoke（中央リーダー必須）← o-m-cc の peer-to-peer 原則と異なる設計
- TeammateIdle / TaskCompleted hook は o-m-cc の stop-guard パターンと相補的（exit 2 でブロック）
- inbox の recipient 名: lead の inbox は "team-lead" が正しい名前（それ以外は silent loss リスク）
