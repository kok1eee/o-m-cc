---
description: "プロジェクト固有の初期化（CLAUDE.md, spec/, Sisyphusルール）。新規プロジェクト開始時や既存プロジェクトにo-m-ccを導入する際に使用。"
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

## Step 4: ルールファイルとデフォルトエージェントを追加

`spec/rules/` にルールを配置し、`.claude/agents/` にデフォルトエージェントを配置（verup時は上書き）：

```bash
mkdir -p spec/rules
cp "${CLAUDE_PLUGIN_ROOT}/templates/rules/sisyphus.md" spec/rules/sisyphus.md
cp "${CLAUDE_PLUGIN_ROOT}/templates/rules/plan-or-act.md" spec/rules/plan-or-act.md
echo "✅ Sisyphus ルールを spec/rules/sisyphus.md に配置"
echo "✅ Plan or Act ルールを spec/rules/plan-or-act.md に配置"

mkdir -p .claude/agents
cp "${CLAUDE_PLUGIN_ROOT}/templates/agents/sisyphus.md" .claude/agents/sisyphus.md
echo "✅ Sisyphus デフォルトエージェントを .claude/agents/sisyphus.md に配置"
echo ""
echo "💡 デフォルトエージェントとして有効にするには:"
echo "   .claude/settings.json に \"agent\": \"sisyphus\" を追加"
echo "   または claude --agent sisyphus で起動"
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
  "spec/plan/HANDOVER.md"
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

## Step 6: 推奨パーミッションの設定

`.claude/settings.json` に o-m-cc がスムーズに動作するための推奨パーミッションを追加。
Sisyphus Loop で自動実行中に権限承認で止まるのを防ぐ。

**既に `.claude/settings.json` が存在する場合は、既存設定にマージする。存在しない場合は新規作成する。**

### 追加する推奨パーミッション

```json
{
  "permissions": {
    "allow": [
      "Read(spec/**)",
      "Write(spec/**)",
      "Edit(spec/**)",
      "Read(agents/**)",
      "Read(commands/**)",
      "Read(templates/**)",
      "Glob(**)",
      "Grep(**)"
    ]
  }
}
```

### 実装方法

1. `.claude/settings.json` を Read で読み込む（なければ `{}` として扱う）
2. 既存の `permissions.allow` があればマージ（重複排除）
3. Write で書き戻す

```
echo "✅ 推奨パーミッションを .claude/settings.json に追加"
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
🔄 Plan or Act: spec/rules/plan-or-act.md に配置
🤖 Default Agent: .claude/agents/sisyphus.md に配置
🔓 Permissions: 推奨パーミッションを .claude/settings.json に追加

💡 デフォルトエージェント有効化:
   .claude/settings.json → "agent": "sisyphus"
   または claude --agent sisyphus

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
🤖 Default Agent: .claude/agents/sisyphus.md に配置
🔓 Permissions: 推奨パーミッションを .claude/settings.json に追加
```

```
🎯 次のステップ:
   「○○を修正して」「○○機能を追加して」など、
   やりたいことをそのまま伝えてください。
```

---

**Step 1 から自動実行してください。**
