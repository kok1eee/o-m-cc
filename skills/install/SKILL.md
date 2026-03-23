---
name: install
description: "o-m-cc のプロジェクト固有セットアップ（CLAUDE.md, plan/, Sisyphusルール, 推奨パーミッション）。新規プロジェクト開始時や既存プロジェクトにo-m-ccを導入する際に使用。「o-m-cc をインストール」「o-m-cc を設定して」「/install」で発動。"
argument-hint: "[project-name]"
allowed-tools: [Read, Bash, Write, Edit, Glob, Grep, AskUserQuestion, Task]
model: sonnet
disable-model-invocation: true
---

# /o-m-cc:install - Project Setup

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

## Step 3: Spec ディレクトリの準備

計画フェーズ用の `plan/` ディレクトリを作成：

```bash
mkdir -p plan
echo "✅ plan/ を作成"
```

**Note:** プロジェクトの規約・文脈は CLAUDE.md に集約。plan/ は計画ファイルのみ管理。

---

## Step 4: デフォルトエージェントを追加

`.claude/agents/` にデフォルトエージェントを配置（verup時は上書き）：

```bash
mkdir -p .claude/agents
cp "${CLAUDE_PLUGIN_ROOT}/templates/agents/sisyphus.md" .claude/agents/sisyphus.md
echo "✅ Sisyphus デフォルトエージェントを .claude/agents/sisyphus.md に配置"
echo ""
echo "💡 デフォルトエージェントとして有効にするには:"
echo "   .claude/settings.json に \"agent\": \"sisyphus\" を追加"
echo "   または claude --agent sisyphus で起動"
```

---

## Step 4.5: 推奨プラグインのインストール

o-m-cc が連携する公式プラグインをインストールする。既にインストール済みならスキップ。

```bash
# セキュリティ（PreToolUse hook でセキュリティパターン検出）
claude plugin install security-guidance

# CLAUDE.md 品質管理（handover/init で連携）
claude plugin install claude-md-management
```

> **security-guidance は必須。** o-m-cc はセキュリティチェックをこのプラグインに委譲している。

---

## Step 4.6: LSP プラグインの自動検出・インストール

プロジェクトの言語を検出し、対応する LSP プラグインをインストールする。

### 言語検出ロジック

```bash
# ファイル拡張子でプロジェクト言語を検出
LSP_PLUGINS=()

# Python
if ls *.py **/*.py pyproject.toml setup.py requirements.txt 2>/dev/null | head -1 > /dev/null; then
  LSP_PLUGINS+=("pyright-lsp")
fi

# TypeScript / JavaScript
if ls *.ts *.tsx *.js *.jsx tsconfig.json package.json 2>/dev/null | head -1 > /dev/null; then
  LSP_PLUGINS+=("typescript-lsp")
fi

# Rust
if ls *.rs Cargo.toml 2>/dev/null | head -1 > /dev/null; then
  LSP_PLUGINS+=("rust-analyzer-lsp")
fi

# Go
if ls *.go go.mod 2>/dev/null | head -1 > /dev/null; then
  LSP_PLUGINS+=("gopls-lsp")
fi
```

### 対応 LSP 一覧

| 言語 | プラグイン | 検出ファイル |
|------|-----------|-------------|
| Python | pyright-lsp | `*.py`, `pyproject.toml`, `requirements.txt` |
| TypeScript/JS | typescript-lsp | `*.ts`, `*.tsx`, `package.json` |
| Rust | rust-analyzer-lsp | `*.rs`, `Cargo.toml` |
| Go | gopls-lsp | `*.go`, `go.mod` |
| Java | jdtls-lsp | `*.java`, `pom.xml`, `build.gradle` |
| C/C++ | clangd-lsp | `*.c`, `*.cpp`, `CMakeLists.txt` |
| Ruby | ruby-lsp | `*.rb`, `Gemfile` |
| PHP | php-lsp | `*.php`, `composer.json` |
| Kotlin | kotlin-lsp | `*.kt`, `build.gradle.kts` |
| Swift | swift-lsp | `*.swift`, `Package.swift` |
| C# | csharp-lsp | `*.cs`, `*.csproj` |
| Lua | lua-lsp | `*.lua` |

### インストール

検出された言語ごとに `claude plugin install <lsp-plugin>` を実行。既にインストール済みならスキップ。

```
echo "✅ LSP プラグイン: ${LSP_PLUGINS[*]} をインストール"
```

> 何も検出されなければスキップ。

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
  ".claude/sisyphus-state.json"
  ".claude/.completed-tasks"
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
      "Read(plan/**)",
      "Write(plan/**)",
      "Edit(plan/**)",
      "Read(agents/**)",
      "Read(skills/**)",
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

## Step 7: SessionEnd hook の設定（plugin bug workaround）

プラグイン定義の SessionEnd hook が発火しない既知のバグへの対処。
プロジェクトレベルの `.claude/settings.json` に SessionEnd hook を追加して、セッション終了時に context.md が保存されるようにする。

**既に `.claude/settings.json` が存在する場合は、既存設定にマージする。**

### 追加する hooks 設定

```json
{
  "hooks": {
    "SessionEnd": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/pre-compact-handover.sh",
            "timeout": 10000
          }
        ]
      }
    ]
  }
}
```

### 実装方法

1. Step 6 で読み込んだ `.claude/settings.json` に `hooks.SessionEnd` を追加
2. 既存の `hooks` があればマージ（SessionEnd のみ追加/上書き）
3. Write で書き戻す

> **Note:** `${CLAUDE_PLUGIN_ROOT}` は Claude Code が実行時に展開する。プラグインの SessionEnd バグが修正されればこのステップは不要になる。

```
echo "✅ SessionEnd hook を .claude/settings.json に追加（context.md 自動保存）"
```

---

## Step 8: CLAUDE.md の品質監査

`claude-md-management` プラグインがインストールされている場合、CLAUDE.md を監査して改善提案を適用する。

```
Skill: claude-md-management:claude-md-improver
```

> プラグイン未インストールの場合はスキップする（エラーにしない）。

---

## 完了時の出力 + 次のステップ提案

プロジェクトの状態に応じた完了メッセージを表示：

```
╔══════════════════════════════════════════════════════════╗
║  ✅ o-m-cc 初期化完了                                    ║
╚══════════════════════════════════════════════════════════╝

📄 CLAUDE.md: 作成/更新済み
📁 plan/: 計画ファイル用ディレクトリ準備済み
🤖 Default Agent: .claude/agents/sisyphus.md に配置
🔓 Permissions: 推奨パーミッションを .claude/settings.json に追加
🔄 SessionEnd: context.md 自動保存を .claude/settings.json に追加
🔧 LSP: [検出された言語の LSP プラグインをインストール]
📊 CLAUDE.md: 品質監査 + 改善提案を適用

💡 デフォルトエージェント有効化:
   .claude/settings.json → "agent": "sisyphus"
   または claude --agent sisyphus

🎯 次のステップ:
   「○○を修正して」「○○機能を追加して」など、
   やりたいことをそのまま伝えてください。
```

---

**Step 1 から自動実行してください。**
