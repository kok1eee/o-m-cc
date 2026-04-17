---
name: quality-gate
description: "Review Council → 静的解析(ruff/ty/shellcheck/tsc/eslint/clippy) を連続実行してコード品質を最終確認。code-reviewer, security-reviewer, critic を並列実行して品質・セキュリティ・計画整合性をチェック。実装完了後、マージ前、コードを書き終えたときに使う。「品質チェックして」「品質ゲート通して」「レビューして」「コードを確認して」「PR 出す前にチェック」「セキュリティ大丈夫？」「コード見て」で発動。"
argument-hint: "[specific files or 'all']"
allowed-tools: [Read, Glob, Grep, Bash, Monitor, AskUserQuestion, Agent, TeamCreate, TeamDelete, SendMessage, Skill, PushNotification]
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

### Step 1.1: 実装範囲の整合性検証（requirements.md がある場合）

**`plan/requirements.md` が存在する場合のみ実行**。quality-gate を sisyphus 外で
単独呼び出しした場合（requirements.md なし）はスキップ。

目的: sisyphus で生成された requirements.md が「A / B / C ファイルを変更する」
と宣言しているのに、実装者が**実際には D / E だけ触っていた**、というズレを
Review Council 前に検出する。過去に「5 画面 redesign を要求しているのに
2 ファイルしか触っていないのに『完了』と報告」する事故が発生したため。

**手順**:

1. `plan/requirements.md` を Read し、以下のヒントから**実装対象ファイル/範囲**
   を抽出（完全自動化は困難なので Claude の自然文判断）:
   - `## 対象ファイル` / `## Scope` / `## スコープ` セクション
   - 本文中の `src/components/foo.tsx` 等のファイルパス言及
   - 「5 画面」「全エンドポイント」等の範囲記述

2. `jj diff --stat`（または `git diff --stat HEAD`）で実際の変更ファイルを取得

3. 照合:

| 照合結果 | アクション |
|---|---|
| 対象ファイルが **1 つも変更されていない** | **致命エラーで停止**。`PushNotification` で通知。「requirements.md は X を要求しているが実装が存在しない」と明示し AskUserQuestion で判断を仰ぐ |
| 対象ファイルの**一部**が未変更 | **警告のみ**（[NOTE] として記録）して先に進む。部分実装は意図的なこともあるため |
| 対象ファイルが全て変更されている | 通常通り Step 1.5 へ |
| requirements.md に対象範囲が書かれていない | スキップ（抽出不能な場合は検証できない） |

**設計判断**:
- `jj diff --stat` の出力はパースしやすい（`path | +N -M` 形式）
- 「致命エラー」は sisyphus から呼ばれた時に Phase 5 を止めるので重大。
  だからこそ「1 つも変更なし」のような**明確な乖離**のみを致命扱いする
- False positive を避けるため、requirements.md の書き方がブレている場合は
  迷わずスキップ（警告すらしない）

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

### Step 6: 静的解析（言語別 Lint — Monitor で並列ストリーミング）

全修正が完了した最終成果物に対して、言語別のリンターを **Monitor で並列実行** する。該当ファイルがなければスキップ。

→ **コマンド詳細は reference.md 参照**

**Monitor で並列実行**: 各 lint の出力がリアルタイムでストリーミングされる。最初の lint 結果が出た時点で修正に着手でき、全ツール完了を待たない。

```
Monitor:
  description: "quality-gate lint (parallel)"
  timeout_ms: 120000
  persistent: false
  command: |
    (
      command -v ruff >/dev/null 2>&1 && { echo "=== [ruff] ===" && ruff check . 2>&1 | sed -u 's/^/[ruff] /'; } &
      command -v shellcheck >/dev/null 2>&1 && { echo "=== [shellcheck] ===" && shellcheck **/*.sh 2>&1 | sed -u 's/^/[shellcheck] /'; } &
      command -v npx >/dev/null 2>&1 && { echo "=== [tsc] ===" && npx tsc --noEmit 2>&1 | sed -u 's/^/[tsc] /'; } &
      command -v cargo >/dev/null 2>&1 && { echo "=== [clippy] ===" && cargo clippy 2>&1 | sed -u 's/^/[clippy] /'; } &
      wait
      echo "=== lint complete ==="
    )
```

**tag prefix** (`[ruff]`, `[shellcheck]` 等) で出力元を識別し、エラーがあれば該当ツールの指摘から順に修正して再実行。warning のみなら記録して続行。

**fallback**: Monitor が使えない環境では従来通り Bash で順次実行:
- Python: `ruff check . && ty check .`
- Shell: `shellcheck`
- TypeScript: `npx tsc --noEmit && npx eslint .`
- Rust: `cargo clippy && cargo test`

### Step 7: 静的解析の最終実行

**全ステップ完了後**、lint を実行する。

```bash
lint
```

### Step 8: 通知（条件付き）

以下のいずれかに該当する場合、`PushNotification` で結果を送る。短時間（数分以内）＆ユーザーが画面を見ている可能性がある場合は送らない。

- **Critical 発見で Step 5 の自動修正も不可**（ユーザー判断が必要で停止）: 例 `quality-gate 停止: SQL injection in auth.ts:42、判断待ち`
- **Review Council が 10 分以上走った**（ユーザー離席想定）: 例 `quality-gate 通過: Critical 0, 12 ファイルレビュー完了`
- **静的解析で Error が残った**: 例 `lint 失敗: shellcheck 3 errors in hooks/foo.sh`

メッセージは行動可能な情報でリードし、200 文字以内。

## Gotchas

- **実装範囲の整合性**: Step 1.1 で requirements.md と実際の変更差分が乖離していたら致命エラーで停止する。「実装者が Phase 4 で嘘の完了報告をした」パターンを Phase 5 で検出する仕組み。requirements.md がない or 対象範囲が抽出不能ならスキップ
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
