---
name: review
description: "Agent Teams で code-reviewer, security-reviewer, critic を並列実行してコード品質・セキュリティ・計画整合性をチェック。Council パターンで相互検証し偽陽性を排除。コード変更後、PR 作成前、実装の妥当性を確認したいときに使う。「レビューして」「コードを確認して」「PR 出す前にチェック」「セキュリティ大丈夫？」で発動。"
argument-hint: "[specific files or 'all']"
allowed-tools: [Read, Glob, Grep, Bash, AskUserQuestion, Agent, TeamCreate, TeamDelete, SendMessage]
model: sonnet
context: fork
---

# Review Command - コードレビュー（Review Council）

コード品質・セキュリティ・計画整合性を **Review Council**（3 reviewer の相互検証）でチェックします。

## 対象

$ARGUMENTS

---

## HIGH SIGNAL ポリシー（全 reviewer 共通）

**HIGH SIGNAL の問題のみ報告する。** 以下は偽陽性として報告しない：

- 変更前から存在する既存の問題（今回の変更で導入されたものだけ報告）
- linter / 静的解析が捕まえる問題（linter を実行して確認する必要はない）
- シニアエンジニアが指摘しないような些末な nitpick
- コードスタイルや品質の一般的な懸念（CLAUDE.md で明示的に要求されていない限り）
- lint ignore コメントで明示的に無視されている問題
- 特定の入力や状態に依存する潜在的な問題
- diff の外のコンテキストなしでは検証できない問題

**フラグすべき問題：**
- コンパイル/パースが失敗する（構文エラー、型エラー、import 漏れ、未解決の参照）
- 入力に関係なく確実に誤った結果を出す（明確なロジックエラー）
- CLAUDE.md の明確な違反（該当ルールを引用できるもの）
- 確実なセキュリティ脆弱性（OWASP Top 10）

**確信がない問題はフラグしない。** 偽陽性は信頼を損ない、レビュー時間を浪費する。

---

## 実行フロー

### Step 1: 変更差分の取得

```bash
jj diff  # または git diff
```

### Step 2: CLAUDE.md の収集

変更ファイルに適用される CLAUDE.md をすべて収集する：

```bash
# ルートの CLAUDE.md
cat CLAUDE.md 2>/dev/null

# 変更ファイルの親ディレクトリの CLAUDE.md
# 例: src/utils/foo.py が変更 → src/CLAUDE.md, src/utils/CLAUDE.md を確認
```

> CLAUDE.md が存在しない場合はスキップ。ファイルのスコープに適用される CLAUDE.md のみを各 reviewer に渡す。

### Step 3: Review Council 作成

```
TeamCreate:
  team_name: "review-council"
  description: "Code quality + Security + Plan compliance review"
```

### Step 4: Council メンバー spawn

**3つの reviewer を Agent ツールで同時 spawn。** 各 reviewer は独立にレビューした後、SendMessage で findings を他の reviewer と共有し相互検証する。

```
1. Agent:
   subagent_type: "o-m-cc:code-reviewer"
   description: "Review Council: コード品質"
   prompt: |
     ## エージェント定義
     agents/code-reviewer.md の指示に従ってください。

     ## 参照ポリシー
     facets/policies/confidence-scoring.md を Read して適用してください。

     ## コンテキスト
     - タスク: $ARGUMENTS のコードレビュー
     - スコープ: コード品質（バグ、ロジックエラー）+ CLAUDE.md コンプライアンス

     ## CLAUDE.md コンプライアンス
     以下の CLAUDE.md ルールに変更コードが準拠しているかチェック：
     [収集した CLAUDE.md の内容を含める]
     違反がある場合は、該当ルールを引用して報告すること。

     ## HIGH SIGNAL ポリシー
     以下は偽陽性として報告しない：
     - 変更前から存在する既存の問題
     - linter が捕まえる問題
     - 些末な nitpick、コードスタイルの好み
     - lint ignore で明示的に無視されている問題
     確信がない問題はフラグしない。

     ## 入力
     [変更差分を含める]

     ## Council プロトコル
     1. 独立にレビューを実施
     2. SendMessage で findings を security-reviewer・critic に共有
     3. 他の reviewer から SendMessage で共有された findings を検証し、同意/異議を返す
        - 「変数が未定義」→ 実際にコード内で確認して同意/異議
        - 「CLAUDE.md 違反」→ ルールのスコープを確認して同意/異議
     4. 相互検証を経た最終 findings のみを報告

     ## 出力フォーマット
     各 issue に以下を含める：
     - 問題の説明
     - フラグ理由（例: "CLAUDE.md 違反: [ルール引用]", "バグ", "ロジックエラー"）
     - Confidence スコア（0-100）
     - 他の reviewer の検証結果（同意/異議）
     - Confidence 80+ の問題のみ Critical/Warning で報告

2. Agent:
   subagent_type: "o-m-cc:security-reviewer"
   description: "Review Council: セキュリティ"
   prompt: |
     ## エージェント定義
     agents/security-reviewer.md の指示に従ってください。

     ## 参照ポリシー
     facets/policies/confidence-scoring.md を Read して適用してください。

     ## コンテキスト
     - タスク: $ARGUMENTS のセキュリティレビュー
     - スコープ: OWASP Top 10 + 変更コードに限定したセキュリティ分析

     ## HIGH SIGNAL ポリシー
     以下は偽陽性として報告しない：
     - 変更前から存在する既存の脆弱性
     - 一般的なセキュリティの懸念（具体的な攻撃ベクトルを示せないもの）
     - 特定の入力や状態に依存する潜在的な脆弱性
     - lint ignore で明示的に無視されている問題
     確信がない問題はフラグしない。

     ## 入力
     [変更差分を含める]

     ## Council プロトコル
     1. 独立にセキュリティレビューを実施
     2. SendMessage で findings を code-reviewer・critic に共有
     3. 他の reviewer から SendMessage で共有された findings を検証し、同意/異議を返す
        - セキュリティ観点から他の findings にコメント
        - コード品質の findings にセキュリティ影響があれば補足
     4. 相互検証を経た最終 findings のみを報告

     ## 出力フォーマット
     各 issue に以下を含める：
     - 問題の説明
     - フラグ理由（例: "SQL Injection", "XSS", "認証バイパス"）
     - Confidence スコア（0-100）
     - 他の reviewer の検証結果（同意/異議）
     - Confidence 80+ の問題のみ Critical/Warning で報告

3. Agent:
   subagent_type: "o-m-cc:critic"
   description: "Review Council: 計画整合性"
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
        - 計画・設計の観点から他の findings にコメント
        - スコープ逸脱の可能性があれば指摘
     4. 相互検証を経た最終 findings のみを報告

     ## 出力フォーマット
     各 issue に以下を含める：
     - 問題の説明
     - フラグ理由（例: "計画との乖離: [該当箇所]", "スコープ逸脱"）
     - Confidence スコア（0-100）
     - 他の reviewer の検証結果（同意/異議）
     - 計画との乖離があれば Critical/Warning で報告
```

### Step 5: 結果の集約

Council メンバーからの相互検証済み findings を集約：

#### 集約ルール

- `all("Critical なし")` → マージ可能
- `any("Critical あり")` → 修正必須。Step 6 へ

```markdown
# Review Council 結果

## コード品質（code-reviewer）
- Critical: X件
- Warning: X件

## セキュリティ（security-reviewer）
- Critical: X件
- Warning: X件

## 計画整合性（critic）
- Critical: X件（計画なしの場合: スキップ）
- Warning: X件

## 総合判定
→ all("Critical なし"): マージ可能
→ any("Critical あり"): 修正必須
```

### Step 6: Critical 発見時の自動修正

Critical が見つかった場合、**自動で修正を試みる**（ノンストップ原則）：

1. 問題箇所を特定し、修正を適用
2. `/review` を再実行して修正を確認

---

## 完了時の出力

### Critical なしの場合

```
✅ Review Council 完了

📊 コード品質
   🟢 Critical: なし
   🟡 Warning: X件

🔒 セキュリティ
   🟢 Critical: なし
   🟡 Warning: X件

📐 計画整合性
   🟢 Critical: なし（または: 計画なし - スキップ）
   🟡 Warning: X件

→ マージ可能
```

### Critical ありの場合

```
⚠️ Review Council 完了

📊 コード品質
   🔴 Critical: X件 ← 要修正
   🟡 Warning: X件

🔒 セキュリティ
   🔴 Critical: X件 ← 要修正
   🟡 Warning: X件

📐 計画整合性
   🔴 Critical: X件 ← 要修正
   🟡 Warning: X件

→ 修正が必要
```

Critical がある場合は、問題点と修正方法を具体的に提案してください。

---

**Review Council を開始します。変更差分と CLAUDE.md を確認し、3 reviewer を並列 spawn してください。**
