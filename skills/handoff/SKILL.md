---
name: handoff
description: "EC2 など別マシンへのセッション引き継ぎが第一用途。現セッションの Recap（LLM 要約）と Next Actions を VCS 共有可能な `.claude/journal.md` の先頭に追記する。ローカル端末固有で他マシンから見えない built-in `/recap` の限界を補う。同一マシン内のセッション区切りにも使える。「EC2 に引き継ぎ」「別マシンに渡したい」「handoff」「ハンドオーバー」「journal に残して」「新セッションに渡したい」「新しい会話を始めたい」「セッションを区切りたい」で発動。"
allowed-tools: [Read, Write, Bash, Glob, AskUserQuestion]
effort: low
---

# Handoff - EC2 / 別マシン引き継ぎの中核

**このスキルは EC2 A → EC2 B のような跨マシン引き継ぎのための中核機能**。
現セッションの Recap と Next Actions を `.claude/journal.md` に追記し、
VCS（jj / git）で別マシンに同期する。

Claude Code built-in `/recap` は優秀だが **ローカル端末固有**（別マシンからは見えない）。
このギャップを埋めるのが handoff。journal.md は `.gitignore` で無視される chronicle / context
と違い、**明示的に VCS で共有** される唯一のセッション履歴。

同一マシン内の「セッションを区切りたい」用途でも使えるが、その場合は `/recap` と
併用する前提（journal は**跨マシン共有のソースオブトゥルース**）。

## いつ使うか

**第一用途（跨マシン引き継ぎ）**:
- EC2 A で作業中にリソース切れ・時間切れ → EC2 B で続きを再開
- 自宅 PC → 会社 PC に作業を渡す
- チームメンバーに状況を引き継ぐ（VCS で共有可能）

**副次用途（同一マシン）**:
- 長いセッションでコンテキストが圧迫されてきた（compaction を待たずに区切りたい）
- タスクの区切りで新しいセッションに切り替えたい
- 後から参照したい「判明した事実 + 次の一手」をアーカイブ化したい

## Step 1: Recap + Next Actions の要約（自己内省）

これまでの会話を振り返り、**2 つの情報** を要約する。transcript パースには
依存せず、あなた自身の会話理解で書く。

### 1A: Recap（2〜4 文）

- 現セッションで **何をしたか / 何が判明したか / どこで止まっているか**
- built-in `/recap` 相当のクオリティ。Intent / Outcomes / Blockers を自然文で
- 別マシンから Read しても文脈が分かるレベルで書く
- 「作業を進めた」のような抽象表現は避ける。具体的なファイル名・発見を入れる

### 1B: Next Actions（1〜5 件、箇条書き）

- **次のセッションでやるべき具体的アクション**
- ファイル名・関数名・コマンド名レベルで具体的に書く
- 「あれをやる」ではなく「`hooks/foo.sh` の `bar` 関数を X に書き換える」
- 該当なし（本当に何もない）場合は AskUserQuestion で確認。
  AskUserQuestion が使えない環境では `- (未指定)` 1 行で記録して進む

## Step 2: タイムスタンプとホスト名の取得

```bash
date '+%Y-%m-%d %H:%M'
hostname -s
```

`hostname -s` が失敗 or 空の場合はホスト識別を省略して続行（EC2 識別は nice-to-have）。

## Step 3: journal.md の先頭に追記

ファイルパス: `.claude/journal.md`

### 新エントリのフォーマット

ホスト名が取得できた場合:

```markdown
## <timestamp> [<hostname>]

### Recap
<Recap 本文>

### Next
- <action 1>
- <action 2>

```

ホスト名が取れなかった場合:

```markdown
## <timestamp>

### Recap
<Recap 本文>

### Next
- <action 1>
- <action 2>

```

### ファイルが存在しない場合

以下のヘッダー + 新エントリで新規 Write：

```markdown
# Journal

> セッション間の引き継ぎ。最新が上。Recap を時系列アーカイブとして保持し、
> 次のアクションを明示する。詳細なセッション内要約は built-in `/recap` も併用。

## <timestamp> [<hostname>]

### Recap
...

### Next
- ...

```

### ファイルが存在する場合

1. `.claude/journal.md` を Read する
2. 最初に現れる `## ` 行（既存エントリの先頭）の位置を探す
3. その行の **直前** に新エントリブロックを挿入する
4. 結合後の全文で Write する

> 既存エントリは削除・編集しない。単に上に積み上げる。

### 実装上の注意

- ヘッダー（`# Journal` + `> ...` + 空行）がファイルに存在しない（手動編集された）場合、
  先頭に `## ` 行があればそのまま prepend、なければヘッダーから作り直す
- 空ファイルは「存在しない」と同じ扱いで新規作成
- サイズ上限・ローテーションはしない。VCS で管理する想定
- `### Recap` と `### Next` の順序は固定（この順で書く）

## Step 4: ユーザーへの出力

以下のメッセージを表示：

```
✅ Handoff 完了

📋 .claude/journal.md の先頭に Recap + Next Actions を追記しました。

同一マシンでの再開:
  cd <current working dir>
  claude

  - SessionStart hook が journal.md の最新エントリを自動表示
  - セッションを resume する場合は built-in `/recap` も併用可

別 EC2 / マシンでの再開:
  1. VCS で journal.md を同期（jj git push → 別マシンで jj git pull）
  2. cd <current working dir>
  3. claude を起動 → SessionStart が最新 Recap + Next を表示

💡 未コミットの変更がある場合は、handoff 前に jj describe を推奨。
```

`<current working dir>` は `pwd` の結果で置換。

## Gotchas

- **Recap は LLM 要約の品質で**: /recap レベルで書く。「作業を進めた」ではなく
  「X ファイルの Y 関数に Z のバグを発見し〇〇で対応した」
- **Next Actions は具体的に**: 「あれをやる」ではなく「ファイル X の関数 Y を Z に変える」
- **transcript パースに依存しない**: 自分の会話理解で書く。jq 等は使わない
- **既存エントリは保持**: マージせず prepend するだけ。上書きしない
- **0 件 Next での呼び出し**: AskUserQuestion で確認。使えない環境では `- (未指定)` で記録
- **hostname 取得失敗時**: ホスト識別なしで進む。EC2 識別は EC2 間連携の補助情報
- **Recap と Next の役割分担**: Recap は過去志向（何をしたか）、Next は未来志向（何をするか）

<!-- AUTO-GOTCHAS -->

---

**Step 1 の自己内省から開始してください。**
