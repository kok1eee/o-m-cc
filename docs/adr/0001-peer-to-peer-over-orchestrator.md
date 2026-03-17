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
