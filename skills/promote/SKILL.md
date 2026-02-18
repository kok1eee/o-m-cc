---
name: promote
description: "HANDOVER.md の履歴から繰り返すパターンを発見し、再利用可能なスキルに昇格。「スキルにして」「ルール化して」で使用。"
argument-hint: "[対象パターン名 or キーワード]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, ToolSearch, AskUserQuestion, Task]
model: sonnet
disable-model-invocation: true
---

# /o-m-cc:promote - 学びのスキル昇格

**HANDOVER.md の VCS 履歴を横断検索し、繰り返すパターンを発見して再利用可能なスキルに昇格させる。**

---

## Step 1: 昇格候補の特定

### 引数ありの場合

`$ARGUMENTS` をキーワードとして HANDOVER.md の VCS 履歴を検索し、該当セッションを抽出。

```bash
# jj が使える場合
jj log -p -- plan/HANDOVER.md | grep -i "$ARGUMENTS" -A 10 -B 5

# git の場合
git log -p -- plan/HANDOVER.md | grep -i "$ARGUMENTS" -A 10 -B 5
```

### 引数なしの場合

2つのソースから昇格候補を自動検出する：

#### ソース1: クロスプロジェクト候補（`~/.claude/skill-candidates.md`）

```bash
# グローバルに蓄積されたスキル候補を読む
cat ~/.claude/skill-candidates.md
```

`promote-checker` hook が各プロジェクトで検出した繰り返しパターンが蓄積されている。
**別プロジェクトでも同じパターンが出現していれば、昇格の優先度が高い。**

#### ソース2: ローカル候補（HANDOVER.md VCS 履歴）

```bash
# jj が使える場合
jj log -p -- plan/HANDOVER.md

# git の場合
git log -p -- plan/HANDOVER.md
```

現プロジェクトの HANDOVER.md VCS 履歴から、繰り返しパターンを検索。

#### 候補の統合

両ソースを統合し、以下の基準で候補を抽出：

```
1. クロスプロジェクト頻出 — 複数プロジェクトで同じパターンが出現（最優先）
2. 頻出パターン — 同一プロジェクト内で複数セッションにわたり繰り返し登場
3. 高影響 — 「うまくいかなかったこと」に複数回登場する同種の問題
4. 汎用性 — プロジェクト固有でなく他でも使えるもの
```

**AskUserQuestion** で候補を提示：

```
質問: どの学びをスキルに昇格させますか？
header: "Promote"
multiSelect: false

選択肢:
1. [候補1の名前] - [概要]（🌐 クロスプロジェクト or 📁 ローカル）
2. [候補2の名前] - [概要]（🌐 クロスプロジェクト or 📁 ローカル）
3. [候補3の名前] - [概要]（🌐 クロスプロジェクト or 📁 ローカル）
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
1. エージェント — 特定タスクを実行する専門エージェント（プラグインレベル）
2. スキル — ユーザーが呼び出すスラッシュコマンド（プラグインレベル）
3. プロジェクトルール — CLAUDE.md に追記する行動規範（プロジェクトレベル）
4. グローバルルール — ~/.claude/CLAUDE.md に追記する行動規範（全プロジェクト共通）
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

### スキルの場合

`skills/[name]/SKILL.md` を作成：

```markdown
---
name: "[スキル名]"
description: "[学びから抽出した説明]"
argument-hint: "[引数]"
allowed-tools: [必要なツール]
model: sonnet
---

# /o-m-cc:[name]

## 背景

この機能は以下の学びから昇格：
- HANDOVER.md の [日付] セッション

[スキルの手順]
```

### プロジェクトルールの場合

プロジェクトの CLAUDE.md に行動規範セクションを追記する：

```markdown
## [ルール名]

> この規則は HANDOVER.md の [日付] セッションの学びから昇格

- [具体的な行動規範]
- [違反例と準拠例]
```

**Edit** ツールで CLAUDE.md の適切な位置に追記する。

### グローバルルールの場合

`~/.claude/CLAUDE.md` に行動規範セクションを追記する：

```markdown
## [ルール名]

> この規則は [プロジェクト名] の HANDOVER.md 履歴の学びから昇格

- [具体的な行動規範]
- [違反例と準拠例]
```

**Edit** ツールで `~/.claude/CLAUDE.md` の適切な位置に追記する。
全プロジェクトで適用されるため、**プロジェクト固有でない汎用的なルールのみ**をここに昇格させる。

---

## Step 5: 確認出力

```
✅ スキル昇格完了

📦 生成: [agents/skills]/[name] または CLAUDE.md / ~/.claude/CLAUDE.md に追記
📝 元の学び: HANDOVER.md の [日付] セッション
🏷️ 種類: [エージェント / スキル / プロジェクトルール / グローバルルール]
```

---

**Step 1 から開始してください。**
