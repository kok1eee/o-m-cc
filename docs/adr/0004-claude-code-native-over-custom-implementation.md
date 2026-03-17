# ADR-0004: Claude Code ネイティブ機能を最大限活用し、独自再実装を避ける

- Status: accepted
- Date: 2025-03-01

## Context

プラグインとして独自の機能（ナレッジ管理、タスク管理、メモリ機構など）を実装する選択肢がある。一方で Claude Code 本体が TaskCreate/TaskUpdate、auto-memory、hooks などの機能を提供している。

## Decision

Claude Code のネイティブ機能を最大限活用し、独自の再実装を避ける。「ネイティブであるほど美しい」を原則とする。

- タスク管理: TaskCreate/TaskUpdate（ネイティブ）
- ナレッジ蓄積: auto-memory（ネイティブ）
- エージェント協調: Agent Teams（ネイティブ）
- 自動化: hooks（ネイティブ）

## Consequences

- **良い面**: Claude Code のアップデートに自動で追従できる。プラグインのコード量が最小限。ユーザーが学ぶ概念が少ない。ネイティブ機能の安定性・パフォーマンスを享受できる
- **悪い面**: Claude Code の仕様変更に依存する。ネイティブ機能の制約（バグ、未実装機能）をそのまま受ける。独自の最適化ができない場面がある
