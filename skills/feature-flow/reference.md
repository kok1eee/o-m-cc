# Feature Flow - Reference

> SKILL.md から参照される詳細テンプレート。Phase B でのみ Read する。

## Mode 1 Agent Prompts（外向き並列調査）

### market-researcher

```
Agent:
  subagent_type: "o-m-cc:market-researcher"
  name: "market-researcher"
  team_name: "feature-flow-prior-art"
  description: "Phase B (Mode 1): 商用 SaaS 調査"
  prompt: |
    ## エージェント定義
    agents/market-researcher.md の指示に従ってください。

    ## コンテキスト
    - タスク: Phase A で確定したユーザーストーリーから、世界に同じ問題を解決する商用 SaaS / 既製アプリを調査
    - 機能: $ARGUMENTS
    - WHO: <Phase A の WHO>
    - WHEN: <Phase A の WHEN>
    - GOAL: <Phase A の GOAL>

    ## 入力
    - ユーザーストーリー（上記）
    - WebSearch / WebFetch（外部知見）

    ## 並列メンバー
    あなたは Phase B 並列 3 エージェントの 1 人です:
    - market-researcher（あなた）: 商用 SaaS
    - oss-scout: OSS / GitHub
    - pattern-observer: UI/UX

    独立に調査してください。SendMessage は使わなくて構いません。
    メインエージェントが 3 者の出力を統合します。

    ## 出力
    agents/market-researcher.md の出力フォーマットに従って、レポートを返してください。
    特に「作る vs 買う」判断材料と、要件への含意を明示すること。
```

### oss-scout

```
Agent:
  subagent_type: "o-m-cc:oss-scout"
  name: "oss-scout"
  team_name: "feature-flow-prior-art"
  description: "Phase B (Mode 1): OSS 調査"
  prompt: |
    ## エージェント定義
    agents/oss-scout.md の指示に従ってください。

    ## コンテキスト
    - タスク: Phase A のユーザーストーリーから、フォーク・依存・参考にできる OSS / GitHub 実装を調査
    - 機能: $ARGUMENTS
    - WHO: <Phase A の WHO>
    - WHEN: <Phase A の WHEN>
    - GOAL: <Phase A の GOAL>

    ## 入力
    - ユーザーストーリー（上記）
    - WebSearch / WebFetch（GitHub / awesome リスト等）

    ## 並列メンバー
    あなたは Phase B 並列 3 エージェントの 1 人です。独立調査でよい。

    ## 出力
    agents/oss-scout.md の出力フォーマットに従ってください。
    各候補について「依存 / フォーク / 参考 / 不採用」の判定を必ず付与すること。
```

### pattern-observer

```
Agent:
  subagent_type: "o-m-cc:pattern-observer"
  name: "pattern-observer"
  team_name: "feature-flow-prior-art"
  description: "Phase B (Mode 1): UI/UX パターン観察"
  prompt: |
    ## エージェント定義
    agents/pattern-observer.md の指示に従ってください。

    ## コンテキスト
    - タスク: Phase A のユーザーストーリーから、類似サービスがどう操作させているかを観察
    - 機能: $ARGUMENTS
    - WHO: <Phase A の WHO>
    - WHEN: <Phase A の WHEN>
    - GOAL: <Phase A の GOAL>

    ## 入力
    - ユーザーストーリー（上記）
    - 公式デモ・スクリーンショット・レビュー記事

    ## 並列メンバー
    あなたは Phase B 並列 3 エージェントの 1 人です。独立観察でよい。

    ## 出力
    agents/pattern-observer.md の出力フォーマットに従ってください。
    共通パターン / 差別化パターン / アンチパターンを必ず分類すること。
```

---

## Mode 2 Agent Prompts（内向き並列調査）

### code-explorer

```
Agent:
  subagent_type: "o-m-cc:code-explorer"
  name: "code-explorer"
  team_name: "feature-flow-prior-art"
  description: "Phase B (Mode 2): 既存実装トレース"
  prompt: |
    ## エージェント定義
    agents/code-explorer.md の指示に従ってください。

    ## コンテキスト
    - タスク: 既存コードベースから、機能 $ARGUMENTS と類似する既存機能を発見しエントリポイントから実装まで辿る
    - WHO: <Phase A の WHO>
    - WHEN: <Phase A の WHEN>
    - GOAL: <Phase A の GOAL>

    ## 入力
    - ユーザーストーリー（上記）
    - コードベース（Glob / Grep / Read のみ。WebSearch 禁止）

    ## 並列メンバー
    あなたは Phase B 並列 3 エージェントの 1 人です:
    - code-explorer（あなた）: 個別機能のトレース
    - architecture-mapper: 抽象境界の地図
    - convention-scout: 命名・配置・テスト

    独立調査でよい。

    ## 出力
    agents/code-explorer.md の出力フォーマットに従ってください。
    必ず「重要ファイル（メインが Read すべき）」リストを最後に含めること。
```

### architecture-mapper

```
Agent:
  subagent_type: "o-m-cc:architecture-mapper"
  name: "architecture-mapper"
  team_name: "feature-flow-prior-art"
  description: "Phase B (Mode 2): 抽象境界マッピング"
  prompt: |
    ## エージェント定義
    agents/architecture-mapper.md の指示に従ってください。

    ## コンテキスト
    - タスク: 既存コードベースのレイヤー構造・モジュール境界・データモデルを把握し、機能 $ARGUMENTS の配置候補を提示
    - WHO: <Phase A の WHO>
    - WHEN: <Phase A の WHEN>
    - GOAL: <Phase A の GOAL>

    ## 入力
    - ユーザーストーリー（上記）
    - コードベース（Glob / Grep / Read のみ）

    ## 並列メンバー
    あなたは Phase B 並列 3 エージェントの 1 人です。独立調査でよい。

    ## 出力
    agents/architecture-mapper.md の出力フォーマットに従ってください。
    新機能の配置候補を必ず 1-2 個提示すること。
```

### convention-scout

```
Agent:
  subagent_type: "o-m-cc:convention-scout"
  name: "convention-scout"
  team_name: "feature-flow-prior-art"
  description: "Phase B (Mode 2): 命名・配置・テスト規約抽出"
  prompt: |
    ## エージェント定義
    agents/convention-scout.md の指示に従ってください。

    ## コンテキスト
    - タスク: 既存コードベースの命名規則・ファイル配置・テストパターン・コーディング規約を抽出
    - 機能: $ARGUMENTS

    ## 入力
    - CLAUDE.md / README / lint 設定 / コードベース全般
    - WebSearch 禁止

    ## 並列メンバー
    あなたは Phase B 並列 3 エージェントの 1 人です。独立調査でよい。

    ## 出力
    agents/convention-scout.md の出力フォーマットに従ってください。
    「守るべき最低限」を 5 項目以内に絞って末尾に提示すること。
```

---

## 統合レポートテンプレート

メインエージェントが Phase B 完了後、3 エージェントの出力を統合する際のフォーマット。

```markdown
## Phase B - 先行事例調査 統合レポート

### Mode: <1 / 2>

### 各エージェントの主要発見
<エージェント別に 3-5 行で要約。詳細はエージェント原文を参照>

### 統合所見
- **採用すべきパターン**: ...
- **避けるべきパターン**: ...
- **「作る vs 既存活用」の暫定判断**: 作る / 買う / OSS 採用 / 既存拡張 / 撤退
- **未解決の論点**: <あれば>
```

---

## Reader Test 失敗時の対応

Reader が以下を返した場合、対応方針:

| Reader の応答 | 対応 |
|---|---|
| WHO / WHEN / GOAL の理解が spec とズレている | Phase A に戻って文言を修正、再 Reader Test |
| INPUT / OUTPUT / STATE が読み取れない | Phase C に戻って具体性を追加、再 Reader Test |
| DONE の判定基準が不明確 | Phase D に戻って観測可能な条件に書き直す、再 Reader Test |
| 「Phase B の方針」が見えない | Phase B のサマリーを spec に厚めに転記、再 Reader Test |
| 全部 OK だが「もう少しサンプルが欲しい」 | 任意。spec に補足例を追加。Reader Test は再実行不要 |

3 回 Reader Test しても解釈ズレが残る場合、ユーザーに「現状で確定するか / 仕切り直すか」を問う。
