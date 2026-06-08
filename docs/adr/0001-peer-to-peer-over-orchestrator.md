# ADR-0001: Peer-to-peer 協調を採用し、中央オーケストレーターを置かない

- Status: accepted
- Date: 2025-03-01

## Context

マルチエージェントシステムの協調方式として、中央オーケストレーター（1つのエージェントが全体を制御）と peer-to-peer（エージェント同士が対等に通信）の2つのアプローチがある。

Claude Code の Agent Teams は TeamCreate でチームを作り、SendMessage でエージェント間の直接通信を提供する。spawn は hub-and-spoke だが、通信は peer-to-peer が可能。

## Decision

中央オーケストレーターを置かず、peer-to-peer 協調を採用する。

- spawn（チーム作成）はリーダーが行うが、リーダーの役割は「spawn + 結果集約」のみ
- エージェント間の議論・知見共有は SendMessage で直接行う
- 各エージェントは専門家として自律的に判断・行動する

## Consequences

- **良い面**: エージェントの自律性が高く、ボトルネックが生まれにくい。新エージェント追加時にオーケストレーターの変更が不要。Claude Code のネイティブ機能（SendMessage）をそのまま活用できる
- **悪い面**: エージェント間の調整が暗黙的になりやすい。全体の進行状況の把握にはタスクリスト（TaskList）を併用する必要がある。SendMessage の silent loss（name 未指定時）に注意が必要

## 補足: Anthropic 5 パターンとの対応（一次情報接地）

> CLAUDE.md から段階的開示で移設。本 ADR（Orchestrator-workers 拒否）の一次情報接地。

Anthropic の [Building effective agents](https://www.anthropic.com/research/building-effective-agents) が挙げる 5 パターンを o-m-cc がどう実装/拒否しているか。**「simple, composable patterns rather than complex frameworks」**という上位主張に従い、4 パターン採用 / 1 パターン意図的拒否:

| Anthropic パターン | o-m-cc の実装 | 採否 |
|---|---|---|
| Prompt chaining | SDD フロー（discovery-council → design → task-decomposition → 実装 → quality-gate） | ✅ 採用 |
| Routing | CLAUDE.md「ワークフロー判断」テーブルが状況→skill を route | ✅ 採用 |
| Parallelization | Agent Teams（discovery-council / quality-gate / editorial-swarm の並列 spawn） | ✅ 採用 |
| Evaluator-optimizer | experiment skill（try→measure→keep/revert）+ Review Council | ✅ 採用 |
| **Orchestrator-workers** | — | ❌ **意図的拒否**（上記「Peer-to-peer 協調」原則。中央オーケストレーターを置かず agent 同士が SendMessage で対等に協調する） |

→ 4/5 採用は Anthropic 推奨に従いつつ、Orchestrator-workers を拒否する判断も**同じ原典の「simple composable patterns」主張に接地**している（複雑な中央制御より、対等な agent の composition）。
