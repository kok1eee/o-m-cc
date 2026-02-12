---
description: "HANDOVER.md の履歴から繰り返すパターンを発見し、再利用可能なスキルに昇格。「スキルにして」「ルール化して」で使用。"
argument-hint: "[対象パターン名 or キーワード]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, ToolSearch, AskUserQuestion, Task]
model: sonnet
---

# /o-m-cc:promote - 学びのスキル昇格

**HANDOVER.md の VCS 履歴を横断検索し、繰り返すパターンを発見して再利用可能なスキルに昇格させる。**

---

## Step 1: 昇格候補の特定

### 引数ありの場合

`$ARGUMENTS` をキーワードとして HANDOVER.md の VCS 履歴を検索し、該当セッションを抽出。

```bash
# jj が使える場合
jj log -p -- spec/plan/HANDOVER.md | grep -i "$ARGUMENTS" -A 10 -B 5

# git の場合
git log -p -- spec/plan/HANDOVER.md | grep -i "$ARGUMENTS" -A 10 -B 5
```

### 引数なしの場合

2つのソースから昇格候補を自動検出：

#### ソース 1: claude-mem からの発掘

ToolSearch で claude-mem MCP ツールの可用性を確認。利用可能な場合：

```
以下のクエリで検索：
- search(query="繰り返し行っている操作パターン")
- search(query="複数プロジェクトで同じ修正")
- search(query="毎回行う設定やセットアップ")

クロスプロジェクトで頻出するパターンを候補として抽出。
```

#### ソース 2: HANDOVER.md VCS 履歴からの検出

HANDOVER.md の全コミット履歴を取得して分析：

```bash
# jj が使える場合
jj log -p -- spec/plan/HANDOVER.md

# git の場合
git log -p -- spec/plan/HANDOVER.md
```

以下の基準で候補を抽出：

```
1. 頻出パターン — 複数セッションで同じ教訓・Gotchas が繰り返し登場
2. 高影響 — 「うまくいかなかったこと」に複数回登場する同種の問題
3. 汎用性 — プロジェクト固有でなく他でも使えるもの
```

#### 統合

claude-mem 結果 + HANDOVER.md 履歴結果を統合して昇格候補リストを作成。

**AskUserQuestion** で候補を提示：

```
質問: どの学びをスキルに昇格させますか？
header: "Promote"
multiSelect: false

選択肢:
1. [候補1の名前] - [概要]
2. [候補2の名前] - [概要]
3. [候補3の名前] - [概要]
4. 手動で指定する
```

---

## Step 2: 元の学びを読み込み

対象セッションの HANDOVER.md 内容を VCS 履歴から抽出。関連する他セッションの記載も収集。

```
収集する情報：
- HANDOVER.md の該当セッションの全内容（教訓、Gotchas、意思決定）
- 同種のパターンが出現する他セッションの記載
- 発見場所のコード（存在すれば）
```

---

## Step 3: スキルの方向性を確認

**AskUserQuestion** でスキルの形式を確認：

```
質問: どのようなスキルにしますか？
header: "Skill type"
multiSelect: false

選択肢:
1. エージェント — 特定タスクを実行する専門エージェント
2. コマンド — ユーザーが呼び出すスラッシュコマンド
3. ルール — spec/rules/ に配置する行動規範
```

---

## Step 4: スキル生成

選択に応じてファイルを生成。

### エージェントの場合

`agents/[name].md` を作成：

```markdown
---
name: [スキル名]
description: [学びから抽出した説明]
tools: [必要なツール]
model: haiku
---

# [スキル名]

## 背景

この知見は以下の学びから昇格：
- HANDOVER.md の [日付] セッション

## 役割

[学びを一般化したガイダンス]

## 手順

[具体的な実行手順]
```

### コマンドの場合

`commands/[name].md` を作成：

```markdown
---
description: "[学びから抽出した説明]"
argument-hint: "[引数]"
allowed-tools: [必要なツール]
model: sonnet
---

# /o-m-cc:[name]

## 背景

この機能は以下の学びから昇格：
- HANDOVER.md の [日付] セッション

[コマンドの手順]
```

### ルールの場合

`templates/rules/[name].md` を作成し、init 時に `spec/rules/` へコピーされるようにする：

```markdown
# [ルール名]

## 背景

この規則は以下の学びから昇格：
- HANDOVER.md の [日付] セッション

## ルール

[具体的な行動規範]

## 違反例

[やってはいけない例]

## 準拠例

[正しい例]
```

---

## Step 5: 確認出力

```
✅ スキル昇格完了

📦 生成: [agents/commands/templates/rules]/[name].md
📝 元の学び: HANDOVER.md の [日付] セッション
🏷️ 種類: [エージェント / コマンド / ルール]
```

---

**Step 1 から開始してください。**
