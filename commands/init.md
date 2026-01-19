---
description: "新規プロジェクトの初期化 + Sisyphusモード有効化"
argument-hint: "[project-name]"
allowed-tools: [Read, Bash, Write, Edit, AskUserQuestion]
model: sonnet
---

# /o-m-cc:init - Project Initialization with Sisyphus

**公式init + Sisyphusモード有効化を一括実行**

引数を省略した場合、カレントディレクトリ名をプロジェクト名として使用します。

---

## Step 1: CLAUDE.md の存在確認

```bash
if [ -f "CLAUDE.md" ]; then
  echo "📄 CLAUDE.md が既に存在します"
else
  echo "📄 CLAUDE.md を新規作成します"
fi
```

- **存在する** → Step 2 へ（Sisyphusセクションのみ追加）
- **存在しない** → CLAUDE.md を作成してから Step 2 へ

### CLAUDE.md 作成（存在しない場合のみ）

```bash
PROJECT_NAME="${1:-$(basename $(pwd))}"

cat > CLAUDE.md << 'EOF'
# [PROJECT_NAME] - Project Configuration

## プロジェクト概要
<!-- プロジェクトの説明を記述 -->

## 技術スタック
<!-- 使用している言語・フレームワーク・ライブラリなど -->

## 開発ガイドライン
<!-- プロジェクト特有の開発標準・コーディング規約など -->

EOF

# プロジェクト名を置換
sed -i '' "s/\[PROJECT_NAME\]/$PROJECT_NAME/g" CLAUDE.md
```

---

## Step 2: 使用言語の確認

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

## Step 3: プラグインのインストール

選択された言語に応じてスクリプトを実行：

```bash
# プラグインインストールスクリプトを実行
bash "${CLAUDE_PLUGIN_ROOT}/scripts/install-plugins.sh" [オプション]
```

**オプション対応:**
| 選択 | オプション |
|------|-----------|
| TypeScript/JavaScript/React | `--ts` |
| Python | `--py` |
| Go | `--go` |
| Rust | `--rust` |

---

## Step 4: CLAUDE.md に Sisyphus セクション追加

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-claude-md.sh" CLAUDE.md
```

---

## Step 5: hooks の確認

```bash
ls -la "${CLAUDE_PLUGIN_ROOT}/hooks/"
```

---

## 完了時の出力

```
╔══════════════════════════════════════════════════════════╗
║  ✅ o-m-cc 初期化完了                                    ║
╚══════════════════════════════════════════════════════════╝

📄 CLAUDE.md: 作成/更新済み
📦 プラグイン: インストール済み
🔄 Sisyphus: 有効化済み（タスク完了まで自動継続）

🎯 次のステップ:
   /o-m-cc:plan <task>      - 計画から始める（複雑なタスク）
   /o-m-cc:ultrawork <task> - 直接実行（シンプルなタスク）
```

---

**Step 1 から開始してください。**
