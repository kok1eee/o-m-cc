---
name: handover
description: "セッションの文脈を .claude/context.md に保存し、CLAUDE.md を改善する。作業を中断するとき、セッションを終えるとき、長い作業の区切りに使う。「引き継ぎ」「保存して」「今日はここまで」「文脈を残して」で発動。"
argument-hint: ""
allowed-tools: [Read, Write, Edit, Glob, Grep, Bash, Skill]
effort: low
---

# セッション文脈の保存

セッション終了時に .claude/context.md を生成し、次のセッションへの引き継ぎ情報を保存する。

## 責務の分離

| 責務 | 担当 | context.md の役割 |
|------|------|-----------------|
| セッション間の引き継ぎ | **context.md** | ← ここだけ |
| compaction 後の復元 | PostCompact hook | 不要（動的取得） |
| 長期的な学び | MEMORY.md (auto-memory) | 不要 |
| タスク管理 | TaskList (ネイティブ) | 不要 |
| プロジェクト設定 | CLAUDE.md | 不要 |

## 手順

1. `.claude/context.md` があれば Read する（既存 Snapshot の確認）
2. `.claude/chronicle.md` があれば Read する（経緯の参考に）
3. `.claude/context.md` に既存 Snapshot があれば `.claude/chronicle.md` に退避:
   - Snapshot の timestamp と Intent を抽出
   - `- [timestamp] Intent概要` の形式で chronicle.md のヘッダー直後に挿入
4. 今回のセッションで行ったことを振り返る
5. 以下の構成で `.claude/context.md` を **上書き** する
6. **CLAUDE.md 改善**: `/revise-claude-md` でセッションの学びを CLAUDE.md に反映（プラグイン未インストールならスキップ）

## .claude/context.md の構成

**3セクションのみ。** 学びは MEMORY.md、タスクは TaskList、設定は CLAUDE.md の責務。

### Intent（意図）
このセッションで達成しようとしていたこと（1-2行）

### Outcomes（成果）
完了した作業と成果物を箇条書きで

### Changed Files
変更したファイルと各ファイルの変更概要

## スキル進化

セッション中に得た学びをスキルの Gotchas に反映する。

```
Skill: evolve
```

## CLAUDE.md の自動改善

`claude-md-management` プラグインがインストールされている場合、セッションの学びを CLAUDE.md に反映する。

```
Skill: claude-md-management:revise-claude-md
```

> プラグイン未インストールの場合はスキップする（エラーにしない）。

## ルール

- **簡潔に**: 各セクション 3-5 行以内
- **context.md はセッション状態のみ**: 学びは MEMORY.md、タスクは TaskList、設定は CLAUDE.md
- **CLAUDE.md は最新に**: セッションの学びで CLAUDE.md を改善（claude-md-management 連携）
- **VCS 管理する**: .claude/context.md, chronicle.md は VCS 管理される
