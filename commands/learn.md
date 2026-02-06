---
description: "レビュー・バグ修正・実装で得た学びをspec/standards/learned/に記録。「これ覚えて」「パターンを記録して」で使用。"
argument-hint: "[学びの概要]"
allowed-tools: [Read, Write, Edit, Glob, Grep, AskUserQuestion]
model: sonnet
---

# /o-m-cc:learn - 学びの記録

**レビュー・バグ修正・実装で得た学びを `spec/standards/learned/` に構造化記録する。**

引数がある場合はそれを学びの概要として使用。ない場合は会話コンテキストから抽出。

---

## Step 1: 学びの種類を判定

**AskUserQuestion** で種類を確認：

```
質問: どの種類の学びですか？
header: "Type"
multiSelect: false

選択肢:
1. パターン - 発見した良いパターン・規約
2. アンチパターン - 避けるべきパターン・落とし穴
3. 技術的決定 - 採用した技術・アーキテクチャの決定とその理由
```

---

## Step 2: 学びの内容を整理

引数 `$ARGUMENTS` または会話コンテキストから以下を抽出：

- **何を学んだか**（概要）
- **どこで発見したか**（ファイルパス、コンポーネント）
- **なぜそうすべきか / すべきでないか**（理由）

情報が不足している場合は **AskUserQuestion** で補完：

```
質問: もう少し詳しく教えてください
header: "Detail"
multiSelect: false

選択肢:
1. 具体的なコード箇所を指定する
2. 理由・背景を補足する
3. このまま記録する（十分な情報がある）
```

---

## Step 3: learned/ ディレクトリの確認

```bash
# spec/standards/learned/ が存在するか確認
ls spec/standards/learned/
```

存在しない場合は作成：

```bash
mkdir -p spec/standards/learned
cp "${CLAUDE_PLUGIN_ROOT}/templates/standards/learned/README.md" spec/standards/learned/
cp "${CLAUDE_PLUGIN_ROOT}/templates/standards/learned/patterns.md" spec/standards/learned/
cp "${CLAUDE_PLUGIN_ROOT}/templates/standards/learned/decisions.md" spec/standards/learned/
cp "${CLAUDE_PLUGIN_ROOT}/templates/standards/learned/antipatterns.md" spec/standards/learned/
```

---

## Step 4: 記録を追記

種類に応じた対象ファイルに **Edit tool** で追記する。

### パターンの場合 → `spec/standards/learned/patterns.md`

追記フォーマット：

```markdown
## [YYYY-MM-DD] パターン名

**発見場所**: `src/path/to/file.ts`
**内容**: [パターンの説明]
**理由**: [なぜこのパターンが有効か]
**タグ**: [検索用キーワード、カンマ区切り]
```

### アンチパターンの場合 → `spec/standards/learned/antipatterns.md`

追記フォーマット：

```markdown
## [YYYY-MM-DD] アンチパターン名

**パターン**: [避けるべき実装方法]
**問題**: [何が起きるか]
**代替案**: [代わりにどうすべきか]
**発見場所**: `src/path/to/file.ts:行番号`
**タグ**: [検索用キーワード、カンマ区切り]
```

### 技術的決定の場合 → `spec/standards/learned/decisions.md`

追記フォーマット：

```markdown
## [YYYY-MM-DD] 決定事項

**決定**: [何を決めたか]
**理由**: [なぜその選択をしたか]
**却下した代替案**: [検討したが採用しなかったもの]
**影響範囲**: [どのモジュール・ファイルに影響するか]
**タグ**: [検索用キーワード、カンマ区切り]
```

---

## Step 5: 確認出力

```
✅ 学びを記録しました

📝 種類: [パターン / アンチパターン / 技術的決定]
📄 ファイル: spec/standards/learned/[対象ファイル].md
🏷️ タグ: [タグ一覧]

💡 この学びは次回 /o-m-cc:plan 実行時に
   learnings-researcher がセマンティック検索します。
   普段の操作は claude-mem が自動記録しています。
```

---

**Step 1 から開始してください。**
