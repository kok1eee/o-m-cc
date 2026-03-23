---
name: quality-gate
description: "Review Council → 静的解析(ruff/ty/shellcheck/tsc/eslint/clippy) を連続実行してコード品質を最終確認。code-reviewer, security-reviewer, critic を並列実行して品質・セキュリティ・計画整合性をチェック。実装完了後、マージ前、コードを書き終えたときに使う。「品質チェックして」「品質ゲート通して」「レビューして」「コードを確認して」「PR 出す前にチェック」「セキュリティ大丈夫？」「コード見て」で発動。"
argument-hint: "[specific files or 'all']"
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion, Agent, TeamCreate, TeamDelete, SendMessage, Skill]
model: opus
effort: high
context: fork
---

# Quality Gate - Review Council + Lint 連続実行

コード変更に対して Review Council（並列レビュー）→ 静的解析（最終チェック）を連続実行し、品質を最終確認します。

> **Note**: このスキルは **opus 専用**（`model: opus`）。Review Council 実行時にプラグインコンテキスト + 変更差分で 200k トークンを超えるため、Sonnet（200k）ではコンテキスト溢れが発生する。

## 対象

$ARGUMENTS

## 現在の変更状態（動的注入）

### 変更統計
!`jj diff --stat 2>/dev/null || git diff --stat HEAD 2>/dev/null || echo "差分なし"`

### 変更ファイル一覧
!`jj diff --name-only 2>/dev/null || git diff --name-only HEAD 2>/dev/null || echo "なし"`

---

## 実行フロー

### Step 1: 変更差分の取得

上記の動的注入で概要は把握済み。詳細な diff を取得します：

```bash
# 変更差分を取得
jj diff  # または git diff
```

### Step 2: レビューチーム作成

**既存チームがあれば削除してから作成（前回の残骸 cleanup）：**

```
TeamDelete:
  team_name: "<既存チーム名>"  # エラーが出なければスキップ

TeamCreate:
  team_name: "quality-gate"
  description: "Quality gate review council"
```

### Step 3: Review Council

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
     - requirements.md / design.md の `## 既知の不足` セクションはレビュー対象外（上流で解決できなかった問題であり、人間が継続を判断済み）

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

### Step 4: 結果の集約

3つの teammate からの報告を集約：

#### 集約ルール

- `all("Critical なし")` → 品質ゲート通過
- `any("Critical あり")` → 修正必須。Step 5 へ（自動修正）

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

### Step 5: Critical 発見時の自動修正

Critical が見つかった場合、**自動で修正を試みる**（ノンストップ原則）：

1. 問題箇所を特定し、修正を適用
2. Step 1 に戻り Review Council を再実行して修正を確認
3. 修正不可能な場合は DONE 出力時に stop-guard がブロックする（既存の仕組み）

### Step 6: 静的解析（言語別 Lint — 最終チェック）

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
✅ 品質ゲート通過（Review Council + Lint）

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

### Step 7: Proof ファイル書き込み（静的解析ゲート付き）

**全ステップ完了後**、lint.sh を `--proof` 付きで実行する。
静的解析が通った場合のみ proof ファイルが書き込まれる。stop-guard はこのファイルを検証して品質ゲート通過を判定する。

```bash
bash ${CLAUDE_SKILL_DIR}/lint.sh --proof
```

> **重要**: このコマンドは Step 1〜6（Review Council + 静的解析修正）が完了した後に実行すること。静的解析が失敗すると proof は書き込まれない。lint.sh の詳細は `skills/quality-gate/lint.sh` を参照。

## Gotchas

- **running マーカーを忘れて stop-guard にブロックされる**: 品質ゲート開始前に必ず `.claude/quality-gate-running` を作成。これがないと stop-guard が実行中と認識せずブロックする
- **diff が大きすぎて reviewer がコンテキスト溢れ**: 変更が数千行ある場合、reviewer に渡す diff を要約するか、ファイル単位で分割してレビューする
- **静的解析ツールが未インストールで失敗**: `ruff`, `shellcheck`, `tsc` 等が PATH にない場合がある。`compgen -G` のファイル検出だけでなく、コマンドの存在確認も行う
- **前回の TeamCreate の残骸でエラー**: Step 2 で既存チームの TeamDelete を先に実行する。前セッションのチームが残っているとチーム名が衝突する
- **proof ファイルが baseline より古くて無効扱い**: proof は baseline ファイルより新しい必要がある。セッション再開後に即 quality-gate を実行すると baseline が更新されて proof が無効になることがある

---

**品質ゲートを開始します。**

**まず running マーカーを作成**（stop-guard が実行中を認識してブロックしない）：
```bash
mkdir -p .claude && echo "{\"started_at\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\"}" > .claude/quality-gate-running
```

1. **変更差分を取得**（Step 1）
2. **Review Council** を TeamCreate + Agent spawn で実行（Step 2〜4）
3. **Critical 修正**があれば対応（Step 5）
4. **静的解析 + proof 書き込み**（Step 6〜7）
