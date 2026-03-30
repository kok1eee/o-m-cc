---
name: simplify
description: "AI が書いた冗長コードを検出・除去。deletion-first で削除を優先。quality-gate の前段、または単独で使える。「簡潔にして」「冗長なコード整理」「deslop」「スリム化」で発動。"
argument-hint: "[target files or area]"
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
model: sonnet
effort: medium
---

# Simplify - Deletion-First Code Cleaner

何かを足す前に、何かを消せないか考える。

## 対象

`$ARGUMENTS` が指定されていればそのファイル/領域。未指定なら現セッションの変更差分。

## 原則

- **Deletion-first**: 削除を優先、追加は最小限
- 「念のため」のコードは消す
- コメントで説明が必要なコードは、コードを直してコメントを消す
- 振る舞いを変えない。変える場合はユーザーに確認

## Step 1: 変更差分の把握

```bash
jj diff --name-only  # または git diff --name-only HEAD
jj diff --stat
```

$ARGUMENTS でファイルが指定されている場合はそちらを優先。

## Step 2: 検出・修正

以下の5カテゴリを順にチェックし、見つけたら即座に修正する。

### 2-1. デッドコード
- 未使用の import / 変数 / 関数 / クラス
- 到達不能コード（early return の後のコード等）
- コメントアウトされたコード
→ **削除**

### 2-2. 不要なコメント
- 自明なコメント（`# ループ`, `// 変数を初期化` 等）
- AI が生成した説明的コメント（`# This function does X by Y` 等）
- 放置された TODO / FIXME / HACK（対応しないなら消す）
→ **削除**

### 2-3. 過剰なエラーハンドリング
- catch して re-throw するだけの try-catch
- 内部コードに対する不要な null/undefined チェックの連鎖
- 起こり得ないケースの防御コード
→ **削除** または **簡潔化**

### 2-4. 不要な抽象化
- 1箇所からしか呼ばれない wrapper / helper
- 使われていないインターフェース / 型定義
- 過剰な設定可能性（config で渡す必要のない値）
→ **インライン化** または **削除**

### 2-5. 重複コード
- 同一ロジックのコピー
- ほぼ同じ関数が複数存在
→ **統合**（ただし無理に抽象化しない。3箇所未満なら重複を許容）

## Step 3: 変更サマリー

修正完了後、以下の形式で報告:

```
📉 Simplify 完了
- 削除: N 行（コメント M, デッドコード K, ...）
- 変更ファイル: file1, file2, ...
- 振る舞いの変更: なし
```
