---
description: "プラグイン・スピナー・hooksのグローバル環境セットアップ。初回インストール後に一度だけ使用。"
argument-hint: ""
allowed-tools: [Read, Bash, Write, Edit, Glob, Grep, AskUserQuestion]
model: sonnet
---

# /o-m-cc:install - Global Setup

**グローバル環境のセットアップ（一度だけ実行）**

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

## Step 2.5: claude-mem メモリの設定

**AskUserQuestion** で claude-mem を設定するか確認：

```
質問: claude-mem（セマンティックメモリ）を設定しますか？全セッションの操作を自動記録し、セマンティック検索が可能になります。
header: "Memory"
multiSelect: false

選択肢:
1. 設定する（推奨） - 全セッションの操作を自動記録、セマンティック検索可能に
2. スキップ - メモリなしで運用
```

「設定する」を選んだ場合のみ実行：

```bash
# claude-mem プラグインをインストール
claude plugin marketplace add thedotmack/claude-mem
claude plugin install claude-mem
```

---

## Step 3: Sisyphus スピナーの設定

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

## Step 4: hooks の確認

```bash
ls -la "${CLAUDE_PLUGIN_ROOT}/hooks/"
```

hooks が存在する場合、内容を表示して確認。

---

## 完了時の出力

```
╔══════════════════════════════════════════════════════════╗
║  ✅ o-m-cc グローバル設定完了                             ║
╚══════════════════════════════════════════════════════════╝

📦 プラグイン: インストール済み
🧠 メモリ: 設定済み / スキップ
🎡 スピナー: 設定済み / スキップ
🔗 hooks: 確認済み

🎯 次のステップ:
   プロジェクトディレクトリで /o-m-cc:init を実行してください。
```

---

**Step 1 から開始してください。**
