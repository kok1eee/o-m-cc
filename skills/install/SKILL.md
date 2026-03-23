---
name: install
description: "o-m-cc のプロジェクトセットアップ。公式 /init の後に実行し、o-m-cc 固有のアドオン（plan/, sisyphus エージェント, パーミッション, プラグイン, .gitignore）を追加。「o-m-cc をインストール」「o-m-cc を設定して」で発動。"
allowed-tools: [Read, Bash, Write, Edit, Glob, Grep, AskUserQuestion, Skill]
model: sonnet
effort: medium
disable-model-invocation: true
---

# /o-m-cc:install - Project Setup

**公式 /init の後に実行する o-m-cc アドオン。** CLAUDE.md の生成は公式 /init に任せ、o-m-cc 固有の設定のみ追加する。

---

## Step 1: 前提確認

```bash
if [ ! -f "CLAUDE.md" ]; then
  echo "⚠️ CLAUDE.md がありません。先に /init を実行してください。"
  exit 1
fi
echo "✅ CLAUDE.md を検出"
```

CLAUDE.md がなければ公式 /init を先に実行するよう案内して終了。

---

## Step 2: CLAUDE.md に o-m-cc ワークフローセクションを追記

既存の CLAUDE.md を Read し、o-m-cc のワークフロー判断テーブルが**まだなければ**追記する。既にあればスキップ。

```markdown
## o-m-cc ワークフロー

| 状況 | アクション |
|------|-----------|
| ピンポイントな修正 | そのまま実行 |
| 複数ファイルにまたがる変更 | `/plan` で計画してから実行 |
| 新機能・設計判断が必要な変更 | `/sisyphus` で要件→設計→タスク分解→実装 |
| 完了を宣言する前 | `/verification` で証拠確認 |

迷ったら `/plan` に入る。
```

---

## Step 3: plan/ ディレクトリの準備

```bash
mkdir -p plan
echo "✅ plan/ を作成"
```

---

## Step 4: Sisyphus デフォルトエージェントを配置

```bash
mkdir -p .claude/agents
cp "${CLAUDE_PLUGIN_ROOT}/templates/agents/sisyphus.md" .claude/agents/sisyphus.md
echo "✅ .claude/agents/sisyphus.md に配置"
```

---

## Step 5: 推奨プラグインのインストール

既にインストール済みならスキップ。

```bash
claude plugin install security-guidance
```

---

## Step 6: .gitignore の設定

o-m-cc のランタイムファイルを追加（重複しない場合のみ）：

```
# Claude Code
.claude/

# o-m-cc runtime
.claude/sisyphus-state.json
.claude/quality-gate-proof.json
.claude/quality-gate-running
.claude/sisyphus-baseline.json
```

---

## Step 7: 推奨パーミッションの設定

`.claude/settings.json` に o-m-cc 用パーミッションを**マージ**する（既存設定を上書きしない）：

```json
{
  "permissions": {
    "allow": [
      "Read(plan/**)",
      "Write(plan/**)",
      "Edit(plan/**)",
      "Glob(**)",
      "Grep(**)"
    ]
  }
}
```

公式 /init が既に `.claude/settings.json` を作成している可能性があるので、**必ず既存設定を Read してマージ**する。

---

## Step 8: SessionEnd hook の設定

`.claude/settings.json` の hooks に SessionEnd を**マージ**する：

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

公式 /init が設定した hooks を壊さないよう、**SessionEnd のみ追加/更新**する。

---

## 完了時の出力

```
╔════════════════════════════════════════╗
║  ✅ o-m-cc セットアップ完了             ║
╚════════════════════════════════════════╝

📄 CLAUDE.md: ワークフローセクション追記済み
📁 plan/: 計画ファイル用ディレクトリ準備済み
🤖 Agent: .claude/agents/sisyphus.md に配置
🔓 Permissions: 推奨パーミッション追加済み
🔄 SessionEnd: context.md 自動保存設定済み

💡 デフォルトエージェント有効化:
   .claude/settings.json → "agent": "sisyphus"
   または claude --agent sisyphus
```

---

**Step 1 から自動実行してください。**
