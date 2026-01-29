---
description: "新規プロジェクトの初期化 + Sisyphusモード有効化"
argument-hint: "[project-name]"
allowed-tools: [Read, Bash, Write, Edit, Glob, Grep, AskUserQuestion, Task]
model: sonnet
---

# /o-m-cc:init - Project Initialization with Sisyphus

**公式init + Sisyphusモード有効化を一括実行**

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

**AskUserQuestion** で Standards/Steering をセットアップするか確認：

```
質問: Standards（技術規約）と Steering（プロジェクト文脈）をセットアップしますか？
multiSelect: false

選択肢:
1. 両方セットアップ（推奨）
2. Standards のみ
3. Steering のみ
4. スキップ
```

選択に応じて実行：

```bash
# 両方セットアップ
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-project.sh" --all

# Standards のみ
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-project.sh" --standards

# Steering のみ
bash "${CLAUDE_PLUGIN_ROOT}/scripts/setup-project.sh" --steering
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

## Step 4: 使用言語の確認

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

## Step 5: プラグインのインストール

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

## Step 6: Sisyphus ルールを追加

`spec/rules/sisyphus.md` を作成（verup時は上書き）：

```bash
mkdir -p spec/rules
cp "${CLAUDE_PLUGIN_ROOT}/templates/rules/sisyphus.md" spec/rules/sisyphus.md
echo "✅ Sisyphus ルールを spec/rules/sisyphus.md に配置"
```

---

## Step 7: .gitignore の設定

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

## Step 8: hooks の確認

```bash
ls -la "${CLAUDE_PLUGIN_ROOT}/hooks/"
```

---

## Step 9: Sisyphus スピナーの設定

**AskUserQuestion** で Sisyphus スピナーを設定するか確認：

```
質問: Sisyphus スピナーを設定しますか？（処理中の表示が「岩を押し上げ中...」などに変わります）
header: "Spinner"
multiSelect: false

選択肢:
1. 設定する（推奨） - Sisyphus の世界観を体験
2. スキップ - デフォルトのまま
```

「設定する」を選んだ場合のみ実行：

```bash
SETTINGS_FILE="$HOME/.claude/settings.json"

# settings.json が存在し、spinnerVerbs が未設定の場合のみ追加
if [ -f "$SETTINGS_FILE" ]; then
  if ! jq -e '.spinnerVerbs' "$SETTINGS_FILE" > /dev/null 2>&1; then
    jq '.spinnerVerbs = {
      "mode": "replace",
      "verbs": [
        "岩を押し上げています",
        "山頂を目指しています",
        "また麓から登っています",
        "永遠に繰り返しています",
        "岩を転がしています",
        "頂上まで押し上げています",
        "神々に抗っています",
        "不屈の意志で格闘しています",
        "岩と格闘しています",
        "運命に立ち向かっています"
      ]
    }' "$SETTINGS_FILE" > "${SETTINGS_FILE}.tmp" && mv "${SETTINGS_FILE}.tmp" "$SETTINGS_FILE"
    echo "✅ Sisyphus スピナーを設定しました"
  else
    echo "ℹ️  spinnerVerbs は既に設定済みです（スキップ）"
  fi
fi
```

---

## 完了時の出力

初期化結果をサマリー表示：

```
╔══════════════════════════════════════════════════════════╗
║  ✅ o-m-cc 初期化完了                                    ║
╚══════════════════════════════════════════════════════════╝

📄 CLAUDE.md: 作成/更新済み
📦 プラグイン: インストール済み
🔄 Sisyphus: spec/rules/sisyphus.md に配置
```

---

## 完了後: AskUserQuestion で次のアクションを提示

**AskUserQuestion** で次のステップを選ばせる：

### 既存プロジェクト（コードが存在する場合）

```
質問: 次に何をしますか？
header: "Next"
multiSelect: false

選択肢:
1. タスクを依頼する - やりたいことを伝えてください
2. /o-m-cc:plan で計画開始 - 複雑なタスクを計画から始める
3. spec/steering/ を設定 - プロジェクト文脈を対話的に作成
```

### 新規プロジェクト（コードがない場合）

```
質問: 次に何をしますか？
header: "Next"
multiSelect: false

選択肢:
1. spec/steering/ を設定（推奨） - プロジェクト文脈を対話的に作成
2. /o-m-cc:plan で計画開始 - タスクを計画から始める
3. タスクを依頼する - やりたいことをそのまま伝える
```

選択に応じて対応する。

---

**Step 1 から開始してください。**
