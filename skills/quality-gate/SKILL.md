---
name: quality-gate
description: "Review Council → 静的解析(ruff/ty/shellcheck/tsc/eslint/clippy) を連続実行してコード品質を最終確認。code-reviewer, security-reviewer, critic を並列実行して品質・セキュリティ・計画整合性をチェック。実装完了後、マージ前、コードを書き終えたときに使う。「品質チェックして」「品質ゲート通して」「レビューして」「コードを確認して」「PR 出す前にチェック」「セキュリティ大丈夫？」「コード見て」で発動。"
argument-hint: "[specific files or 'all']"
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion, Agent, TeamCreate, TeamDelete, SendMessage, Skill]
model: opus
effort: high
context: fork
paths:
  - "**/*.py"
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
  - "**/*.sh"
  - "**/*.rs"
  - "**/*.go"
  - "**/*.java"
  - "**/*.rb"
  - "**/*.php"
  - "**/*.swift"
  - "**/*.kt"
  - "**/*.c"
  - "**/*.cpp"
  - "**/*.cs"
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

### Step 1.5: /simplify（自動修正）

Review Council の前に、再利用性・品質・効率の自動レビュー+修正を実行する。
レビュアーに渡す前にまず機械的に改善できるものは改善しておく。

```
Skill: simplify
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

**原則: コンテキスト遮断** — reviewer は実装者の意図・理由・議論を知らない状態でレビューする。prompt に実装の「なぜ」を含めない。渡すのはコード差分のみ。これにより実装者のバイアスを排除し、コードそのものを客観的に評価する。

3つの reviewer（code-reviewer, security-reviewer, critic）を Agent で同時 spawn。
→ **prompt テンプレートは reference.md を Read して使用**

**重要**: 3つの teammate を同時に spawn してレビュー時間を短縮。
SendMessage で互いの発見を共有・議論し、相互検証する。

### Step 4: 結果の集約

3つの teammate からの報告を集約（→ フォーマットは reference.md 参照）:

- `all("Critical なし")` → 品質ゲート通過
- `any("Critical あり")` → 修正必須。Step 5 へ

### Step 4.5: チーム解散

結果を集約したらすぐにチームを解散する。**lint や修正の前に必ず実行。**
**shutdown メッセージは送らない。** TeamDelete だけで十分。SendMessage でブロードキャストしない。

```
TeamDelete
```

### Step 5: Critical 発見時の自動修正

Critical が見つかった場合、**自動で修正を試みる**（ノンストップ原則）：

1. 問題箇所を特定し、修正を適用
2. Step 1 に戻り Review Council を再実行して修正を確認
3. 修正不可能な場合は AskUserQuestion で判断を委ねる

### Step 6: 静的解析（言語別 Lint — 最終チェック）

全修正が完了した最終成果物に対して、言語別のリンターを実行する。該当ファイルがなければスキップ。

言語別リンターを実行する。該当ファイルがなければスキップ。
→ **コマンド詳細は reference.md 参照**

- Python: `ruff check . && ty check .`
- Shell: `shellcheck`
- TypeScript: `npx tsc --noEmit && npx eslint .`
- Rust: `cargo clippy && cargo test`

エラーがあればこの場で修正して再実行。warning のみなら記録して続行。

### Step 7: 静的解析の最終実行

**全ステップ完了後**、lint を実行する。

```bash
lint
```

## Gotchas

- **diff が大きすぎて reviewer がコンテキスト溢れ**: 変更が数千行ある場合、reviewer に渡す diff を要約するか、ファイル単位で分割してレビューする
- **静的解析ツールが未インストールで失敗**: `ruff`, `shellcheck`, `tsc` 等が PATH にない場合がある。`compgen -G` のファイル検出だけでなく、コマンドの存在確認も行う
- **前回の TeamCreate の残骸でエラー**: Step 2 で既存チームの TeamDelete を先に実行する。前セッションのチームが残っているとチーム名が衝突する

<!-- AUTO-GOTCHAS -->

---

**品質ゲートを開始します。**

1. **変更差分を取得**（Step 1）
2. **Review Council** を TeamCreate + Agent spawn で実行（Step 2〜4）
3. **Critical 修正**があれば対応（Step 5）
4. **静的解析**（Step 6〜7）
