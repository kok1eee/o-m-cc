---
name: handoff
description: "現セッションを手動で区切り、新セッションへの引き継ぎ情報を context.md に保存する。長いセッションでコンテキストが圧迫されたとき、タスクの区切りで新セッションに切り替えたいときに使う。「ハンドオーバー」「引き継ぎ」「新セッションに渡したい」「context を保存して」「新しい会話を始めたい」「セッションを区切りたい」「handoff」で発動。"
allowed-tools: [Read, Write, Bash, Glob]
effort: low
---

# Handoff - 手動セッション引き継ぎ

現セッションの状態を `.claude/context.md` に保存し、新しい terminal で再開するための手順を出力する。

`pre-compact-handover.sh` は PreCompact / SessionEnd で自動実行されるが、**ユーザーが任意のタイミングで明示的に handover したい場合**にこのスキルを使う。

## 用途

- 長いセッションでコンテキストが圧迫されてきた（compaction を待たずに区切りたい）
- タスクの区切りで新しいセッションに切り替えたい
- 別の terminal で並行作業を始めたい

## 実行フロー

### Step 1: 状態の整理（自己内省）

これまでの会話を振り返り、以下を**自分の理解で**まとめる:

- **Intent**: 現在取り組んでいるタスクの主目的（1行、200文字以内）
- **Next**: 次のセッションでやるべき具体的なアクション（最大3つ、ファイル名・関数名レベルで具体的に）
- **Outcomes**: このセッションで達成したこと（簡潔に1-2行）
- **Blockers**: 解決していない問題・疑問点・判断待ち事項（あれば）

> **重要**: transcript パースに頼らない。あなた自身の会話理解を使って書く。

### Step 2: 現在のディレクトリと変更状態を取得

```bash
pwd
jj diff --stat 2>/dev/null || git diff --stat HEAD 2>/dev/null || echo "no changes"
```

### Step 3: context.md に書き込み

`.claude/context.md` を以下のフォーマットで上書き:

```markdown
# Context

> セッション間の引き継ぎ情報。学びは MEMORY.md、タスクは TaskList、設定は CLAUDE.md。

### Snapshot (MM/DD HH:MM, manual-handoff)

**Intent:** <Intent を1行で>

**Next:**
- <action 1: ファイル名・関数名・具体的な変更内容>
- <action 2>
- <action 3>

**Outcomes:** <このセッションで達成したことを1-2行で>

**Blockers:** <未解決があれば。なければこの行ごと省略>

**Working Dir:** `<Step 2 で取得した pwd>`
```

タイムスタンプは `date '+%m/%d %H:%M'` で取得。

### Step 4: chronicle.md にエントリ追加

`pre-compact-handover.sh` と同じフォーマットで chronicle.md の先頭に追記:

```bash
TIMESTAMP=$(date '+%m/%d %H:%M')
ENTRY="- [${TIMESTAMP}, manual] <Intent の冒頭80文字>"
```

ヘッダー（`> 超過分は ...` 行）の直後に挿入。

### Step 5: ユーザーへの出力

以下のメッセージをユーザーに表示:

```
✅ Handoff 完了

📋 .claude/context.md を更新しました。

次のセッションを開始するには、新しい terminal で:

  cd <Working Dir>
  claude

新セッションでは SessionStart hook が自動で context.md を表示します。

💡 未コミットの変更がある場合は、handoff 前に jj describe を推奨。
```

## Gotchas

- **Intent は1行**: 長すぎると chronicle.md が読みづらくなる。200文字以内
- **Next は具体的に**: 「あれをやる」ではなく「ファイル X の関数 Y を Z に変える」
- **transcript パースに依存しない**: 自分の会話理解で Intent/Next/Outcomes を書く。jq 等は使わない
- **既存 context.md は上書き**: マージしない。新セッションは新しいスナップショットだけ参照する
- **未コミット変更の警告**: 変更が大きい場合は handoff 前に commit を推奨する一文を追加

---

**Step 1 の自己内省から開始してください。**
