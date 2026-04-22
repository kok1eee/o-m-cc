---
name: install
description: "o-m-cc のプロジェクトセットアップ。公式 /init の後に実行し、o-m-cc 固有のアドオン（plan/, sisyphus エージェント, パーミッション, プラグイン, .gitignore）を追加。「o-m-cc をインストール」「o-m-cc を設定して」で発動。"
allowed-tools: [Read, Bash, Write, Edit, Glob, Grep, AskUserQuestion, Skill]
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

**重要: o-m-cc skill は「action の加速装置」。auto mode でも積極発動せよ（planning 遅延ではない）。**

| 状況 | アクション |
|------|-----------|
| ピンポイントな修正（typo, 1 ファイル） | そのまま実行 |
| 複数ファイルにまたがる変更 | `/plan` で計画してから実行 |
| 新機能・設計判断が必要な変更 | `/o-m-cc:sisyphus` で要件→設計→タスク分解→実装まで一気通貫（action skill）|
| 要件が曖昧・何を作るか不明確 | `/o-m-cc:deep-interview` で要件を解像度上げる（action skill）|
| 完了を宣言する前 | `/o-m-cc:verification` で証拠確認（action skill）|
| push/コミット前の最終チェック | `/o-m-cc:quality-gate` で Review Council + 静的解析（action skill）|
| UI polish・a11y・複数画面 redesign | `/o-m-cc:ui-polish`（action skill）|
| 技術記事レビュー・推敲 | `/o-m-cc:editorial-swarm`（action skill）|
| 最適化・試行錯誤 | `/o-m-cc:experiment`（action skill）|

迷ったら `/plan` で方針を固め、実装が見えたら上記 skill に即移行。**auto mode でも上記 skill は抑制せず、状況マッチで積極発動**（Opus 4.7 は指示を文字通り解釈するので、トリガー条件への合致を重視）。
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
.claude/quality-gate-running
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

## Step 7.5: R12 スタイル保護 deny ルール（opt-in）

危険な破壊的操作に対する二層目の防御を追加するか、**AskUserQuestion で必ず確認**する（デフォルトは「追加しない」）:

**選択肢（説明付き）**:
- **追加する（推奨: チーム開発 / 共有リポジトリ）**: 下記の deny ルールを settings.json にマージする
- **追加しない（デフォルト: 個人開発 / 学習プロジェクト）**: 利便性優先、Claude Code 2.1.98+ の built-in 防御に依存
- **詳細を見たい**: 下記のルール内容と動機を表示してから再確認

**「追加する」が選ばれた場合**に settings.json にマージする内容:

```json
{
  "permissions": {
    "deny": [
      "Bash(git push --force*)",
      "Bash(git push -f *)",
      "Bash(git push -f)",
      "Bash(git commit --no-verify*)",
      "Bash(git commit -n *)",
      "Bash(git reset --hard origin/main*)",
      "Bash(git reset --hard origin/master*)",
      "Bash(rm -rf /)",
      "Bash(rm -rf /*)",
      "Bash(rm -rf ~)",
      "Bash(rm -rf ~/)",
      "Bash(jj git push --force*)"
    ]
  }
}
```

**ルールの意図**:
- **force push 系** (`git/jj push --force`, `-f`): 保護ブランチへの破壊的上書きを防ぐ
- **hook bypass 系** (`git commit --no-verify`, `-n`): pre-commit hook を迂回する事故を防ぐ
- **reset --hard origin**: リモート追従による未 push 変更の消失を防ぐ
- **rm -rf /** 系: ファイルシステム破壊を防ぐ

**出典と補足**:
- Claude Harness "Hokage" の R12 deny ルールから必要最小限を抽出（ブランチ保護 / 履歴改変 / FS 破壊の 3 カテゴリ）
- Claude Code 2.1.98+ で built-in Bash bypass は大半修正済み。これは **defense-in-depth の二層目**
- `permissions.deny` を追加してもユーザーが一時的に承認すれば実行可能（完全ブロックではなく、明示承認を強制）

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
🛡️ Deny Rules: R12 保護ルール（opt-in の選択結果を表示）
📝 Handoff: /o-m-cc:handoff で .claude/journal.md に Next Actions を記録（詳細要約は /recap）

💡 デフォルトエージェント有効化:
   .claude/settings.json → "agent": "sisyphus"
   または claude --agent sisyphus
```

---

**Step 1 から自動実行してください。**
