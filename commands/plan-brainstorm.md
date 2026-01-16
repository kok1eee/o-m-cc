---
description: "ブレインストーミング → Plan（アイデア発散→収束→計画）"
allowed-tools: Task, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TodoWrite, AskUserQuestion
model: opus
---

# Plan with Brainstorming

**アイデアを発散させてから計画を立てます。**

## 機能

$ARGUMENTS

---

## Phase 0: ブレインストーミング

### Step 1: アイデア発散

まず制約なしでアイデアを出す：

```
- この機能で実現したいことは？
- 理想的な形は？
- 既存の類似機能やサービスは？
- ユーザーにとって最高の体験は？
```

**AskUserQuestion** でユーザーの考えを引き出す：

```
質問: この機能について、特に重視したいポイントは？

選択肢:
1. ユーザー体験（UX） - 使いやすさ重視
2. パフォーマンス - 速度・効率重視
3. 拡張性 - 将来の機能追加を考慮
4. シンプルさ - 最小限の実装
```

### Step 2: アイデア整理

発散したアイデアを整理：

```
- 必須機能（Must）
- あると良い機能（Nice to have）
- 将来検討（Future）
```

### Step 3: 方向性確認

**AskUserQuestion** で方向性を確認：

```
質問: ブレインストーミングの結果、以下の方向性でよいですか？

選択肢:
1. この方向で進める（推奨）
2. 別のアイデアを検討
3. もう少し発散させる
```

---

## Phase 1-3: Plan 実行

ブレインストーミング完了後、通常の Plan フローを実行：

1. **要件定義** - analyst subagent
2. **設計** - designer subagent
3. **タスク分解** - planner subagent

---

## 出力

ブレインストーミング結果を `.plan/brainstorm.md` に保存：

```markdown
# ブレインストーミング: [機能名]

## アイデア一覧
- ...

## 優先順位
### Must（必須）
- ...

### Nice to have（あると良い）
- ...

### Future（将来）
- ...

## 決定した方向性
- ...
```

---

**まずブレインストーミングでアイデアを発散させ、その後 Plan を実行してください。**
