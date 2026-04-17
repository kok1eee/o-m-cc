---
name: ui-polish
description: "既存画面の UI polish / 複数画面の redesign 統一 / a11y 対応 / CSS 一貫性修正を軽量ループで実装。Council を使わず tsc/lint のみでゲート。1 画面ずつ Read → Edit → 静的チェック → 次へ。「UI polish して」「画面統一して」「a11y 対応」「CSS 統一」「複数画面 redesign」で発動。新規デザインをゼロから生成する場合は外部プラグイン frontend-design を使う。"
argument-hint: "<target description (e.g., 5 画面の a11y 対応)>"
allowed-tools: [Read, Edit, Glob, Grep, Bash, AskUserQuestion]
effort: low
---

# UI Polish - 軽量 UI 実装ループ

既に明確な方針がある UI 実装タスクを、画面/コンポーネント単位で順次適用し
個別に tsc/lint でゲートする。Council やマルチフェーズ計画は使わない。

## いつ使う / いつ使わない

| 使う | 使わない |
|---|---|
| 複数画面の統一的 polish（同じデザインシステム適用）| 新機能開発 → `/o-m-cc:sisyphus` |
| a11y 対応（focus-visible, aria, キーボードナビ） | 要件が曖昧 → `/o-m-cc:deep-interview` |
| CSS 一貫性修正・デザイントークン適用 | パフォーマンス計測が必要 → `/o-m-cc:experiment` |
| 既存機能を壊さないリファクタ | **新規デザインをゼロから生成** → 外部プラグイン `frontend-design` |
| | 単発 1 ファイル修正 → 普通の Edit |

`frontend-design` との棲み分け: このスキルは **既存 UI の統一・修正** に集中する。
ページ/コンポーネントを一から作る要求が来たら Claude は `frontend-design` へ誘導する。

## Step 1: 対象リスト + 方針の確認

`AskUserQuestion` で対象画面/ファイル列と方針を確定する。

- 対象が `$ARGUMENTS` で明示されていればそれを候補の出発点にする
- 方針が不明なら「デザイン方針 / a11y 基準 / CSS 統一ルール」のどれを適用するか聞く
- 対象が 1 ファイルのみなら「普通の Edit で十分」と伝えてスキル終了も選択肢に

Headless モード（`CLAUDE_NON_INTERACTIVE=1`）では、$ARGUMENTS から対象と方針が
取れない場合はエラー停止（推測で盲目的に編集しない）。

## Step 2: 画面ごとの実装ループ

各対象について順次:

1. **Read** 現状のファイル
2. **Edit** 方針に沿って差分適用。`.me-field` のような独自 focus スタイル等、
   既存コンポーネントの意図は尊重する
3. **静的チェック**（優先順に試す）:
   - `bin/lint` が存在 → それを実行（プロジェクト標準）
   - なければ `npm run lint`（package.json の scripts にあれば）
   - さらに必要なら `npx tsc --noEmit` で型チェック
4. **失敗時**: 1 回だけ修正を試みて再チェック。2 度目も失敗 or 判断に迷ったら
   `AskUserQuestion` で判断を委ねる（「無視して次」「ここで止める」等）

> 次の対象に進む前に、前の対象の lint が通過していること。通っていないのに
> 積み上げると後でまとめて壊れたときに切り分け不能になる。

## Step 3: 変更サマリ

全対象完了後、変更内容の表を出力:

```
| 対象ファイル | 変更概要 | lint |
|---|---|---|
| src/components/Foo.tsx | focus-visible 追加 | ✅ |
| src/app/globals.css | トークン統一 | ✅ |
```

コミットは呼び出し元（ユーザー or 上位ワークフロー）に委ねる。ui-polish は
commit しない（短命な変更の連続なので、最終確認はユーザー判断）。

## Gotchas

- **tsc/lint コマンドの発見優先順を崩さない**: `bin/lint` が存在すれば必ずそれを使う。プロジェクト標準を優先しないと CI との乖離が起きる
- **1 画面ずつ進める（バッチ Edit は避ける）**: 複数画面を 1 Edit でまとめると、失敗時の切り分けが効かなくなる。Council 不要の代わりに「小さく進めて都度ゲート」が原則
- **新規デザイン生成は委ねる**: 「ゼロから作って」系の要求は `frontend-design`（外部プラグイン）にハンドオフ。このスキルは既存の統一・修正に徹する
- **独自 focus スタイルを上書きしない**: `.me-field` のような用途別 focus 設定は保護。グローバル `:focus-visible` はそれらを除外する outline ルールで入れる
- **小規模タスクで Step 1 を飛ばさない**: 1 ファイル 5 行の修正なら AskUserQuestion なしで進むのは OK だが、「複数画面」「方針未確定」なら必ず Step 1 で確認

<!-- AUTO-GOTCHAS -->

---

**Step 1 の対象 + 方針確認から開始してください。**
