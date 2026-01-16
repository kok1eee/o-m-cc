---
description: "仕様駆動の計画フロー（要件 → 設計 → タスク 一括実行）"
argument-hint: "<feature description>"
allowed-tools: [Task, Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TodoWrite, AskUserQuestion]
model: opus
---

# Plan - 仕様駆動開発オーケストレーター

**要件 → 設計 → タスク** を一括で実行します。

## 機能

$ARGUMENTS

---

## Step 0: コンテキスト管理

**AskUserQuestion** でコンテキストの準備方法を確認：

```
質問: 計画開始前にコンテキストを整理しますか？

選択肢:
1. スキップ（推奨） - このまま開始
2. /compact を実行 - 会話を要約してコンテキスト確保
3. /clear を実行 - 会話履歴をクリアしてリセット
```

- **スキップ** → そのまま次へ
- **/compact** → ユーザーに `/compact` 実行を依頼し、完了後に続行
- **/clear** → ユーザーに `/clear` 実行を依頼し、完了後に続行

---

## Step 1: ブレインストーミング

**AskUserQuestion** でブレインストーミングの実施を確認：

```
質問: 計画前にアイデアを発散させますか？

選択肢:
1. スキップ（推奨） - すぐに計画へ
2. ブレインストーミング実施 - アイデアを発散→収束→方向性決定
```

### ブレインストーミング実施時

1. **アイデア発散**: 制約なしでアイデアを出す
   - この機能で実現したいことは？
   - 理想的な形は？
   - 既存の類似機能やサービスは？
   - ユーザーにとって最高の体験は？

2. **AskUserQuestion** で重視ポイントを確認：
   ```
   質問: 特に重視したいポイントは？

   選択肢:
   1. ユーザー体験（UX） - 使いやすさ重視
   2. パフォーマンス - 速度・効率重視
   3. 拡張性 - 将来の機能追加を考慮
   4. シンプルさ - 最小限の実装
   ```

3. **アイデア整理**:
   - 必須機能（Must）
   - あると良い機能（Nice to have）
   - 将来検討（Future）

4. **出力**: `.plan/brainstorm.md` に保存

---

## Step 2: 実行方式の確認

**AskUserQuestion** で実行方式を確認：

```
質問: どのように計画を進めますか？

選択肢:
1. 一括実行（推奨） - 要件→設計→タスクを自動で実行
2. 段階的に実行 - 各フェーズで確認しながら進める
3. 要件定義のみ - /requirements だけ実行
```

- **一括実行** → Phase 1-3 を連続実行
- **段階的** → 各 Phase 完了後にユーザー確認
- **要件のみ** → Phase 1 のみ実行して終了

---

## 実行フロー

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  Phase 1     │───▶│  Phase 1.5   │───▶│  Phase 2     │───▶│  Phase 3     │
│  要件定義    │    │  ギャップ    │    │  設計        │    │  タスク分解  │
│  (analyst)   │    │  (scout)     │    │  (designer)  │    │  (planner)   │
└──────────────┘    └──────────────┘    └──────────────┘    └──────────────┘
       │                   │                   │                   │
       ▼                   ▼                   ▼                   ▼
  requirements.md    追加質問で補完       design.md          tasks.md
```

---

## Phase 1: 要件定義

**analyst subagent** で要件定義を作成。

```
Task tool で analyst subagent を呼び出し：
- 現状分析
- 要件整理（FR/NFR）
- 出力: .plan/requirements.md
```

**完了を待ってから Phase 1.5 へ。**

---

## Phase 1.5: ギャップ分析

**scout subagent** で漏れを発見し、追加質問。

```
Task tool で scout subagent を呼び出し：
- requirements.md を読み込み
- 曖昧な点・聞き漏れを発見
- AskUserQuestion で追加確認
- 必ず質問で終わる（パッシブ終了禁止）
```

**scout の原則:**
- 読み取り専用（プランモード互換）
- 必ず質問で終わる
- Critical な質問が解決するまで続行

**ユーザーが「十分」と確認したら Phase 2 へ。**

---

## Phase 2: 設計

**designer subagent** で設計書を作成。

```
Task tool で designer subagent を呼び出し：
- requirements.md を読み込み
- アーキテクチャ設計
- 出力: .plan/design.md
```

**完了を待ってから Phase 3 へ。**

---

## Phase 3: タスク分解

**planner subagent** でタスクを分解。

```
Task tool で planner subagent を呼び出し：
- design.md を読み込み
- タスク分解・依存関係整理
- 出力: .plan/tasks.md
```

---

## Phase 4: レビュー（任意）

**critic subagent** で計画全体をレビュー。

```
Task tool で critic subagent を呼び出し：
- requirements.md, design.md, tasks.md をレビュー
- 漏れや矛盾がないか確認
```

---

## 出力ファイル

```
.plan/
├── requirements.md  # 要件定義
├── design.md        # 設計書
└── tasks.md         # 実装タスク
```

---

## 完了時の出力

計画が完了したら、以下を出力してください：

```
✅ 計画完了
   📄 .plan/requirements.md
   📄 .plan/design.md
   📄 .plan/tasks.md

   - 機能要件: X件
   - コンポーネント: X個
   - タスク: X件 (S:X, M:X, L:X)

計画完了。「実装を開始して」と依頼してください。

<promise>DONE</promise>
```

---

**Step 0 から開始してください。AskUserQuestion でコンテキスト管理方法を確認します。**
