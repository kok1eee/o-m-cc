---
name: discovery-council
description: "3エージェント（researcher, analyst, scout）による並列要件分析 Council。peer-to-peer で相互検証し requirements.md を確定。「要件を整理して」「要件定義して」「現状分析して」「要件をまとめて」で発動。"
argument-hint: "<feature description>"
allowed-tools: [Agent, TeamCreate, TeamDelete, SendMessage, TaskCreate, TaskUpdate, Read, Write, Edit, AskUserQuestion, Glob, Grep, WebSearch, WebFetch]
model: sonnet
effort: high
context: fork
---

# Discovery Council - 並列要件分析

3エージェント（researcher, analyst, scout）が peer-to-peer で相互検証し、requirements.md を確定する。

## 機能

$ARGUMENTS

## プロジェクト状態（動的注入）

### ディレクトリ構造
!`find . -maxdepth 2 -type f \( -name "*.py" -o -name "*.ts" -o -name "*.js" -o -name "*.go" -o -name "*.rs" -o -name "*.java" -o -name "*.sh" \) 2>/dev/null | head -30 || echo "ソースファイルなし"`

### 技術スタック
!`ls package.json pyproject.toml Cargo.toml go.mod Gemfile setup.py requirements.txt 2>/dev/null || echo "検出なし"`

## Headless モード

`CLAUDE_NON_INTERACTIVE=1` または `-p` モードで実行されている場合、AskUserQuestion を使わない。scout の曖昧点は仮定を記録して進む。

---

## Step 1: チーム作成

```
TeamDelete:
  team_name: "<既存チーム名>"  # エラーが出なければスキップ

TeamCreate:
  team_name: "discovery"
  description: "Discovery Council: 要件分析"
```

## Step 2: 3エージェント同時 spawn

```
1. Agent:
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

2. Agent:
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

3. Agent:
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
     - Critical な曖昧点は AskUserQuestion で確認（Headless モードでは仮定で進む）
     - 回答がなければ仮定を記録して進む
     - フローをブロックしない

     ## 出力
     - 発見した漏れ・補完事項を SendMessage で analyst に報告
```

## Step 3: 曖昧点の確認（スキップ禁止）

Council の報告を集約した後、**曖昧点が残っていれば AskUserQuestion で確認する**。このステップはスキップしてはならない。

```
1. scout の報告から未解決の曖昧点を抽出
2. analyst の requirements.md ドラフトで「仮定」として記録された箇所を抽出
3. 曖昧点があれば → AskUserQuestion で具体的に質問（1回にまとめる）
4. 回答を requirements.md に反映
5. 曖昧点がなければ → そのまま次へ
```

**Headless モードでは**: 曖昧点を `## 仮定` セクションに記録して先に進む。

## Step 4: チーム終了

全エージェントの報告完了後、チームを削除する。

```
TeamDelete
```

## Gotchas

- **researcher が外部検索に時間を使いすぎて analyst が待ちぼうけ**: researcher は `background: true` で非同期。analyst と scout は researcher を待たずに独立して分析を開始すべき
- **scout が曖昧点を発見しても analyst に伝わらない**: SendMessage の recipient 名を正確に。name が間違っていると silent loss する
- **要件が広すぎてスコープ爆発**: scout が IN/OUT SCOPE を明確にしないまま analyst が全部盛りの requirements.md を書く。scout の分析を待ってから最終化する
- **既存プロジェクトの文脈を無視**: 動的注入でプロジェクト構造は把握済みだが、CLAUDE.md の開発ガイドラインも必ず確認する

## 出力

plan/requirements.md
