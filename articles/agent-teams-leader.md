---
title: "Claude Code Agent Teams — リーダーは必要か？ peer-to-peer との両立と name の落とし穴"
emoji: "👑"
type: "tech"
topics: ["ClaudeCode", "AI", "マルチエージェント", "o-m-cc"]
published: false
---

## TL;DR

Agent Teams には team lead が**必須**。誰かが spawn しないとチームが始まらない。ただし lead の仕事は「spawn + 結果集約」だけで、途中の議論には関与しない。spawn は hub-and-spoke だが通信は peer-to-peer — レイヤーが違うから矛盾しない。なお、spawn 時に `name` を指定しないと teammate にならず SendMessage が黙って消えるので注意。

## 全部自動でやってほしい

Claude Code で複数エージェントを並列に動かすとき、理想はこうだ：

```
自分: 「/sisyphus 認証機能を実装して」
  → あとは全部勝手にやってくれる
  → 終わったら結果だけ教えてくれる
```

人間がタブを切り替えてタスクを割り振る、なんてことはしたくない。Tasks System を使えば `CLAUDE_CODE_TASK_LIST_ID` で複数セッションにタスクリストを共有して手動で並列化する方法もあるが、結局タスク割り振りや統合の指示を自分でやることになる。

**全自動でやるなら Agent Teams が必要だ。** そして Agent Teams にはリーダーが必要になる。

## Agent Teams にはリーダーが必須

公式ドキュメントの定義：

> One session acts as the team lead, coordinating work, assigning tasks, and synthesizing results.

リーダーなしのチームは作れない。これは設計上の制約だ：

- teammate は**チームを作れない**し、teammate を spawn もできない
- リーダーは**固定**。昇格も交代もできない
- **1セッション = 1チーム**のみ

つまり Agent Teams は **hub-and-spoke**（中央リーダー必須）の構造を持っている。

## peer-to-peer との矛盾？

[o-m-cc](https://github.com/kok1eee/o-m-cc) の設計原則には「peer-to-peer 協調」がある。

> エージェント同士が対等に議論・共有する。中央オーケストレーターは置かない

ここで矛盾が生まれるように見える。Agent Teams はリーダー必須なのに、o-m-cc はオーケストレーターを置かないと言っている。

**結論から言うと、矛盾しない。** 理由は「リーダーの仕事」にある。

## リーダーの仕事は2つだけ

o-m-cc の sisyphus では、リーダー（fork）の仕事を意図的に最小化している。

### 仕事1: spawn する

```
sisyphus (fork = team-lead)
  ├─ TeamCreate: "planning"
  ├─ Agent: name="researcher",  team_name="planning"
  ├─ Agent: name="analyst",     team_name="planning"
  └─ Agent: name="scout",       team_name="planning"
```

チームを作り、teammate を spawn する。これはリーダーにしかできない（Agent Teams の制約）。

### 仕事2: 結果を集約する

```
sisyphus (fork)
  ← researcher の調査結果
  ← analyst の要件定義
  ← scout のギャップ分析
  → requirements.md が完成したことを確認
  → 次の Phase（設計）に進む
```

各 teammate の成果物を確認し、次のフェーズに進むかどうか判断する。

### やらないこと

**途中の議論を仲介しない。**

```
researcher ──SendMessage──► analyst
  「既存の認証コード、こういうパターンだった」

analyst ──SendMessage──► scout
  「要件ドラフト書いた、漏れない？」

scout ──SendMessage──► researcher
  「エッジケースの調査、追加で必要」
```

teammate 間の通信は peer-to-peer で、sisyphus を経由しない。sisyphus は spawn したら結果を待つだけ。指示を出すオーケストレーターではなく、結果を待つコーディネーターだ。

## spawn は hub-and-spoke、通信は peer-to-peer

図にするとこうなる：

```
spawn（hub-and-spoke）         通信（peer-to-peer）

     sisyphus                researcher ◄──► analyst
    ╱    |    ╲                   ▲              ▲
   ╱     |     ╲                  └──► scout ◄───┘
researcher analyst scout
```

左の構造は hub-and-spoke だ。spawn の起点は必ずリーダー。これは Agent Teams の制約であり、回避できない。

しかし右の構造は peer-to-peer だ。researcher が見つけた知見は analyst に直接送られる。sisyphus を経由しない。analyst の要件ドラフトも scout に直接共有される。

**「リーダーが必要」と「peer-to-peer」は、矛盾ではなくレイヤーの違い**だ。spawn のレイヤーは hub-and-spoke、通信のレイヤーは peer-to-peer。

## context: fork でリーダーを隔離する

o-m-cc のスキルは `context: fork` で定義されている。

```yaml
# skills/sisyphus/SKILL.md
---
context: fork
allowed-tools: [Agent, TeamCreate, TeamDelete, SendMessage, ...]
---
```

これにより、sisyphus のリーダーセッションは**メインの会話とは別プロセス**で動く。

```
自分: /sisyphus 認証機能を実装して

sisyphus fork (= team-lead)  ← 別セッション
  ├─ Phase 1: Discovery Council (3 teammates)
  ├─ Phase 2: 設計 (designer)
  ├─ Phase 3: タスク分解 (planner)
  └─ Phase 4: 実装

自分のメイン会話             ← 空いている
```

fork にリーダーを任せることで、メインの会話が**占有されない**。sisyphus が数十分かけて計画を立てている間に、別の作業ができる。

## 落とし穴: name を指定しないと通信できない

ここからは実際に検証して判明した問題。

### SendMessage の silent loss

[GitHub issue #25135](https://github.com/anthropics/claude-code/issues/25135) で報告されている問題がある：

> SendMessage の recipient バリデーションが**空文字チェックのみ**。存在しない名前に送ると `success: true` を返しつつ、メッセージは誰にも配信されない。

recipient 名を間違えても**エラーが出ない**。成功したように見えて、メッセージは闇に消える。

### name パラメータの必須性

Agent ツールで teammate を spawn するとき、`name` と `team_name` を明示指定しないと**チームに登録されず通常の subagent として実行される**。

```yaml
# NG: teammate にならない（name がない）
Agent:
  subagent_type: "o-m-cc:code-reviewer"
  description: "Review Council: コード品質"
  prompt: "レビューして"

# OK: teammate になる
Agent:
  subagent_type: "o-m-cc:code-reviewer"
  name: "code-reviewer"           # ← 必須
  team_name: "review-council"     # ← 必須
  description: "Review Council: コード品質"
  prompt: "レビューして"
```

`name` と `team_name` は Agent Teams 有効時にのみ出現するパラメータで、通常の subagent spawn では見えない。

### 検証: name あり vs なし

実際に確認した。

**name あり**:

```yaml
TeamCreate:
  team_name: "test-naming"

Agent:
  name: "code-reviewer"
  team_name: "test-naming"
  prompt: "SendMessage(recipient: 'critic', content: 'hello') を送って"

Agent:
  name: "critic"
  team_name: "test-naming"
  prompt: "SendMessage(recipient: 'code-reviewer', content: 'hello') を送って"
```

結果：双方向でメッセージが配信される。config.json にも両方登録される。

```json
{
  "members": [
    { "agentId": "team-lead@test-naming", "name": "team-lead" },
    { "agentId": "code-reviewer@test-naming", "name": "code-reviewer" },
    { "agentId": "critic@test-naming", "name": "critic" }
  ]
}
```

**name なし**:

```yaml
Agent:
  subagent_type: "o-m-cc:code-reviewer"
  team_name: "test-no-name"
  # name を省略
  prompt: "起動したらすぐに完了して"
```

結果：config.json の members に**登録されない**。通常の subagent として実行された。

### 何が怖いか

name を書き忘れると：
- Agent は起動する（エラーにならない）
- SendMessage も `success: true` を返す（エラーにならない）
- でもメッセージは配信されない（silent loss）

**エラーが一切出ないので、動いているように見えて全く通信できていない。** peer-to-peer の通信が壊れていることに気づけない。

### 対策

```bash
# チームのメンバーを確認
cat ~/.claude/teams/{team-name}/config.json | jq '.members[].name'
```

「動いてるはずなのに結果がおかしい」と思ったら、まず config.json の members を確認する。

## まとめ

| 疑問 | 回答 |
|------|------|
| リーダーは必要か？ | **必要**。Agent Teams の制約。spawn はリーダーにしかできない |
| peer-to-peer と矛盾しないか？ | **しない**。spawn は hub-and-spoke だが通信は peer-to-peer |
| リーダーは何をするか？ | **spawn + 結果集約**の2つだけ。途中の議論には関与しない |
| メインの会話が占有されない？ | `context: fork` でリーダーを別セッションに隔離すれば空く |
| name を省略するとどうなる？ | teammate にならず SendMessage が silent loss する |

リーダーは必要だが、リーダーの仕事は最小限にできる。o-m-cc の sisyphus は「最小限のリーダー」であり、teammate が自律的に peer-to-peer で議論する設計を支えている。

---

*2026-03-12 執筆・検証。Claude Code v2.1.74, Agent Teams (experimental)。*
