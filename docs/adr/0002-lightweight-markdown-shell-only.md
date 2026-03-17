# ADR-0002: Markdown + Shell のみで構成し、ビルドステップを持たない

- Status: accepted
- Date: 2025-03-01

## Context

Claude Code プラグインの実装言語として TypeScript、Python、Shell などが選択肢にある。o-m-cc はエージェント定義・スキル定義・hooks で構成されており、複雑なロジックは Claude 自身が担う。

## Decision

Markdown + Shell のみで構成する。ビルドステップ、ランタイム依存は持たない。

- エージェント定義・スキル定義: Markdown（frontmatter + 本文）
- hooks: Bash スクリプト
- 設定: JSON
- TypeScript/Python への書き換えは行わない

## Consequences

- **良い面**: インストールが `claude plugin install` のみで完結。ビルドエラーがない。依存管理不要。どの環境でも動く。コードリーディングの障壁が低い
- **悪い面**: 複雑なロジック（パーサー、データ変換など）を Shell で書くと可読性が下がる。型安全性がない。テストフレームワークが貧弱
