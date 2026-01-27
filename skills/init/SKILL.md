---
name: init
description: 新規プロジェクトの初期化 + Sisyphusモード有効化。spec/steering/にプロジェクト文脈（product.md, tech.md, structure.md）を対話的に作成する。
---

# プロジェクト初期化スキル

このスキルは新規プロジェクトのセットアップを対話的に行います。

## 実行手順

### Step 1: ディレクトリ作成

```bash
mkdir -p spec/steering
mkdir -p spec/standards
mkdir -p spec/plan
```

### Step 2: プロダクト文脈の設定

ユーザーに以下を質問し、`spec/steering/product.md`を作成：

**質問リスト:**
1. プロダクト名は？
2. 一言で何をするプロダクト？
3. 対象ユーザーは？
4. 解決したい課題は？（1-3個）
5. 主要機能は？（優先度付きで）

AskUserQuestionツールを使って質問してください。

### Step 3: 技術文脈の設定

ユーザーに以下を質問し、`spec/steering/tech.md`を作成：

**質問リスト:**
1. 使用言語/フレームワークは？
2. データベースは？
3. インフラ/デプロイ先は？
4. 設計原則や制約は？

### Step 4: 構造文脈の設定

ユーザーに以下を質問し、`spec/steering/structure.md`を作成：

**質問リスト:**
1. 既存のディレクトリ構造がある？（あれば`ls -la`で確認）
2. 命名規則の希望は？
3. テストの配置方針は？

既存プロジェクトの場合は、現在の構造を読み取って反映。

### Step 5: Sisyphusモード有効化

`spec/steering/`の設定が完了したら、以下を伝える：

```
✅ プロジェクト初期化完了！

作成されたファイル:
- spec/steering/product.md  - プロダクト文脈
- spec/steering/tech.md     - 技術文脈
- spec/steering/structure.md - 構造文脈

これでo-m-ccのエージェント（analyst, designer, planner等）が
プロジェクト文脈を理解した上で開発を進められます。

次のステップ:
- /o-m-cc:plan で仕様駆動開発を開始
- /o-m-cc:requirements で要件定義を作成
```

## テンプレート参照

以下のテンプレートを参考に作成：
- `${CLAUDE_PLUGIN_ROOT}/templates/steering/product.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/steering/tech.md`
- `${CLAUDE_PLUGIN_ROOT}/templates/steering/structure.md`

## 注意事項

- 既存の`spec/steering/`がある場合は上書き確認を行う
- ユーザーが「スキップ」と言ったら、該当セクションはテンプレートのままにする
- 最小限の質問で最大限の文脈を得ることを目指す
