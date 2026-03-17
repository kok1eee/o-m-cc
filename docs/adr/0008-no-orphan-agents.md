# ADR-0008: ワークフローに組み込まれないエージェントは持たない

- Status: accepted
- Date: 2025-03-18

## Context

o-m-cc は最大12体のエージェントを持っていた。しかし vision, advisor, frontend の3体はどのスキル（sisyphus, quality-gate, discovery-council 等）からも spawn されず、「ユーザーが直接呼ぶかもしれない」という理由だけで存在していた。

- vision: Claude Code 本体が Read で画像・PDF を直接読める
- advisor: Opus に直接聞けばいい。スキルからの参照なし
- frontend: エージェントとしての差別化がない。facets のリファレンスで十分

これらは常時 frontmatter がロードされるためゼロコストではなく、capabilities.md の情報量も増やしていた。

## Decision

エージェントはすべてワークフロー（スキル）に組み込まれている前提とする。スキルから spawn されないエージェントは作らない・残さない。

判断基準：
- **残す**: スキルの `subagent_type` で参照されている、またはワークフロー内で明確な役割がある
- **削除**: 「ユーザーが直接呼ぶかも」だけが存在理由

## Consequences

- **良い面**: エージェント数が減り、capabilities.md がシンプルになる。全エージェントが明確な役割を持つ。新エージェント追加時の基準が明確
- **悪い面**: ユーザーが直接 debugger 以外の専門エージェントを呼び出す手段が減る。ただし Claude 本体や他のプラグインで代替可能
