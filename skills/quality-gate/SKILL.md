---
name: quality-gate
description: "/simplify → Review Council → 静的解析(ruff/ty/shellcheck) を連続実行してコード品質を最終確認。「品質チェックして」「品質ゲート通して」で使用。"
argument-hint: "[specific files or 'all']"
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion, TeammateTool, Skill]
model: sonnet
context: fork
---

# Quality Gate - /simplify + Review Council + Lint 連続実行

コード変更に対して `/simplify`（自動修正）→ Review Council（並列レビュー）→ 静的解析（最終チェック）を連続実行し、品質を最終確認します。

## 対象

$ARGUMENTS

---

## 実行フロー

### Step 1: /simplify で品質改善

`/simplify` を実行して、変更コードを自動改善する。

`/simplify` は以下の3観点でチェックし、問題があれば自動修正する：
- **再利用**: 既存ユーティリティとの重複がないか
- **品質**: 冗長な状態管理、コピペコード、マジックナンバーがないか
- **効率**: 不要な計算、並列化可能な直列処理がないか

```
Skill: simplify
```

### Step 2: 変更差分の取得

`/simplify` 完了後、レビュー対象の変更内容を確認します：

```bash
# 変更差分を取得
jj diff  # または git diff
```

### Step 3: レビューチーム作成

**TeammateTool の spawnTeam でレビューチームを作成：**

```
TeammateTool: spawnTeam
  teamName: "quality-gate"
```

### Step 4: Review Council

**3つの teammate を同時に spawn：**

```
1. TeammateTool: spawnTeammate
   teamName: "quality-gate"
   name: "code-reviewer"
   prompt: |
     ## エージェント定義
     agents/code-reviewer.md の指示に従ってください。

     ## 参照ポリシー
     facets/policies/confidence-scoring.md を Read して適用してください。

     ## コンテキスト
     - タスク: $ARGUMENTS のコードレビュー
     - スコープ: コード品質（バグ、複雑性、保守性）

     ## 入力
     [変更差分を含める]

     ## チーム連携
     - 発見した問題を security-reviewer・critic にもメッセージで共有
     - セキュリティに関連する発見があれば security-reviewer に相談
     - 完了したら Lead に結果サマリーをメッセージ送信

     ## 出力
     - Confidence 80+ の問題のみ Critical/Warning で報告
     - agents/code-reviewer.md の出力フォーマットに従う

2. TeammateTool: spawnTeammate
   teamName: "quality-gate"
   name: "security-reviewer"
   prompt: |
     ## エージェント定義
     agents/security-reviewer.md の指示に従ってください。

     ## 参照ポリシー
     facets/policies/confidence-scoring.md を Read して適用してください。

     ## コンテキスト
     - タスク: $ARGUMENTS のセキュリティレビュー
     - スコープ: OWASP Top 10 + Trail of Bits パターン

     ## 入力
     [変更差分を含める]

     ## チーム連携
     - 発見した問題を code-reviewer・critic にもメッセージで共有
     - コード品質に関連する発見があれば code-reviewer に相談
     - 完了したら Lead に結果サマリーをメッセージ送信

     ## 出力
     - Confidence 80+ の問題のみ Critical/Warning で報告
     - agents/security-reviewer.md の出力フォーマットに従う

3. TeammateTool: spawnTeammate
   teamName: "quality-gate"
   name: "critic"
   prompt: |
     ## エージェント定義
     agents/critic.md の指示に従ってください。

     ## コンテキスト
     - タスク: 実装が計画・設計に沿っているかレビュー
     - スコープ: 計画整合性、設計原則の遵守、スコープ逸脱

     ## 入力
     [変更差分を含める]
     - plan/requirements.md（存在する場合）
     - plan/design.md（存在する場合）
     - plan/tasks.md（存在する場合）

     ## チーム連携
     - 設計との乖離を発見したら code-reviewer・security-reviewer にメッセージで共有
     - 完了したら Lead に結果サマリーをメッセージ送信

     ## 条件
     - plan/ ディレクトリが存在しない場合は「計画なし - スキップ」と報告して終了

     ## 出力
     - 計画との乖離があれば Critical/Warning で報告
     - agents/critic.md の出力フォーマットに従う
```

**重要**: 3つの teammate を同時に spawn してレビュー時間を短縮。
Teammates は互いの発見をメッセージで共有・議論できます。

### Step 5: 結果の集約

3つの teammate からの報告を集約：

#### 集約ルール

- `all("Critical なし")` → 品質ゲート通過
- `any("Critical あり")` → 修正必須。Step 6 へ（自動修正）

```markdown
# 統合レビュー結果

## コード品質（code-reviewer teammate）
- Critical: X件
- Warning: X件

## セキュリティ（security-reviewer teammate）
- Critical: X件
- Warning: X件

## 計画整合性（critic teammate）
- Critical: X件（計画なしの場合: スキップ）
- Warning: X件

## 総合判定
→ all("Critical なし"): 品質ゲート通過
→ any("Critical あり"): 修正必須
```

### Step 6: Critical 発見時の自動修正

Critical が見つかった場合、**自動で修正を試みる**（ノンストップ原則）：

1. 問題箇所を特定し、修正を適用
2. Step 2 に戻り Review Council を再実行して修正を確認
3. 修正不可能な場合は DONE 出力時に stop-guard がブロックする（既存の仕組み）

### Step 7: 静的解析（言語別 Lint — 最終チェック）

全修正が完了した最終成果物に対して、言語別のリンターを実行する。該当ファイルがなければスキップ。

| ファイル種別 | リンター | コマンド |
|-------------|---------|---------|
| `*.py` | ruff + ty | `ruff check . && ty check .` |
| `*.sh` | shellcheck | `shellcheck <files>` |

```bash
# Python ファイルがある場合
if compgen -G "**/*.py" > /dev/null 2>&1; then
  ruff check .
  ty check .
fi

# Shell スクリプトがある場合
if compgen -G "**/*.sh" > /dev/null 2>&1; then
  shellcheck **/*.sh
fi
```

- エラーがあれば**この場で修正**して再実行
- warning のみなら記録して続行

---

## 完了時の出力

```
✅ 品質ゲート通過（/simplify + Review Council + Lint）

🔧 /simplify
   修正: X件

📊 コード品質
   🟢 Critical: なし
   🟡 Warning: X件

🔒 セキュリティ
   🟢 Critical: なし
   🟡 Warning: X件

📐 計画整合性
   🟢 Critical: なし（または: 計画なし - スキップ）
   🟡 Warning: X件

🔍 静的解析
   ruff: ✅ (or N/A)
   ty: ✅ (or N/A)
   shellcheck: ✅ (or N/A)

→ 品質ゲート通過

<promise>DONE</promise>
```

---

**品質ゲートを開始します。まず `/simplify` を実行し、Review Council で並列レビュー、最後に静的解析で最終チェックを行ってください。**
