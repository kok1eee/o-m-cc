# Discovery Council - Reference

> SKILL.md から参照される詳細テンプレート。必要時のみ Read する。

## Agent Prompt テンプレート

### researcher

```
Agent:
  subagent_type: "o-m-cc:researcher"
  name: "researcher"
  team_name: "discovery"
  description: "Discovery Council: 技術調査"
  prompt: |
    ## エージェント定義
    agents/researcher.md の指示に従ってください。

    ## コンテキスト
    - タスク: 以下の機能に関連する技術情報・実装パターン・既存知見を調査
    - 機能: $ARGUMENTS

    ## 入力
    - MEMORY.md（プロジェクトの蓄積知識）
    - コードベース内の既存実装（Glob/Grep）
    - 必要に応じて外部ドキュメント（WebSearch）

    ## Council プロトコル
    あなたは Discovery Council のメンバーです。
    1. 独立に技術調査を実施
    2. 知見が見つかったら SendMessage で analyst と scout の両方に共有
    3. analyst・scout から共有された findings を検証し、技術的に妥当かコメント
    4. 追加調査を依頼されたら対応
    5. [TRACKING] プレフィックス付きタスクは進捗管理用。無視すること

    ## 出力
    関連する知見が見つかったら SendMessage で analyst と scout に報告。
    見つからなければ「関連する既存知見なし」と報告。
```

### analyst

```
Agent:
  subagent_type: "o-m-cc:analyst"
  name: "analyst"
  team_name: "discovery"
  description: "Discovery Council: 要件分析"
  prompt: |
    ## エージェント定義
    agents/analyst.md の指示に従ってください。

    ## コンテキスト
    - タスク: 以下の機能の要件定義を作成
    - 機能: $ARGUMENTS

    ## 入力
    - ユーザーの機能要求（上記）
    - scout からのギャップ報告
    - researcher からの調査知見

    ## Council プロトコル
    あなたは Discovery Council のメンバーです（requirements.md の作成担当）。
    1. 独立に要件分析を実施
    2. 要件ドラフトの主要部分ができたら SendMessage で scout・researcher に共有しフィードバックを促す
    3. scout からのギャップ報告、researcher からの調査知見を SendMessage で受け取り反映
    4. 全員の findings を統合してから requirements.md を最終確定
    5. [TRACKING] プレフィックス付きタスクは進捗管理用。無視すること

    ## 確定前チェック
    requirements.md を Write する前に、scout と researcher からの報告を受信済みか確認。

    ## 出力
    - plan/requirements.md に要件定義を出力
```

### scout

```
Agent:
  subagent_type: "o-m-cc:scout"
  name: "scout"
  team_name: "discovery"
  description: "Discovery Council: ギャップ分析"
  prompt: |
    ## エージェント定義
    agents/scout.md の指示に従ってください。

    ## コンテキスト
    - タスク: 以下の機能について、ギャップ分析を実施
    - 機能: $ARGUMENTS

    ## 入力
    - ユーザーの元の要求（上記）
    - コードベースを直接調査（Glob, Grep, Read）

    ## Council プロトコル
    あなたは Discovery Council のメンバーです。
    1. 独立にギャップ分析を実施
    2. ギャップを発見したら SendMessage で analyst・researcher に共有
    3. researcher から技術知見を SendMessage で受け取ったら分析に反映
    4. analyst の要件ドラフトを検証し、漏れがあればフィードバック
    5. [TRACKING] プレフィックス付きタスクは進捗管理用。無視すること

    ## 原則
    - requirements.md の完成を待たず、ユーザーの要求とコードベースから直接分析を開始
    - Critical な曖昧点は AskUserQuestion で確認（使えない環境や critical でない場合は仮定で進む）
    - 回答がなければ仮定を記録して進む
    - フローをブロックしない

    ## 出力
    - 発見した漏れ・補完事項を SendMessage で analyst に報告
```
