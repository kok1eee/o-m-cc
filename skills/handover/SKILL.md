---
name: handover
description: "セッションの文脈を .claude/context.md に保存。Learnings の MEMORY.md 反映と Skill 提案も行う。作業を中断するとき、セッションを終えるとき、長い作業の区切りに使う。「引き継ぎ」「保存して」「今日はここまで」「文脈を残して」で発動。"
argument-hint: ""
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash]
model: sonnet
---

# セッション文脈の保存

セッション終了時に .claude/context.md を生成し、失われる文脈を保存する。
Learnings に長期的価値があれば MEMORY.md に反映し、繰り返しパターンがあれば Skill を提案する。

## 手順

1. `.claude/context.md` があれば Read する（既存 Snapshot の確認）
2. `.claude/chronicle.md` があれば Read する（経緯の参考に）
3. `.claude/context.md` に既存 Snapshot があれば `.claude/chronicle.md` に退避:
   - Snapshot の timestamp と Intent を抽出
   - `- [timestamp] Intent概要` の形式で chronicle.md のヘッダー直後に挿入
4. 今回のセッションで行ったことを振り返る
5. 以下の構成で `.claude/context.md` を **上書き** する
6. **Learnings チェック**: 長期的価値のある知見があれば MEMORY.md に追記
7. **Skill 提案**: 繰り返しパターンを発見したら提案を出力

## .claude/context.md の構成

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

## Learnings → MEMORY.md フロー

Learnings セクションに記載した内容を確認し、以下に該当するものを MEMORY.md に追記:
- プロジェクト固有のパターンや慣習
- 繰り返し使えるワークアラウンド
- 設計判断の根拠

追記先: プロジェクトの auto-memory（MEMORY.md の適切なセクション）
形式: 既存セクションに追記。新規トピックなら新セクション作成。

## Skill 提案

セッション中に以下のパターンを発見したら、プロジェクト専用スキルとして提案:
- 同じワークフローの繰り返し（3回以上）
- 定型的なコマンド列の実行
- 特定のファイル群への決まった操作

提案形式（.claude/context.md の末尾に追記）:

```
### Skill Suggestion
- **名前**: suggest-skill-name
- **トリガー**: どういう時に使うか
- **内容**: 何をするか（1-2行）
- **根拠**: なぜスキル化すべきか
```

> ユーザーが承認したら skills/ に作成する。自動作成はしない。

## ルール

- **簡潔に**: 各セクション 3-5 行以内
- **知識は memory に**: 長期的に価値のある知見は MEMORY.md に反映。context.md には session state のみ
- **VCS 管理する**: .claude/context.md, chronicle.md は VCS 管理される
