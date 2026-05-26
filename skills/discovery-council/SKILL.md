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
!`ls -d */ 2>/dev/null || echo "(サブディレクトリなし)"`

### 技術スタック
!`ls package.json pyproject.toml Cargo.toml go.mod Gemfile setup.py requirements.txt 2>/dev/null || echo "(技術スタック検出なし — md+shell 等)"`

## Step 1: チーム作成

```
TeamDelete:
  team_name: "<既存チーム名>"  # エラーが出なければスキップ

TeamCreate:
  team_name: "discovery"
  description: "Discovery Council: 要件分析"
```

## Step 2: 3エージェント同時 spawn

3つのエージェントを同時 spawn:

| エージェント | 役割 | 出力先 |
|-------------|------|--------|
| researcher | 技術調査（既存実装、外部知見） | SendMessage で共有 |
| analyst | 要件分析 → requirements.md 作成 | plan/requirements.md |
| scout | ギャップ分析（漏れ・曖昧点の検出） | SendMessage で共有 |

→ **Agent prompt テンプレートは reference.md を Read して使用**

Council プロトコル: 独立に分析 → SendMessage で相互共有 → 相互検証 → analyst が最終統合

## Step 3: 曖昧点の確認（スキップ禁止）

Council の報告を集約した後、**曖昧点が残っていれば AskUserQuestion で確認する**。このステップはスキップしてはならない。

```
1. scout の報告から未解決の曖昧点を抽出
2. analyst の requirements.md ドラフトで「仮定」として記録された箇所を抽出
3. 曖昧点があれば → AskUserQuestion で具体的に質問（1回にまとめる）
4. 回答を requirements.md に反映
5. 曖昧点がなければ → そのまま次へ
```

**AskUserQuestion が使えない環境 or critical でない曖昧点の場合**: 曖昧点を `## 仮定` セクションに記録して先に進む。

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

<!-- AUTO-GOTCHAS -->

## 出力

plan/requirements.md
