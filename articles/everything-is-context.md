---
title: "Claude Codeを3ヶ月使って踏んだ坑に、全部名前がついていた — 論文 'Everything is Context' との対応"
emoji: "🧠"
type: "idea"
topics: ["ClaudeCode", "AI", "LLM", "エージェント", "プロンプトエンジニアリング"]
published: false
---

## はじめに

Claude Code を3ヶ月使い続けて、ディレクトリは増え続けた。

`rules/`、`docs/`、`memory/`、`skills/`、`facets/` — 各種分層を重ねて、13のエージェントと hooks による自動化を持つプラグイン [o-m-cc](https://github.com/kok1eee/o-m-cc) を作った。動いてはいる。でも「自分が何を作っているのか」をうまく説明できなかった。

そんなとき ["Everything is Context"（arXiv:2512.05470）](https://arxiv.org/abs/2512.05470) という論文を読んだ。

自分のフォルダ構造が、学術用語に翻訳された。

## 対応表：踏んだ坑と論文の名前

| 論文の概念 | 説明 | o-m-cc での実装 |
|-----------|------|----------------|
| **Scratchpad** | 一時作業区。現在のタスクの中間状態 | `.claude/context.md`, `plan/` |
| **Fact Memory** | プロジェクト固有の事実記憶 | `MEMORY.md`, `.claude/agent-memory/` |
| **Experiential Memory** | 複数プロジェクトを横断する経験知 | `facets/references/`, auto-memory |
| **Context Constructor** | トークン予算内でコンテキストを選択的にロード | Progressive Disclosure（3層構造） |
| **Bounded Reasoning** | 有限なコンテキスト窓での戦略的な取捨選択 | `rules/` 自動ロード vs `docs/` 按需ロードの分離 |
| **Context Evaluator** | ロードしたコンテキストの妥当性を検証 | hooks（stop-guard, auto-verify, memory-digest） |

全部、先に実装があって、後から名前を知った。

## 一番痛かった坑：トークン爆発

最初は `rules/` に全情報を詰め込んでいた。エージェント定義も、レビュー基準も、セキュリティチェックリストも。

結果、コンテキストが爆発した。エージェントは肝心の指示を読み落とし、的外れな回答を返す。

対策として**3層に分離**した：

```
Layer 1: frontmatter（常時ロード）    → ~60 tokens/agent
Layer 2: 本文（エージェント起動時）     → ~100-200 tokens/agent
Layer 3: facets/references/（必要時に Read） → ~200-500 tokens/file
```

全情報を常時ロードする場合と比べて、通常時のトークン消費が約 1/3 になった。

論文はこれを **Context Constructor** と呼んでいる。「トークン予算という有限リソースの中で、タスクの優先度に基づいてコンテキストを動的に配分する仕組み」。

自分が解いていた問題は **Bounded Reasoning Capacity** — 有限な推論容量の中での戦略的取捨選択 — だった。

## もう一つの発見：Context Evaluator

論文との対応表を作ったとき、一つだけ「隙間」が見えた。

o-m-cc は**出力の検証**（stop-guard がタスク完了を検証、auto-verify がテスト通過を確認）はしていたが、**入力コンテキストの鮮度チェック**はしていなかった。

例えば `MEMORY.md` に「`hooks/old-script.sh` のパターンは〜」と書いてあっても、そのファイルがもう削除されていたら？古い前提で作業を始めてしまう。

論文の **Context Evaluator** — ロードしたコンテキストが本当に有効か検証する仕組み — が欠けていた。

対応として、既存の `memory-digest.sh`（SessionStart hook）に20行追加した：

```bash
# MEMORY.md 内のファイルパス参照の実在チェック
while IFS= read -r ref_path; do
  if [[ ! -e "${CWD}/${ref_path}" ]]; then
    STALE_REFS+=("$ref_path")
  fi
done < <(grep -oE '`[a-zA-Z0-9_./-]+\.(md|sh|py|json|yaml|yml|toml|ts|js|txt)`' \
  "$PROJECT_MEMORY_FILE" 2>/dev/null | tr -d '`' | sort -u)
```

セッション開始時に「MEMORY.md が言及しているファイルが存在するか」を確認し、なければ警告する。修正はユーザーか auto-memory に委ねる。

初回実行で即座に検知した：

```
🔍 MEMORY.md 古い参照（ファイルが存在しません）
   - plugin.json
   → 該当する記述を確認・更新してください
```

`plugin.json` の正確なパスは `.claude-plugin/plugin.json` だが、MEMORY.md では短縮形で書かれていた。実問題の検知。

素朴な実装だが、設計原則（Lightweight: Markdown + Shell のみ）の範囲でできる最大限だと思っている。

## 実践在前、命名在後

論文を先に読んでいたら、こうはならなかった。

「Context Constructor を実装しよう」と思って作ったのではなく、「トークンが爆発して困ったから分離した」結果が Context Constructor だった。「Bounded Reasoning を考慮しよう」と思ったのではなく、「エージェントが指示を読み落とすから自動ロードを減らした」結果が Bounded Reasoning への対処だった。

痛みから始めて、実験で形にして、論文で名前を知る。この順序だからこそ、概念が腹落ちする。

逆に言えば、論文の価値は「新しい概念を教えてくれる」ことではなく、「自分が暗黙的にやっていたことを言語化してくれる」ことにある。言語化されると、次にやるべきこと（Context Evaluator の隙間）も見えてくる。

## まとめ

Claude Code のようなエージェントシステムを構築していると、いずれ同じ問題にぶつかる：

1. **コンテキストが爆発する** → 分離と段階的開示（Context Constructor）
2. **全部は入らないと悟る** → 優先度ベースの取捨選択（Bounded Reasoning）
3. **古い情報で動いてしまう** → 入力コンテキストの鮮度チェック（Context Evaluator）

これは LLM の token window という物理的制約から必然的に導かれる問題で、誰がやっても似た解に収束する。論文 ["Everything is Context"](https://arxiv.org/abs/2512.05470) はその収束先に名前をつけてくれた。

先に踏んだ坑に名前がつく快感は格別だ。
