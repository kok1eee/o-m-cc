---
name: quality-gate
description: "/simplify → Review Council → 静的解析(ruff/ty/shellcheck/tsc/eslint/clippy) を連続実行してコード品質を最終確認。code-reviewer, security-reviewer, critic を並列実行して品質・セキュリティ・計画整合性をチェック。実装完了後、マージ前、コードを書き終えたときに使う。「品質チェックして」「品質ゲート通して」「レビューして」「コードを確認して」「PR 出す前にチェック」「セキュリティ大丈夫？」「simplify して」「コード見て」で発動。"
argument-hint: "[specific files or 'all']"
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion, Agent, TeamCreate, TeamDelete, SendMessage, Skill]
model: opus
context: fork
---

# Quality Gate - /simplify + Review Council + Lint 連続実行

コード変更に対して `/simplify`（自動修正）→ Review Council（並列レビュー）→ 静的解析（最終チェック）を連続実行し、品質を最終確認します。

> **Note**: このスキルは **opus 専用**（`model: opus`）。Review Council 実行時にプラグインコンテキスト + 変更差分で 200k トークンを超えるため、Sonnet（200k）ではコンテキスト溢れが発生する。

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

> **必須**: Step 3〜5 は `/simplify` とは完全に別のステップです。「/simplify で既に実行済み」ということはありえません。必ず以下の TeamCreate + Agent spawn を実行してください。

**既存チームがあれば削除してから作成（前回の残骸 cleanup）：**

```
TeamDelete:
  team_name: "<既存チーム名>"  # エラーが出なければスキップ

TeamCreate:
  team_name: "quality-gate"
  description: "Quality gate review council"
```

### Step 4: Review Council

**3つの reviewer を Agent ツールで同時 spawn：**

```
1. Agent:
   subagent_type: "o-m-cc:code-reviewer"
   name: "code-reviewer"
   team_name: "quality-gate"
   description: "Quality Gate: コード品質"
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

     ## Council プロトコル
     1. 独立にレビューを実施
     2. SendMessage で findings を security-reviewer・critic に共有
     3. 他の reviewer から SendMessage で共有された findings を検証し、同意/異議を返す
     4. 相互検証を経た最終 findings のみを報告

     ## 出力
     - Confidence 80+ の問題のみ Critical/Warning で報告
     - agents/code-reviewer.md の出力フォーマットに従う

2. Agent:
   subagent_type: "o-m-cc:security-reviewer"
   name: "security-reviewer"
   team_name: "quality-gate"
   description: "Quality Gate: セキュリティ"
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

     ## Council プロトコル
     1. 独立にセキュリティレビューを実施
     2. SendMessage で findings を code-reviewer・critic に共有
     3. 他の reviewer から SendMessage で共有された findings を検証し、同意/異議を返す
     4. 相互検証を経た最終 findings のみを報告

     ## 出力
     - Confidence 80+ の問題のみ Critical/Warning で報告
     - agents/security-reviewer.md の出力フォーマットに従う

3. Agent:
   subagent_type: "o-m-cc:critic"
   name: "critic"
   team_name: "quality-gate"
   description: "Quality Gate: 計画整合性"
   prompt: |
     ## エージェント定義
     agents/critic.md の指示に従ってください。

     ## コンテキスト
     - タスク: 実装が計画・設計に沿っているかレビュー
     - スコープ: 計画整合性、設計原則の遵守、スコープ逸脱

     ## 入力
     [変更差分を含める]
     - plan/ ディレクトリ内のファイルを自分で確認してください

     ## Council プロトコル
     1. 独立に計画整合性レビューを実施
     2. SendMessage で findings を code-reviewer・security-reviewer に共有
     3. 他の reviewer から SendMessage で共有された findings を検証し、同意/異議を返す
     4. 相互検証を経た最終 findings のみを報告

     ## 出力
     - 計画との乖離があれば Critical/Warning で報告
     - agents/critic.md の出力フォーマットに従う
```

**重要**: 3つの teammate を同時に spawn してレビュー時間を短縮。
SendMessage で互いの発見を共有・議論し、相互検証する。

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
| `*.ts` / `*.tsx` | tsc + eslint | `npx tsc --noEmit && npx eslint .` |
| `*.rs` | cargo clippy + cargo test | `cargo clippy -- -D warnings && cargo test` |

```bash
# Python ファイルがある場合
if compgen -G "**/*.py" > /dev/null 2>&1; then
  ruff check .
  ty check .
fi

# Shell スクリプトがある場合
if compgen -G "**/*.sh" > /dev/null 2>&1; then
  shellcheck -S warning **/*.sh
fi

# TypeScript ファイルがある場合
if compgen -G "**/*.ts" > /dev/null 2>&1 || compgen -G "**/*.tsx" > /dev/null 2>&1; then
  npx tsc --noEmit
  npx eslint .
fi

# Rust ファイルがある場合（既にビルド/テスト済みならスキップ可）
if [[ -f "Cargo.toml" ]]; then
  cargo clippy -- -D warnings
  cargo test
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
   tsc: ✅ (or N/A)
   eslint: ✅ (or N/A)
   clippy: ✅ (or N/A)
   cargo test: ✅ (or N/A)

→ 品質ゲート通過
```

### Step 5: Proof ファイル書き込み（静的解析ゲート付き）

**全ステップ完了後**、以下のコマンドを **1つの Bash ツール呼び出し** で実行する。
静的解析が通った場合のみ proof ファイルが書き込まれる。stop-guard はこのファイルを検証して品質ゲート通過を判定する。

```bash
# 静的解析ゲート: 該当ファイルがあればチェック、失敗したら proof を書かない
PASS=true

# Python
if compgen -G "**/*.py" > /dev/null 2>&1; then
  ruff check . || PASS=false
fi

# Shell
SHELL_FILES=$(find . -name "*.sh" -not -path "./.claude/*" -not -path "./node_modules/*" 2>/dev/null)
if [[ -n "$SHELL_FILES" ]]; then
  echo "$SHELL_FILES" | xargs shellcheck -S warning || PASS=false
fi

# TypeScript
if compgen -G "**/*.ts" > /dev/null 2>&1 || compgen -G "**/*.tsx" > /dev/null 2>&1; then
  npx tsc --noEmit || PASS=false
fi

# Rust
if [[ -f "Cargo.toml" ]]; then
  cargo clippy -- -D warnings || PASS=false
fi

# running マーカー削除（quality-gate 完了）
rm -f .claude/quality-gate-running

# 全チェック通過時のみ proof を書き込む
if [[ "$PASS" == "true" ]]; then
  mkdir -p .claude && echo "{\"passed_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > .claude/quality-gate-proof.json
  echo "✅ 静的解析通過 — proof ファイル書き込み完了"
else
  echo "❌ 静的解析失敗 — proof ファイルは書き込まれません。エラーを修正して再実行してください。"
fi
```

> **重要**: このコマンドは Step 1〜4（/simplify + Review Council + 静的解析修正）が完了した後に実行すること。静的解析が失敗すると proof は書き込まれない。

---

**品質ゲートを開始します。**

**まず running マーカーを作成**（stop-guard が実行中を認識してブロックしない）：
```bash
mkdir -p .claude && echo "{\"started_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > .claude/quality-gate-running
```

1. **`/simplify`** を実行（Step 1）
2. **Review Council** を TeamCreate + Agent spawn で実行（Step 3〜5） — /simplify とは別ステップ、省略不可
3. **静的解析 + proof 書き込み**（Step 7 + proof）
