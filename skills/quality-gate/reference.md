# Quality Gate - Reference

> SKILL.md から参照される詳細テンプレート。必要時のみ Read する。

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

    ## 出力
    - Confidence 80+ の問題のみ Critical/Warning で報告
    - agents/code-reviewer.md の出力フォーマットに従う
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

    ## 出力
    - Confidence 80+ の問題のみ Critical/Warning で報告
    - agents/security-reviewer.md の出力フォーマットに従う
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

    ## 出力
    - 計画との乖離があれば Critical/Warning で報告
    - agents/critic.md の出力フォーマットに従う
```

## 結果集約テンプレート

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
