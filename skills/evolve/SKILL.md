---
name: evolve
description: "スキルの自己進化。auto-memory と実行履歴から学びを抽出し、各スキルの Gotchas セクションに自動追記する。セッション終了前、定期的な改善サイクル、問題に遭遇した後に使う。「スキルを進化させて」「学びを反映して」「Gotchas を更新」「evolve」で発動。"
argument-hint: "[skill name or 'all']"
allowed-tools: [Read, Edit, Glob, Grep, Bash]
effort: medium
---

# Evolve - スキル自己進化

auto-memory + skill-usage.log から学びを抽出し、スキルの Gotchas を更新する。

## 対象

$ARGUMENTS（省略時は最近使われたスキル全て）

## 実行フロー

### Step 1: 情報収集

1. **skill-usage.log** を Read して最近使われたスキルを特定
2. **auto-memory**（`.claude/memory/`）を Read して、スキル実行に関する学び・失敗・注意点を抽出
3. **agent-memory**（`.claude/agent-memory/`）からエージェント固有の学びを抽出

```bash
# 最近使われたスキル
cat "${CLAUDE_PLUGIN_DATA}/skill-usage.log" | tail -20
```

### Step 2: 既存 Gotchas との照合

対象スキルの SKILL.md を Read し、Gotchas セクションを確認。

- 既に記載されている内容と重複する学びは除外
- 新しい学びのみを候補にする

### Step 3: Gotchas 追記

`<!-- AUTO-GOTCHAS -->` マーカーの後に追記する。マーカーがなければ Gotchas セクション末尾に追加する。

#### フォーマット

```markdown
<!-- AUTO-GOTCHAS -->
<!-- 以下は実行経験から自動追記。不要なら削除してよい -->
- **[日付] 問題の要約**: 具体的な状況と回避方法
```

#### ルール

- **追記のみ**。既存の Gotchas（マーカーより上）は絶対に編集しない
- 1スキルあたり最大5件の AUTO-GOTCHAS を保持。超過時は古いものから削除
- 曖昧な学び（「うまくいかないことがある」等）は追記しない。具体的な状況 + 回避方法がセットで必要
- SKILL.md の Gotchas セクション以外は一切触らない

### Step 4: 報告

```markdown
## Evolve 結果

### 更新したスキル
- skill-name: +N件の Gotchas 追加
  - [要約1]
  - [要約2]

### スキップしたスキル
- skill-name: 新しい学びなし

### スキップした学び
- [具体性が不足していた学び]
```

## Gotchas

- **手順部分を書き換えてしまう**: Gotchas セクション以外は絶対に Edit しない。`<!-- AUTO-GOTCHAS -->` マーカーを目印にする
- **曖昧な Gotchas を追記して価値が下がる**: 「状況 + 回避方法」のペアがないものは追記しない
- **重複追記**: Step 2 の照合を必ず行い、既存と同じ内容は追記しない

---

**Step 1 の情報収集から開始してください。**
