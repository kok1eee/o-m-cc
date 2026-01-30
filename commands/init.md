---
description: "プロジェクト固有の初期化（CLAUDE.md, spec/, Sisyphusルール）"
argument-hint: "[project-name]"
allowed-tools: [Read, Bash, Write, Edit, Glob, Grep, AskUserQuestion, Task]
model: sonnet
---

# /o-m-cc:init - Project Initialization

**プロジェクト固有のセットアップ（毎回実行）**

引数を省略した場合、カレントディレクトリ名をプロジェクト名として使用します。

---

## Step 1: プロジェクトタイプの判定

ソースコードの存在を確認して、既存/新規を判定：

```bash
# ソースコードの存在チェック
if ls *.py *.js *.ts *.go *.rs *.java src/ lib/ app/ 2>/dev/null | head -1 > /dev/null; then
  echo "📁 既存プロジェクトを検出"
  PROJECT_TYPE="existing"
else
  echo "📁 新規プロジェクトとして初期化"
  PROJECT_TYPE="new"
fi
```

判定結果を記憶して、以降のステップで分岐。

---

## Step 2: CLAUDE.md の存在確認

```bash
if [ -f "CLAUDE.md" ]; then
  echo "📄 CLAUDE.md が既に存在します"
else
  echo "📄 CLAUDE.md を新規作成します"
fi
```

- **存在する** → 次のステップへ
- **存在しない** → CLAUDE.md を作成

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

## Step 3: Spec セットアップ（プロジェクトタイプで分岐）

### 既存プロジェクトの場合: 自動分析

コードベースを分析して `spec/` を自動生成：

```
以下を自動で分析・生成します：

1. 技術スタック検出
   - package.json / pyproject.toml / go.mod / Cargo.toml を解析
   - フレームワーク・ライブラリを特定

2. ディレクトリ構造マッピング
   - src/, lib/, app/ などの構造を分析
   - 命名規則を推測

3. コーディングパターン抽出
   - 既存コードからパターンを学習
   - 規約を推測

生成ファイル:
  spec/steering/product.md   ← README.md から推測
  spec/steering/tech.md      ← 依存関係から生成
  spec/steering/structure.md ← ディレクトリ構造
  spec/standards/learned/patterns.md ← 既存コードから抽出
```

**実行方法:**
1. Glob で主要ファイルを検出（package.json, README.md, src/ など）
2. Read で内容を取得
3. 分析結果を spec/ 配下に Write

### 新規プロジェクトの場合: テンプレートセットアップ

Standards と Steering を両方セットアップする（デフォルト動作）：

```bash
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-project.sh" --all
```

**セットアップ後の構造:**
```
spec/
├── standards/    # 技術規約（実装時に参照）
│   ├── global/
│   ├── frontend/
│   ├── backend/
│   └── testing/
└── steering/     # プロジェクト文脈（計画時に参照）
    ├── product.md
    ├── tech.md
    └── structure.md
```

---

## Step 4: Sisyphus ルールを追加

`spec/rules/sisyphus.md` を作成（verup時は上書き）：

```bash
mkdir -p spec/rules
cp "${CLAUDE_PLUGIN_ROOT}/templates/rules/sisyphus.md" spec/rules/sisyphus.md
echo "✅ Sisyphus ルールを spec/rules/sisyphus.md に配置"
```

---

## Step 5: .gitignore の設定

o-m-cc のランタイムファイルを .gitignore に追加：

```bash
# 追加するエントリ
GITIGNORE_ENTRIES=(
  "# Claude Code"
  ".claude/"
  ""
  "# o-m-cc runtime files"
  "spec/sisyphus-state.json"
  "spec/.completed-tasks"
  "spec/plan/logs/"
  "spec/plan/handoff.yaml"
)

# .gitignore が存在しない場合は作成
touch .gitignore

# 各エントリを追加（重複しない場合のみ）
for entry in "${GITIGNORE_ENTRIES[@]}"; do
  if ! grep -qF "$entry" .gitignore; then
    echo "$entry" >> .gitignore
  fi
done

echo "✅ .gitignore に o-m-cc ランタイムファイルを追加"
```

---

## 完了時の出力 + 次のステップ提案

プロジェクトの状態に応じた完了メッセージを表示：

### 既存プロジェクト

```
╔══════════════════════════════════════════════════════════╗
║  ✅ o-m-cc 初期化完了                                    ║
╚══════════════════════════════════════════════════════════╝

📄 CLAUDE.md: 作成/更新済み
🔄 Sisyphus: spec/rules/sisyphus.md に配置

🎯 次のステップ:
   「○○を修正して」「○○機能を追加して」など、
   やりたいことをそのまま伝えてください。
```

### 新規プロジェクト

```
╔══════════════════════════════════════════════════════════╗
║  ✅ o-m-cc 初期化完了                                    ║
╚══════════════════════════════════════════════════════════╝

📄 CLAUDE.md: 作成/更新済み
🔄 Sisyphus: spec/rules/sisyphus.md に配置
📐 Standards: spec/standards/ にセットアップ済み
📋 Steering: spec/steering/ にセットアップ済み
```

```
🎯 次のステップ:
   「○○を修正して」「○○機能を追加して」など、
   やりたいことをそのまま伝えてください。
```

---

**Step 1 から自動実行してください。**
