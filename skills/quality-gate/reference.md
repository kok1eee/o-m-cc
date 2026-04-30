# Quality Gate - Reference

> SKILL.md から参照される詳細テンプレート。必要時のみ Read する。

## 共通プロトコル

- **Plan Handoff Protocol**: `facets/policies/plan-handoff.md`
- **Council Output Schema (JSON)**: `facets/policies/council-output-schema.md`
- **Confidence Scoring (Coverage-first)**: `facets/policies/confidence-scoring.md`

各 reviewer は Council Output Schema に従って **1 つの JSON オブジェクト** を返す。集約側（SKILL.md Step 4）が JSON でパースして降格マトリクスを機械的に適用する。

## Agent Prompt テンプレート

### code-reviewer

```
Agent:
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
    5. このプロジェクトで繰り返し発見した指摘パターンは memory に保存

    ## 出力（Coverage-first + JSON Schema）
    - 検出した issue は confidence (0-100) と severity (critical/high/medium/low) を付与して**全件報告**
    - finding 時にフィルタリングしない（閾値カットは集約側で行う）
    - 出力は `facets/policies/council-output-schema.md` の JSON schema に従う 1 つの JSON オブジェクト
    - `reviewer: "code-reviewer"`、`category: "code-quality"`、`file` と `line_range` 必須
    - 前置き・後書き・コードフェンスなしの純粋な JSON で返す
```

### security-reviewer

```
Agent:
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
    5. このプロジェクトで繰り返し発見した脆弱性パターンは memory に保存

    ## 出力（Coverage-first + JSON Schema）
    - 検出した issue は confidence (0-100) と severity (critical/high/medium/low) を付与して**全件報告**
    - finding 時にフィルタリングしない（閾値カットは集約側で行う）
    - 出力は `facets/policies/council-output-schema.md` の JSON schema に従う 1 つの JSON オブジェクト
    - `reviewer: "security-reviewer"`、`category: "security"`、`file` と `line_range` 必須
    - 前置き・後書き・コードフェンスなしの純粋な JSON で返す
```

### critic

```
Agent:
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
    - requirements.md / design.md の `## 既知の不足` セクションはレビュー対象外

    ## Council プロトコル
    1. 独立に計画整合性レビューを実施
    2. SendMessage で findings を code-reviewer・security-reviewer に共有
    3. 他の reviewer から SendMessage で共有された findings を検証し、同意/異議を返す
    4. 相互検証を経た最終 findings のみを報告
    5. このプロジェクトで繰り返し発見した計画乖離パターンは memory に保存

    ## Quote-first（長文 input 対策）
    plan/requirements.md / plan/design.md の判断根拠となる箇所を `quotes` 配列に抽出してから findings を返してください（各 finding に必須）。

    ## 出力（Coverage-first + JSON Schema）
    - 計画との乖離は confidence (0-100) と severity (critical/high/medium/low) を付与して**全件報告**
    - finding 時にフィルタリングしない（閾値カットは集約側で行う）
    - 出力は `facets/policies/council-output-schema.md` の JSON schema に従う 1 つの JSON オブジェクト
    - `reviewer: "critic"`、`category: "plan-alignment"`、各 finding の `quotes` 配列必須
    - 前置き・後書き・コードフェンスなしの純粋な JSON で返す
```

## 結果集約（JSON 入力 + 降格マトリクス自動適用）

各 reviewer は `facets/policies/council-output-schema.md` の schema に従う JSON オブジェクトを返す。集約側は以下のロジックで自動分類する。

### 降格マトリクス

| confidence | severity | 表記 |
|---|---|---|
| 90+ | critical / high | 🔴 Critical（必須修正） |
| 80-89 | high / medium | 🟡 Warning（推奨修正） |
| 60-79 | medium / low | ℹ️ Note（参考、サマリ集計外） |
| < 60 | - | 📦 Archive（履歴用、デフォルト非表示） |

### 集約擬似コード

```python
def classify(finding: dict) -> str:
    c = finding["confidence"]
    s = finding["severity"]
    if c >= 90 and s in ("critical", "high"):
        return "critical"
    if 80 <= c <= 89 and s in ("high", "medium"):
        return "warning"
    if 60 <= c <= 79 and s in ("medium", "low"):
        return "note"
    return "archive"

# 各 reviewer JSON を読み込んで集約
buckets = {"critical": [], "warning": [], "note": [], "archive": []}
for reviewer_json in [code_reviewer_json, security_reviewer_json, critic_json]:
    for f in reviewer_json["findings"]:
        f["_reviewer"] = reviewer_json["reviewer"]
        buckets[classify(f)].append(f)

passed = len(buckets["critical"]) == 0
```

### 出力レポート

```markdown
# 統合レビュー結果

## サマリ（reviewer 別）
- code-reviewer: <code-reviewer-json.summary>
- security-reviewer: <security-reviewer-json.summary>
- critic: <critic-json.summary>（計画なしの場合: スキップ）

## 🔴 Critical (X件)
- [code-reviewer] file:line — issue (confidence: N, severity: S)
  - fix: ...
- ...

## 🟡 Warning (X件)
- ...

## ℹ️ Note (X件、要約のみ)
- 件数のみ表示し詳細は折り畳み

## 📦 Archive (X件、デフォルト非表示)

## 良い点
- code-reviewer.good_points
- security-reviewer.good_points

## 総合判定
→ 🔴 Critical 0件 → 品質ゲート通過
→ 🔴 Critical あり → 修正必須（Step 5 へ）
（🟡 / ℹ️ / 📦 は通過判定の対象外、レポートには記録）
```

## 静的解析コマンド

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

# Rust ファイルがある場合
if [[ -f "Cargo.toml" ]]; then
  cargo clippy -- -D warnings
  cargo test
fi
```

## 完了時の出力フォーマット

```
✅ 品質ゲート通過（Review Council + Lint）

📊 コード品質
   🔴 Critical: なし
   🟡 Warning: X件
   ℹ️ Note: X件

🔒 セキュリティ
   🔴 Critical: なし
   🟡 Warning: X件
   ℹ️ Note: X件

📐 計画整合性
   🔴 Critical: なし（または: 計画なし - スキップ）
   🟡 Warning: X件
   ℹ️ Note: X件

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
