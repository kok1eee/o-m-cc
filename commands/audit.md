---
description: エージェント・コマンドの品質監査
allowed-tools: [Task, Read, Glob, Grep, AskUserQuestion]
---

# /o-m-cc:audit — 品質監査

指定された対象（agent / command / hook）を監査し、品質レポートを生成する。

## 使用例

```
/o-m-cc:audit agents/planner.md
/o-m-cc:audit commands/plan.md
/o-m-cc:audit all agents
```

## 引数

`$ARGUMENTS` — 監査対象のファイルパスまたはカテゴリ

## 監査プロセス

### Step 1: 対象の特定

引数に応じて対象を決定：
- ファイルパス指定 → そのファイル
- `all agents` → `agents/*.md` 全体
- `all commands` → `commands/*.md` 全体
- 引数なし → AskUserQuestion で確認

### Step 2: チェック項目

#### エージェント (`agents/*.md`)

| チェック | 基準 |
|---------|------|
| frontmatter | name, description, tools, model が定義されている |
| description 品質 | 「何をするか + いつ使うか」の2要素が含まれる |
| 役割定義 | 具体的なタスクが明記されている |
| 出力フォーマット | 出力の形式が定義されている |
| capabilities.md | エージェント一覧に登録されている |

#### コマンド (`commands/*.md`)

| チェック | 基準 |
|---------|------|
| frontmatter | description, allowed-tools が定義されている |
| プロセス | 実行ステップが明確 |
| 出力 | 何を生成するか明記 |
| エラー処理 | 異常系の対応が定義されている |

#### フック (`hooks/*.sh`)

| チェック | 基準 |
|---------|------|
| set -euo pipefail | 安全なシェル設定 |
| hooks.json 登録 | フックイベントに登録されている |
| エラーハンドリング | 失敗時に exit 0（フックがブロッカーにならない） |

### Step 3: レポート生成

```markdown
## 監査結果: [対象名]

### 評価
[1-2文の総合評価]

### 問題点
1. **[カテゴリ]** (ファイル:行)
   - 現状: [何が問題か]
   - 推奨: [どうすべきか]

### 良い点
- [具体的な強み]

### 改善提案
1. [アクション] — [期待効果]
```

### Step 4: レポート出力

監査結果をレポートとして出力する。修正はユーザーが別途指示する。
