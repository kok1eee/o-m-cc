---
name: handover
description: "セッションの文脈を CONTEXT.md に保存。セッション終了前に「引き継ぎ」「handover」「context」で使用。"
argument-hint: ""
allowed-tools: [Read, Write, Glob, Grep, Bash]
model: sonnet
---

# セッション文脈の保存

セッション終了時に CONTEXT.md を生成し、失われる文脈を保存する。

## 手順

1. 既存の CONTEXT.md があれば Read して、PreCompact hook のスナップショットも参考にする
2. 今回のセッションで行ったことを振り返る（スナップショット + 現在の文脈）
3. 以下の構成で CONTEXT.md をプロジェクトルートに **上書き** する（最終版として生成）

## CONTEXT.md の構成

Entire.io inspired な4軸 + 補足セクション:

### Intent（意図）
このセッションで達成しようとしていたこと（1-2行）

### Outcomes（成果）
完了した作業と成果物を箇条書きで

### Learnings（学び）
確定した設計判断、発見したパターン、技術的な知見

### Friction（摩擦点）
ハマったこと、失敗したアプローチ、既知の問題

### Next Steps（次のステップ）
次のセッションで最初にやるべきこと（優先順位付き）

### Changed Files
変更したファイルと各ファイルの変更概要

### Chronicle（これまでの経緯）
既存の CONTEXT.md に Chronicle セクションがあれば、その内容を引き継ぐ。
新しいエントリを追記して経緯を維持する。

## ルール

- **簡潔に**: 各セクション 3-5 行以内
- **Chronicle を引き継ぐ**: 既存のダイジェストは消さない。追記する
- **知識は memory に**: 長期的に価値のある知見は auto-memory に任せる。CONTEXT.md には session state のみ
- **VCS 管理しない**: .gitignore に含まれる
