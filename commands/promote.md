---
description: "learned/に蓄積された学びを分析し再利用可能なエージェント・コマンド・ルールに昇格。「スキルにして」「ルール化して」で使用。"
argument-hint: "[対象パターン名 or キーワード]"
allowed-tools: [Read, Write, Edit, Glob, Grep, ToolSearch, AskUserQuestion, Task]
model: sonnet
---

# /o-m-cc:promote - 学びのスキル昇格

**`spec/standards/learned/` に蓄積された学びを分析し、再利用可能なスキルに昇格させる。**

---

## Step 1: 昇格候補の特定

### 引数ありの場合

`$ARGUMENTS` をキーワードとして `spec/standards/learned/` を検索し、該当エントリを抽出。

**hook 連携（自動検出エントリの優先処理）:**
- `review-discovered` タグを含むエントリを優先的に表示
- 同一タグが複数エントリに出現する場合、その出現回数を「繰り返し回数」として表示
- claude-mem が利用可能な場合、同一パターンのクロスプロジェクト出現も検索して昇格根拠を強化

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

#### ソース 2: learned/ からの検出

`spec/standards/learned/` 全体をスキャンして候補を検出：

```
以下の基準で候補を抽出：

1. 頻出パターン — 同じタグが複数エントリに出現
2. 高影響 — 影響範囲が広い決定やアンチパターン
3. 汎用性 — プロジェクト固有でなく他でも使えるもの
```

#### 統合

claude-mem 結果 + learned/ 結果を統合して昇格候補リストを作成。

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

対象エントリの全文を Read で取得。関連する他のエントリも含めて収集。

```
収集する情報：
- 元のエントリ内容（パターン / アンチパターン / 決定）
- 関連するタグで紐づく他のエントリ
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
- spec/standards/learned/[source].md の [エントリ名]

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
- spec/standards/learned/[source].md の [エントリ名]

[コマンドの手順]
```

### ルールの場合

`templates/rules/[name].md` を作成し、init 時に `spec/rules/` へコピーされるようにする：

```markdown
# [ルール名]

## 背景

この規則は以下の学びから昇格：
- spec/standards/learned/[source].md の [エントリ名]

## ルール

[具体的な行動規範]

## 違反例

[やってはいけない例]

## 準拠例

[正しい例]
```

---

## Step 5: 元エントリに昇格マークを追加

元の学びエントリに昇格済みであることを記録：

```markdown
## [YYYY-MM-DD] パターン名

> ✅ **昇格済み** → agents/[name].md (YYYY-MM-DD)

**発見場所**: ...
```

Edit tool で該当エントリのタイトル直下に昇格マークを挿入。

---

## Step 6: 確認出力

```
✅ スキル昇格完了

📦 生成: [agents/commands/templates/rules]/[name].md
📝 元の学び: spec/standards/learned/[source].md
🏷️ 種類: [エージェント / コマンド / ルール]

💡 元のエントリに昇格済みマークを追加しました。
```

---

**Step 1 から開始してください。**
