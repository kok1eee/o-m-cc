---
name: evolve
description: "スキルの自己進化。auto-memory と実行履歴から学びを抽出し、各スキルの Gotchas セクションに自動追記する。セッション終了前、定期的な改善サイクル、問題に遭遇した後に使う。「スキルを進化させて」「学びを反映して」「Gotchas を更新」「evolve」で発動。"
argument-hint: "[skill name or 'all']"
allowed-tools: [Read, Edit, Glob, Grep, Bash]
effort: medium
---

# Evolve - スキル自己進化

auto-memory + skill-usage.csv から学びを抽出し、スキルの Gotchas を更新する。

## 対象

$ARGUMENTS（省略時は最近使われたスキル全て）

## 実行フロー

### Step 1: 情報収集

1. **skill-usage.csv** を Read して最近使われたスキルを特定
2. **auto-memory**（`.claude/memory/`）を Read して、スキル実行に関する学び・失敗・注意点を抽出
3. **agent-memory**（`.claude/agent-memory/`）からエージェント固有の学びを抽出

```bash
# 最近使われたスキル（CSV: timestamp,skill。header行をスキップ）
tail -n +2 "${CLAUDE_PLUGIN_DATA}/skill-usage.csv" | tail -20 | awk -F, '{print $1, $2}'
```

### Step 2: 既存 Gotchas との照合

対象スキルの SKILL.md を Read し、Gotchas セクションを確認。

- 既に記載されている内容と重複する学びは除外
- 新しい学びのみを候補にする

### Step 2.5: Quality Gate（追記前に必ず照合）

Gotchas として追記する前に、**以下の3つの質問すべてに YES か検証**（oh-my-claudecode の `/learner` にインスパイア）:

1. **「Google で5分以内に見つけられない？」** → YES（= Googleable なら却下）
2. **「この codebase / skill 固有の話？」** → YES（= 普遍的パターンなら却下）
3. **「実際にデバッグや試行錯誤で発見したもの？」** → YES（= 推測・想像なら却下）

#### 価値ある Gotchas の4条件

| 条件 | OK | NG |
|---|---|---|
| **Non-Googleable** | "o-m-cc の TeamCreate で name 未指定だと SendMessage が silent loss" | "Bash で set -e を使う" |
| **Context-Specific** | "sisyphus Step 5 で verification auto-trigger しない問題" | "エージェントの使い方" |
| **Actionable with Precision** | "`hooks/subagent-verify.sh` の exit 2 は 2.1.105+ で subagent を停止させる（非ブロッキングは exit 0）" | "hook を気をつけて使う" |
| **Hard-Won** | 「実際に壊して原因を突き止めた学び」 | 「マニュアルに書いてあること」 |

#### Anti-Patterns（絶対に追記しない）

- ❌ Generic programming patterns（言語やフレームワーク一般の話）
- ❌ Refactoring techniques（汎用技術）
- ❌ Library 使用例（ドキュメント参照で十分）
- ❌ Type 定義や boilerplate
- ❌ ジュニアが5分で Google できる内容

#### Core Principle

**再利用可能な Gotchas は「コードスニペット」ではなく「考え方のヒューリスティック」**。

- ❌ 悪い例（mimicking）: "ConnectionResetError を見たらこの try/except を追加"
- ✅ 良い例（reusable）: "async ネットワークコードでは I/O 操作は client/server ライフサイクルのズレで独立に失敗する。各 I/O を個別に wrap する"

### Step 2.6: Gotcha vs Atom 分類（escalation 判定）

Quality Gate を通った学びの行き先を判定する。詳細は `facets/policies/agent-memory-guidance.md` の「Gotcha vs Atom 分類」セクションを参照。

| 学びの種類 | 行き先 | 例 |
|---|---|---|
| **行動修正系**（現存 skill / agent を動かす時の再発防止メモ） | Step 3 へ進み Gotchas に追記 | SendMessage name 未指定で silent loss |
| **改善案系**（skill / agent を変える、試す、新規追加するアイデア） | **atom に escalate** → Step 3 をスキップ | discovery-council 5 並列実験 / editorial prompt XML 化 |

#### Atom escalation の手順

改善案系と判定したら以下を実行:

```bash
bin/atoms add "evolve" "<学びの内容（1 行で）>" "<次アクション（promote / 試行 / 議論など）>"
```

その学びは Step 3 の Gotchas には書かない（atom と Gotchas に二重登録すると着手判断がぶれる）。Step 5 の報告では `### atom escalate` セクションに分類し、`A00X` の id を含めて明示する。

#### 判定に迷う場合

1. 「明日 skill を呼び出すユーザーがこの注意を読んで動作を修正できるか？」→ YES なら gotcha
2. 「これは『そのうちやる』タスクとして backlog 管理すべきか？」→ YES なら atom
3. 両方該当する稀なケースは gotcha 優先（再発防止が即効性高い）+ atom にも残す（着手判断のため）

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

### Step 4: 完了マーカー

PreCompact hook のループ防止用。evolve 完了を記録する。

```bash
mkdir -p .claude && touch .claude/evolve-done
```

### Step 5: 報告

```markdown
## Evolve 結果

### 更新したスキル
- skill-name: +N件の Gotchas 追加
  - [要約1]
  - [要約2]

### atom escalate（atoms.csv に追加）
- A00X: [改善案の要約] (next: [次アクション])

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
