# Plan Handoff Protocol - 共通ポリシー

**上位スキル → 下位 agent / subagent / Council へ計画やコンテキストを引き継ぐときの共通プロトコル。**

Anthropic 公式 prompting best practices（Claude Opus 4.7 で観測、v2.1.154+ のデフォルト Opus 4.8 でも継続注視）で名指しされている 3 つの落とし穴を回避することを目的とする:

1. **Lost in the Middle**: 20k+ tokens の入力で、長文と指示の配置順次第で品質が最大 30% ぶれる
2. **リテラル解釈**: 4.7 は `"only critical"` `"be conservative"` `"Confidence 80+ のみ"` のような閾値指示を文字通り守り、bug を発見しても silent drop する
3. **scope 暗黙拡張**: 4.7 は明示されない範囲には instruction を一般化しない（例: 「最初のセクションだけでなく全セクションに適用」と明示しないと最初しか反映しない）

## ハンドオフの 4 原則

### 1. Path 渡しを優先する
長文（requirements.md / design.md / 既存コード / 記事本文）は **agent prompt に inline せず、ファイルパスで渡す**。agent 側で必要な箇所だけ Read する。

inline せざるを得ない場合（たとえば diff そのものを渡すとき）は次の 2 原則に従う。

### 2. Lost in the Middle 対策: 長文上、指示下
Inline で長文を渡すときの順序:

```
[長文: 入力データ / 既存コード / 仕様書]
   ↓
[XML タグでメタデータ wrap（任意）]
   ↓
[指示: タスク / 出力形式 / 制約]
```

**末尾配置で品質が最大 30% 改善する**（公式評価結果）。指示を上に置きたくなるが我慢する。

### 3. Coverage-first（agent 側で閾値カットしない）
**閾値・フィルタリング・降格はすべて集約側に集中させる。**

- ❌ agent prompt に書かない: `"Confidence 80+ のみ報告"`、`"only critical"`、`"be conservative"`、`"don't nitpick"`
- ✅ agent prompt に書く: `"検出した issue を confidence と severity を付与して全件報告"`
- ✅ 集約側に書く: 降格マトリクス（`facets/policies/confidence-scoring.md`）

理由は `facets/policies/confidence-scoring.md` の「リテラル解釈トラップ」節を参照。

### 4. Quote-first（長文を Read する agent のみ）
plan/requirements.md / plan/design.md / 記事本文のような長文を agent が **Read してから判断する**場合、prompt 末尾に 1 文追加:

```
入力ドキュメントから判断の根拠となる箇所を <quotes> タグで抽出した後、findings を返してください。
```

これにより agent は「読んだ気」ではなく実際に根拠を引用してから出力する（grounding 効果）。長文を Read しない agent には不要。

## XML タグ規約（補助）

長文 input を agent に渡すときの推奨タグ。**装飾目的では使わない**（既存の `## コンテキスト / 入力 / 出力` markdown section で structurally 等価なら不要）。

| タグ | 用途 |
|---|---|
| `<requirements>` | requirements.md の内容を inline 渡しするとき |
| `<design>` | design.md の内容を inline 渡しするとき |
| `<known_gaps>` | requirements/design の `## 既知の不足` セクション |
| `<context>` | 周辺コンテキスト（既存実装、関連コミット等） |
| `<prior_findings>` | 別 reviewer / 前ラウンドの findings |
| `<quotes>` | agent が出力する根拠引用 |
| `<output_format>` | 期待する出力スキーマ |

## scope 明示（4.7 リテラル解釈対策）

instruction を「全件」「全セクション」「全ファイル」に適用してほしいときは、**範囲を明示する**。4.7 は暗黙の一般化をしない。

- ❌ `この formatting を section に適用`
- ✅ `この formatting を **全 section に** 適用、最初の section だけではない`

## 関連ポリシー

- `facets/policies/confidence-scoring.md` — coverage-first の詳細スコアリング基準と降格マトリクス
- `facets/policies/council-output-schema.md` — Council reviewer の共通 JSON schema（集約曖昧性を解消する基盤）

## 参照する場面

このポリシーは以下から参照される:

- `skills/sisyphus/SKILL.md` — Phase 1〜3 の Skill chain
- `skills/discovery-council/reference.md` — researcher / analyst / scout の prompt
- `skills/quality-gate/reference.md` — security-reviewer / critic の prompt（コードレビュー一般は built-in `Skill: code-review` で実施、findings は main agent が修正）
- `skills/editorial-swarm/SKILL.md` — 4 reviewer の prompt
- `agents/designer.md` / `agents/planner.md` — 設計 / タスク分解の入力受領
- `agents/critic.md` / `agents/security-reviewer.md` 等 — Council 出力
