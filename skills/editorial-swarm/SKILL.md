---
name: editorial-swarm
description: "技術記事の並列レビュー Council。anti-ai-slop / fact-checker / narrative-critic / reader-advocate を並列 spawn、severity 付き findings を最大3ラウンドで収束。Zenn などのドラフト完成後に使う。「記事レビュー」「editorial swarm」「編集会議」「記事推敲」「記事添削」で発動。"
argument-hint: "<article path> [target reader profile]"
allowed-tools: [Agent, TeamCreate, TeamDelete, SendMessage, TaskCreate, TaskUpdate, Read, Write, Edit, AskUserQuestion, Glob, Grep, WebSearch, WebFetch, Bash]
model: sonnet
effort: high
context: fork
---

# Editorial Swarm - 並列編集レビュー Council

4 人のレビュアー（anti-ai-slop, fact-checker, narrative-critic, reader-advocate）が peer-to-peer でドラフトをレビューし、severity 付きの提案を集約する。discovery-council の「文章版」。

> **共通プロトコル**: ハンドオフの 4 原則（path 渡し優先 / 長文上・指示下 / coverage-first / quote-first）は `facets/policies/plan-handoff.md` を参照。各 reviewer prompt は閾値カットなしで全件返し、自動 apply は集約側 (Step 4) のみが判断する。

## 対象記事

$ARGUMENTS

## いつ使う / いつ使わない

| 使う | 使わない |
|---|---|
| ドラフトが概ね完成（v0.9 以上）、最終推敲したい | 構成から考える → まず手で書く |
| Zenn / note / ブログ用の技術記事 | 社内メモ・議事録（レビューコスト過剰） |
| 対象読者が明確 | 読者不明 → まず `/deep-interview` 等で固める |
| 3 ラウンド程度で収束を期待できる品質 | 大規模書き直し → 手で構造から見直す |

## Step 1: 前提確認

AskUserQuestion で以下を一括確認:

1. **対象読者プロファイル**（未指定なら必須）: 「Claude Code 経験者」「Web エンジニア一般」「非エンジニア」等
2. **最大ラウンド数**: デフォルト 3。2 にしたいか
3. **自動 apply 範囲**: デフォルト「low + 非競合のみ」。widen したいか、手動のみか

対象記事が存在しない場合は AskUserQuestion で path を再確認する。

### 作業ディレクトリ準備

```bash
mkdir -p .editorial
```

## Step 2: Team 作成 + 4 エージェント並列 spawn

```
TeamDelete:
  team_name: "editorial"  # エラーが出なければスキップ

TeamCreate:
  team_name: "editorial"
  description: "Editorial Swarm: 記事の並列レビュー"
```

4 つのレビュアーを同時 spawn。各エージェントは `facets/policies/council-output-schema.md` の **共通 Council JSON schema** に従う JSON オブジェクト 1 つを返す:

```json
{
  "reviewer": "anti-ai-slop",
  "schema_version": "1",
  "summary": "1-2 文の総評",
  "findings": [
    {
      "id": "F001",
      "category": "ai-slop",
      "line_range": "12-15",
      "issue": "問題の要約",
      "fix": "具体的な修正案（diff 風でなくテキスト置換可能な形）",
      "confidence": 85,
      "severity": "high",
      "quotes": ["問題箇所の引用 30 文字程度"]
    }
  ],
  "memo": "free-form notes（任意）"
}
```

**reviewer 別の `category` 値**: `ai-slop` / `fact` / `narrative` / `reader-fit`。
**`file` フィールド**: 記事ファイルが 1 つなので各 finding では省略可（reviewer ごとに `memo` で記事 path を記録）。

### レビュアー別の prompt テンプレート

#### reviewer-A: anti-ai-slop

```
あなたは「AI が書いた文章の匂い」を嗅ぎ分ける編集者です。

対象記事: $ARTICLE_PATH
対象読者: $READER_PROFILE

以下を high/medium/low で指摘してください:

**冗長な AI 定型句（具体フレーズリスト）**:
- 動詞冗長化: 「〜することができます」「〜することが可能です」「〜することによって」「〜することにより」
- 視点テンプレ: 「〜の観点から」「〜という観点では」「〜の側面から見ると」
- 曖昧副詞: 「正しく」「適切に」「きちんと」「しっかりと」「十分に」「効果的に」（具体性ゼロで情報量なし）
- 包括語の乱用: 「など」「等」「〜といった」「〜のような」
- 冗長つなぎ: 「上記の通り」「前述の通り」「以下の通りです」（直後に内容が続くので不要）
- 曖昧代名詞: 「これにより」「このように」「そのため」（主語を省略した因果）

**構造系**:
- 過剰な箇条書き（3 項目で済むのに 8 項目並べる、文章で済む内容を箇条書きにする）
- 無意味な前置き（「この記事では…について解説します」が導入で被る等）
- 冒頭の「結論」箇条書きと本文の重複
- 各見出しごとの「まとめ」ミニ段落（本文と情報重複）

severity 基準:
- high: 記事全体の信頼感を損ねる（冒頭 / 結論 / 複数箇所で同パターン）
- medium: 読みづらさはあるが部分的
- low: 単発の表現ゆれ

出力: `facets/policies/council-output-schema.md` の JSON schema に従う 1 つの JSON オブジェクト。`reviewer: "anti-ai-slop"`、`category: "ai-slop"`。各 finding には `confidence` (0-100) と `severity` 必須。前置き・後書き・コードフェンス禁止。
```

#### reviewer-B: fact-checker

```
あなたは技術事実検証担当です。

対象記事: $ARTICLE_PATH

以下を検証してください:
- API 名・version 番号・コマンド構文
- 製品名・機能名（Claude Code / Anthropic / 外部 SaaS 等）
- 引用した仕様・動作挙動
- URL（リンク切れ・誤記）

必要に応じて WebFetch / WebSearch で公式ドキュメントと照合。確信が持てない主張にも severity: medium で「要検証」として指摘。

severity 基準:
- high: 明らかな事実誤認（存在しない API、誤った version、壊れたコマンド）
- medium: 出典なし主張 / 古い情報の可能性
- low: 表記ゆれ（"Claude code" vs "Claude Code" 等）

quote-first: 各 finding の `quotes` 配列に記事本文から問題箇所を 30 文字程度で抽出。どの記述に対する指摘か明示すること（fact-checker は長文 Read するため必須）。

coverage-first: 検出した issue は confidence + severity を付けて全件返す。「low は省略」のような閾値カットは行わない（集約側で扱う）。

出力: `facets/policies/council-output-schema.md` の JSON schema に従う 1 つの JSON オブジェクト。`reviewer: "fact-checker"`、`category: "fact"`。各 finding に `confidence` (0-100), `severity`, `quotes` 必須。前置き・後書き・コードフェンス禁止。
```

#### reviewer-C: narrative-critic

```
あなたは物語構造を見るエディターです。

対象記事: $ARTICLE_PATH
対象読者: $READER_PROFILE

以下を指摘してください:
- 導入から結論への論理の糸が途切れている箇所
- weak transitions（段落間の接続が唐突）
- buried leads（重要な結論が本文中段以降に埋もれている）
- セクション構成の不均衡（前半詳細すぎ / 後半駆け足等）

severity 基準:
- high: 読者が途中で迷子になる構造破綻
- medium: 流れが重い・冗長
- low: 小さな接続詞の置き換えで済む

出力: `facets/policies/council-output-schema.md` の JSON schema に従う 1 つの JSON オブジェクト。`reviewer: "narrative-critic"`、`category: "narrative"`。各 finding に `confidence` (0-100) と `severity` 必須。前置き・後書き・コードフェンス禁止。
```

#### reviewer-D: reader-advocate

```
あなたは対象読者の代弁者です。

対象記事: $ARTICLE_PATH
対象読者: $READER_PROFILE

以下を指摘してください:
- 対象読者が知らない前提で使われている jargon / 略語 / 内輪ネタ
- 専門用語の初出で定義がない箇所
- 「なぜ重要か」「何がうれしいか」が語られる前に How に入ってしまう箇所
- コード例の説明不足（何が起きるか / どう使うか）

severity 基準:
- high: その用語・前提がないと読者は先に進めない
- medium: 理解はできるが不親切
- low: 親切なら追加したい

出力: `facets/policies/council-output-schema.md` の JSON schema に従う 1 つの JSON オブジェクト。`reviewer: "reader-advocate"`、`category: "reader-fit"`。各 finding に `confidence` (0-100) と `severity` 必須。前置き・後書き・コードフェンス禁止。
```

### 並列 spawn

4 エージェントを **1 メッセージ内で同時** spawn。Agent tool の `subagent_type: general-purpose` でよい。各 agent の output (Council JSON schema 準拠の 1 オブジェクト) は `.editorial/round-N/reviewer-X.json` に保存する。

## Step 3: Findings 集約（Council JSON schema 入力）

各 reviewer の JSON を読み込み、`schema_version == "1"` を確認した上で `findings[]` 配列を flatten し、**統合テーブル** を作成:

| # | reviewer | category | line | severity | confidence | issue | fix | quotes |
|---|----------|----------|------|----------|-----------|-------|-----|--------|
| 1 | anti-ai-slop | ai-slop | 12-15 | high | 88 | ... | ... | ... |

**衝突検出**: 同じ `line_range` を複数 reviewer が指摘している場合は「conflict」フラグを立てる（自動 apply しない）。

集約結果を `.editorial/round-N/findings.md` に保存する（`good_points` と `memo` も併記）。

#### schema 違反時のフォールバック

reviewer が schema 違反の出力を返した場合は、JSON パースを再実行依頼（最大 1 回）。それでも失敗なら **その reviewer のラウンドはスキップ** し、`.editorial/round-N/skipped.md` に `[NOTE] schema 違反: <reviewer>` を記録。他 reviewer 分の findings はそのまま処理する（1 reviewer 失敗で全体停止しない）。

## Step 4: Low severity を自動 apply（confidence 重み付け）

Step 1 で「自動 apply: low + 非競合のみ」が選ばれた場合:

1. `severity == "low"` かつ `conflict` フラグなしの findings を抽出
2. **`confidence >= 70` のもののみ自動 apply** 対象（confidence 低い low はノイズの可能性が高いので保留）
3. Edit ツールで順次 apply（`line_range` の大きいほうから apply して位置ずれを回避）
4. apply できなかったもの・confidence 不足で保留したものは `.editorial/round-N/skipped.md` に記録

## Step 5: Medium/High + 保留 low を AskUserQuestion で一括承認

以下を AskUserQuestion で提示:

- `severity in ("medium", "high")` の findings
- conflict ありの findings
- Step 4 で保留された low (confidence < 70)

1 件ずつではなく **一度に最大 20 件を checkboxes で** 提示（API 制約に応じて分割）。各選択肢には `[severity/confidence] reviewer: issue` の形で表示し、ユーザーが優先度判断しやすくする。

ユーザーが承認したものだけ Edit で apply。却下したものは `.editorial/round-N/rejected.md` に理由ごと記録（次ラウンドで重複提案を回避する材料）。

## Step 6: diff 保存 + 収束判定

```bash
# 現在の記事と originals の diff を保存
jj diff "$ARTICLE_PATH" > .editorial/round-N/applied.diff 2>/dev/null || \
  git diff "$ARTICLE_PATH" > .editorial/round-N/applied.diff 2>/dev/null
```

**収束判定**:
- 全 high finding が apply または却下されている → **クローズ**
- high が残っている かつ round < MAX_ROUNDS → **Step 2 に戻る**（再レビュー）
- MAX_ROUNDS に到達 → **クローズ（残 issue をサマリで明示）**

再ラウンド時は rejected.md を各 reviewer の prompt に「これは既に却下された提案なので重複して出さない」として渡す。

## Step 7: 最終サマリ

```markdown
## Editorial Swarm 結果（N ラウンド）

### 確定 apply
- [R1] anti-ai-slop: 〜 (line 12-15)
- [R1] fact-checker: 〜 (line 80)

### ユーザー却下
- [R1] narrative-critic: 〜 (理由: 意図的な構成)

### 未解決（MAX_ROUNDS 到達）
- [R3] fact-checker: 〜（要手動検証）

### 成果物
- 記事: $ARTICLE_PATH
- 各ラウンドの diff: .editorial/round-*/applied.diff
- findings 履歴: .editorial/round-*/findings.md
```

`.editorial/summary.md` としても書き出す。

## Gotchas

- **個別 reviewer prompt を肥大化させない**: 4 並列で context を食い合うので、各 prompt は 30 行以内に抑える。詳しい基準は本文の template に集約
- **自動 apply を widen しない**: severity=low 以外を自動適用すると意図しない書き換えが起きる。ユーザーが明示的に widen 指示したときのみ
- **WebFetch の並列度**: fact-checker が多数 URL を触ると遅くなる。prompt で「確信できない 5 件以内に絞って検証」と制限する
- **Zenn の front matter（title / emoji / tags）は触らない**: line 1-10 あたりは reviewer から除外対象と明記する
- **記事全体書き換えが必要な指摘が出たら収束させない**: editorial-swarm は「推敲」が責務。構造書き換えは手で戻して再度呼ぶ
- **conflict 処理**: 同一行に複数 reviewer の異なる fix が来たら AskUserQuestion で必ず人間判断。自動マージ禁止
- **schema 違反 reviewer のスキップ**: Council JSON schema 違反 (旧形式の配列直返し / 前置き混入) は再実行 1 回 → それでも違反ならその reviewer をラウンドからスキップ。1 reviewer 失敗で全体停止しない

---

**Step 1 の前提確認から開始してください。**
