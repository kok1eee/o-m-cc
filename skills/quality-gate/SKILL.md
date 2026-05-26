---
name: quality-gate
description: "コード品質の最終確認。Skill: code-review (built-in) で correctness bug を検出 → main agent が findings を修正 → lint/ty 静的解析 → 条件付きで security-reviewer / critic を spawn (security 関連変更 or plan/requirements.md がある時のみ)。実装完了後、マージ前、コードを書き終えたときに使う。「品質チェックして」「品質ゲート通して」「レビューして」「コードを確認して」「PR 出す前にチェック」「セキュリティ大丈夫？」「コード見て」で発動。"
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

> **fork コンテキスト制約**: 本スキルは `context: fork` + `allowed-tools` に **Edit / Write を含めない設計**（呼び出し元のメインコンテキストを Council の verbose な findings で汚染しないため）。fork agent はファイルを **直接編集できない**。修正が必要な場合は、(a) 軽微なら findings を fork の最終 summary に列挙して **呼び出し元（main / sisyphus）に修正を委ねる**、(b) 複雑なら fork 内から **Agent ツールで debugger 等を spawn**（debugger は Edit/Write を持つ）して修正する。

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

### Step 2: Skill: code-review（correctness bug 検出 → 呼び出し元 / debugger spawn で修正）

Anthropic 公式の **`Skill: code-review`** に **コードレビュー（correctness bug 検出）** を委譲する。effort level 指定可（`/code-review high` 等）。**v2.1.147 で cleanup-and-fix 動作は削除された**ため、本 skill は bug を **報告するのみ** で自動修正はしない。

```
Skill: code-review
```

**fork 内の findings 取り扱い** (上記 fork 制約を参照):

1. **findings をメモする**: 出力された bug list（ファイル / 行 / 説明）を保持して、Step 9 の最終 summary に必ず列挙すること（fork 終了時に caller に渡る）
2. **修正の振り分け**:
   - **軽微な finding**: 修正は **呼び出し元（main / sisyphus）** に委ねる → fork の summary に "[fix needed]" マーカー付きで列挙し、Step 3 へ進む
   - **複雑なバグ**: Step 6 と同じ要領で `Agent` ツールから **debugger を spawn** して fork 内で修正完結させる（debugger は Edit/Write を持つ）
3. **caller 側の動作**: fork 終了後、main / sisyphus は summary を読んで該当箇所を Edit し、必要なら quality-gate を再実行して通過確認する（iterative ループ）

> **設計理由**: v0.58.0 当時は `Skill: simplify`（cleanup-and-fix）と独自 `code-reviewer` agent の責任範囲が重複していたため統合した。v2.1.147 で `/simplify` は `/code-review` にリネームされ **cleanup 機能が削除**（bug 検出特化）。現状は cleanup の自動化機能はビルトインから失われており、findings は main agent が手動反映する。format / style 統一は Step 3 の lint に任せる。

### Step 3: 静的解析（lint + 型チェック）— Monitor で並列ストリーミング

code-review の findings を main agent が修正した後、言語別の静的解析を **Monitor で並列実行** する。Council を呼ぶ前に lint エラーを潰しておくことで、reviewer に「lint で見つかる軽微な問題」を見せずレビュアーの注意を本質的問題に集中させる。

```
Monitor:
  description: "quality-gate lint (parallel)"
  timeout_ms: 120000
  persistent: false
  command: |
    (
      command -v ruff >/dev/null 2>&1 && { echo "=== [ruff] ===" && ruff check . 2>&1 | sed -u 's/^/[ruff] /'; } &
      command -v ty >/dev/null 2>&1 && { echo "=== [ty] ===" && ty check . 2>&1 | sed -u 's/^/[ty] /'; } &
      command -v shellcheck >/dev/null 2>&1 && { echo "=== [shellcheck] ===" && shellcheck **/*.sh 2>&1 | sed -u 's/^/[shellcheck] /'; } &
      command -v npx >/dev/null 2>&1 && { echo "=== [tsc] ===" && npx tsc --noEmit 2>&1 | sed -u 's/^/[tsc] /'; } &
      command -v cargo >/dev/null 2>&1 && { echo "=== [clippy] ===" && cargo clippy 2>&1 | sed -u 's/^/[clippy] /'; } &
      wait
      echo "=== lint complete ==="
    )
```

エラーが残っていれば修正してから Step 4 へ。warning のみなら記録して続行。

### Step 3.5: EDD drift check（optional / 通知止まり）

`bin/edd-check` が存在する場合のみ実行する EDD 層の数値ゲート（FR-5）。FR カバレッジ率と outputs.csv の failure rate を閾値判定し、超過していれば `edd-drift` atom を登録する（Sensors 止まり = 通知のみ）。**pass/fail 判定には影響させない**（NFR-3）。

```bash
# edd-check が無ければ skip（A-3: optional 機能、既存環境への影響ゼロ）
if [[ -x bin/edd-check ]]; then
  bin/edd-check 2>&1 || true   # exit 1 でも quality-gate は止めない（通知止まり）
fi
```

- exit 1（閾値超え）でも **quality-gate の総合判定は変えない**。検知結果は Step 9 summary に「EDD drift」として記載する
- 閾値超え時は `edd-drift` atom が atoms.csv に登録される（7 日重複防止あり）。人間が後で `/atom-suggest` で拾って判断する
- 閾値: `EDD_FR_COVERAGE_MIN`（default 70）/ `EDD_FAILURE_RATE_MAX`（default 30）を env で上書き可

### Step 4: 条件付き Review Council（security / plan 整合性が必要な時のみ）

ここまでで「コード品質一般」と「lint」は片付いている。**残りの責任範囲は (a) セキュリティ脆弱性、(b) 計画妥当性 / 範囲整合性** のみ。これらは条件付きで spawn する:

| 条件 | 起動するレビュアー |
|---|---|
| `git diff` に **認証 / 暗号化 / 入力検証 / 認可** 系のキーワード（auth, login, password, token, jwt, sanitize, escape, validate, sql, injection 等）または `*/auth/*`, `*/security/*`, `*/middleware/*` パスの変更が含まれる | **security-reviewer** を spawn |
| `plan/requirements.md` が存在する | **critic** を spawn（実装範囲整合性検証も併せて担当） |
| 上記いずれにも該当しない | **Council はスキップして Step 5 へ** |

両方該当する場合は **両方を同時 spawn**（peer-to-peer で SendMessage 共有）。

**spawn 時の原則: コンテキスト遮断** — reviewer は実装者の意図・理由を知らない状態でレビューする。prompt に「なぜこの実装をしたか」を含めない。渡すのはコード差分のみ。実装者のバイアスを排除する。

prompt テンプレートは `reference.md` を Read して使用。

#### TeamCreate（Council 起動時のみ）

```
TeamDelete:
  team_name: "<既存チーム名>"  # エラーが出なければスキップ

TeamCreate:
  team_name: "quality-gate"
  description: "Quality gate review council (conditional)"
```

### Step 5: 結果の集約（Council 起動時のみ、JSON 入力 + 降格マトリクス自動適用）

Council をスキップした場合はこの Step も飛ばす。

起動した teammate は `facets/policies/council-output-schema.md` に従う JSON オブジェクトを返す。集約側で機械的に降格・分類する。

#### 手順

1. 各 reviewer の JSON を取得（SendMessage の戻り値、または出力ファイル）
2. JSON をパース。schema_version が `"1"` であることを確認
3. `findings` 配列の各要素に対して降格マトリクスを適用:

| confidence | severity | 分類 |
|---|---|---|
| 90+ | critical / high | 🔴 Critical |
| 80-89 | high / medium | 🟡 Warning |
| 60-79 | medium / low | ℹ️ Note |
| < 60 | - | 📦 Archive |

4. バケット別に集計し、reference.md の集約テンプレートに沿ってレポートを生成

#### 判定

- `len(🔴 Critical) == 0` → 品質ゲート通過
- `len(🔴 Critical) > 0` → 修正必須。Step 5 へ
- 🟡 Warning / ℹ️ Note / 📦 Archive は通過判定の対象外（レポートには記載）

#### JSON パース失敗時のフォールバック

- reviewer が schema 違反の出力を返した場合は、JSON パースを再実行依頼（最大 1 回）。それでも失敗なら markdown レポートとして処理し、`[NOTE] schema 違反: <reviewer>` を集約レポートに記録
- 集約は他 reviewer 分のみ進める（1 つの reviewer 失敗で全体停止しない）

→ 集約擬似コード・レポートテンプレートは reference.md 参照

### Step 5.5: チーム解散（Council 起動時のみ）

結果を集約したらすぐにチームを解散する。**修正の前に必ず実行。**
**shutdown メッセージは送らない。** TeamDelete だけで十分。SendMessage でブロードキャストしない。

```
TeamDelete
```

### Step 6: Critical 発見時の自動修正

Critical が見つかった場合（Council 起動かつ集約結果に Critical あり）、**自動で修正を試みる**（ノンストップ原則）：

1. **`Agent` ツールで debugger を spawn して修正を適用**（fork は Edit/Write 不可。debugger の tools: には Edit/Write が含まれるため、spawn 経由で修正可能）
2. **Step 3 に戻り lint を再実行**（修正で型エラーや構文エラーが出ていないかチェック）
3. 必要なら Step 4 の Council を再実行して修正を確認
4. 修正不可能な場合は AskUserQuestion で判断を委ねる、または summary に "[fix needed]" として列挙し caller に委ねる

### Step 7: 最終 lint

**全ステップ完了後**、lint を実行する。

```bash
lint
```

### Step 8: 通知（条件付き）

以下のいずれかに該当する場合、`PushNotification` で結果を送る。短時間（数分以内）＆ユーザーが画面を見ている可能性がある場合は送らない。

- **Critical 発見で Step 6 の自動修正も不可**（ユーザー判断が必要で停止）: 例 `quality-gate 停止: SQL injection in auth.ts:42、判断待ち`
- **Review Council が 10 分以上走った**（ユーザー離席想定）: 例 `quality-gate 通過: Critical 0, 12 ファイルレビュー完了`
- **静的解析で Error が残った**: 例 `lint 失敗: shellcheck 3 errors in hooks/foo.sh`

メッセージは行動可能な情報でリードし、200 文字以内。

### Step 9: fork 終了時の summary（必須）

fork の **最後のメッセージ** が呼び出し元（main / sisyphus）に戻る成果物になる。以下を必ず含めること（caller がこの summary だけで状況把握できる粒度で）:

- **総合判定**: 通過 / 修正必要 / 停止（ユーザー判断待ち）のいずれか
- **Step 2 code-review findings**: `[fix needed]` マーカー付きで「ファイル:行 — 内容」形式で列挙（fork 内で修正済みの分は `[fixed by debugger]` マーカー付きで別記）
- **Step 3 lint 結果**: 各言語の error / warning 件数。残存 error があれば該当ファイル列挙
- **Step 3.5 EDD drift**（edd-check 実行時のみ）: FR coverage / failure rate の閾値判定結果。超過があれば登録された edd-drift atom を記載（通知のみ、判定には影響しない）
- **Step 4 Council 結果**（実行時のみ）: Critical / Warning の件数、Critical の代表例
- **caller への次アクション**: 「Edit で fix → quality-gate 再実行」「修正不可なのでユーザー判断必要」等

例:
```
[quality-gate summary]
判定: 修正必要 (Critical 2, fix needed)

Step 2 code-review findings:
  [fix needed] src/auth.ts:42 — uninitialized password before null check
  [fixed by debugger] src/utils.ts:88 — off-by-one in loop boundary

Step 3 lint: ruff 0 / ty 0 / shellcheck 0 errors
Step 3.5 EDD drift: FR coverage 100% / failure rate OK（閾値内、atom 登録なし）
Step 4 Council: 未実行 (security-related changes なし / requirements.md なし)

次アクション: src/auth.ts:42 を Edit で fix → quality-gate を再実行
```

## Gotchas

- **実装範囲の整合性**: Step 1.1 で requirements.md と実際の変更差分が乖離していたら致命エラーで停止する。「実装者が Phase 4 で嘘の完了報告をした」パターンを Phase 5 で検出する仕組み。requirements.md がない or 対象範囲が抽出不能ならスキップ
- **diff が大きすぎて reviewer がコンテキスト溢れ**: 変更が数千行ある場合、reviewer に渡す diff を要約するか、ファイル単位で分割してレビューする
- **静的解析ツールが未インストールで失敗**: `ruff`, `shellcheck`, `tsc` 等が PATH にない場合がある。`compgen -G` のファイル検出だけでなく、コマンドの存在確認も行う
- **前回の TeamCreate の残骸でエラー**: Step 2 で既存チームの TeamDelete を先に実行する。前セッションのチームが残っているとチーム名が衝突する
- **agent 側に閾値カットを書かない（4.7 リテラル解釈トラップ）**: `"Confidence 80+ のみ報告"` のような閾値指示を agent に書くと、Opus 4.7 は文字通り守ってバグを発見しても silent drop する。agent は coverage-first（全件 + confidence/severity 付与）、フィルタは Step 4 の集約側で行う

<!-- AUTO-GOTCHAS -->

---

**品質ゲートを開始します。**

1. **変更差分を取得**（Step 1）
2. **Review Council** を TeamCreate + Agent spawn で実行（Step 2〜4）
3. **Critical 修正**があれば対応（Step 5）
4. **静的解析**（Step 6〜7）
