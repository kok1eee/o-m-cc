---
description: "Sisyphusモードを有効化（CLAUDE.mdに原則を追加）"
argument-hint: ""
allowed-tools: [Read, Bash, AskUserQuestion]
model: sonnet
---

# Sisyphus - モード有効化

**プロジェクトに Sisyphus モードを有効化します。**

一度有効化すれば、以降は自動的に「タスク完了まで止まらない」モードで動作します。

---

## Step 1: 使用言語の確認

**AskUserQuestion** で使用する言語を確認（複数選択可）：

```
質問: 普段使用するプログラミング言語は？（LSPプラグインの選択用）
multiSelect: true

選択肢:
1. TypeScript/JavaScript/React
2. Python
3. Go
4. Rust
```

---

## Step 2: プラグインのインストール

選択された言語に応じてスクリプトを実行：

```bash
# プラグインインストールスクリプトを実行
# 選択に応じてオプションを追加: --ts, --py, --go, --rust
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh" [オプション]
```

**オプション対応:**
| 選択 | オプション |
|------|-----------|
| TypeScript/JavaScript/React | `--ts` |
| Python | `--py` |
| Go | `--go` |
| Rust | `--rust` |

**例:**
```bash
# TypeScript と Python を選択した場合
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh" --ts --py
```

---

## Step 3: CLAUDE.md の設定

**スクリプトで CLAUDE.md に Sisyphus セクションを追加/更新:**

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-claude-md.sh" CLAUDE.md
```

このスクリプトは：
- CLAUDE.md が存在しない → 新規作成
- Sisyphus セクションがない → 末尾に追加
- Sisyphus セクションがある → 最新内容に更新

**マーカー形式:**
```markdown
<!-- o-m-cc:sisyphus:start -->
## Sisyphus Mode
...
<!-- o-m-cc:sisyphus:end -->
```

---

## Step 4: hooks の確認

o-m-cc プラグインをインストールすると、Stop Hook が自動的に有効になります。

**自動で有効になる機能:**
- `<promise>DONE</promise>` 検知でループ終了
- code-reviewer 未実行なら block
- Critical な問題があれば block
- max_iterations（デフォルト: 50）で安全弁

```bash
# hooks が有効か確認
ls -la "${CLAUDE_PLUGIN_ROOT}/hooks/"
```

---

## 完了時の出力

```
✅ Sisyphus モード有効化完了

📦 インストール済みプラグイン:
   - frontend-design
   - feature-dev
   - code-simplifier
   - security-guidance
   - [選択した LSP]

📄 CLAUDE.md に Sisyphus セクションを追加/更新しました

🔄 Stop Hook が有効です（タスク完了まで自動継続）

以降、このプロジェクトでは自動的に
「タスク完了まで止まらない」モードで動作します。
```

---

**Step 1 から開始してください。AskUserQuestion で使用言語を確認します。**
