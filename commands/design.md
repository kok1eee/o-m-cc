---
description: "設計書を作成（SDD Phase 2）"
argument-hint: ""
allowed-tools: [Task, Read, Write, Glob, Grep, WebSearch, WebFetch, AskUserQuestion]
model: opus
---

# Design - アーキテクチャ設計

**SDD Phase 2**: requirements.md に基づいて設計書を作成します。

---

## 前提条件

`.plan/requirements.md` が存在すること。

存在しない場合は、先に `/requirements` を実行してください。

---

## Step 0: 設計アプローチの確認

複数のアーキテクチャパターンが考えられる場合、**AskUserQuestion** で確認してください：

```
例: 状態管理の選択
質問: どの状態管理アプローチを使用しますか？

選択肢:
1. Context API（推奨） - シンプルで十分な場合
2. Redux - 複雑な状態管理が必要な場合
3. Zustand - 軽量で柔軟な選択肢
4. 既存のパターンに合わせる
```

**明確な場合やプロジェクトのパターンがある場合はスキップ。**

---

## 実行内容

**designer subagent** を使用して設計書を作成してください。

```
Task tool で designer subagent を呼び出し：

1. 要件の確認
   - .plan/requirements.md を読み込み
   - FR/NFR を把握

2. 設計
   - アーキテクチャパターンの選択
   - コンポーネント設計
   - データ設計
   - API設計（必要な場合）

3. 出力
   - .plan/design.md を作成
```

---

## 出力ファイル

`.plan/design.md`

```markdown
# 設計書: [機能名]

## 対応する要件
- FR-1, FR-2, ...
- NFR-1, ...

## アーキテクチャ
### システム構成図
[Mermaid図]

### コンポーネント
#### [コンポーネント名]
- 責務: ...
- 対応要件: FR-X

## データ設計
...

## API設計
...
```

---

## 完了時の出力

設計が完了したら、以下を出力してください：

```
✅ 設計完了
   📄 .plan/design.md

   - コンポーネント: X個
   - API: X個
```

## 次のステップ確認

設計完了後、**AskUserQuestion** で次のアクションを確認：

```
質問: 設計が完了しました。次のステップは？

選択肢:
1. タスク分解へ進む（推奨） - Phase 3 を実行
2. 設計を修正 - フィードバックを反映
3. ここで終了 - 後で続行
```

**「ここで終了」選択時のみ:**
```
<promise>DONE</promise>
```

---

**designer subagent で設計を開始してください。**
