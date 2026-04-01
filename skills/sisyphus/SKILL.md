---
name: sisyphus
description: "計画→実装→品質ゲートまで止まらない Sisyphus ワークフロー。Agent Teams で要件→設計→タスク分解→実装→quality-gate を一括実行。「計画して」「この機能を実装したい」で発動。"
argument-hint: "<feature description>"
allowed-tools: [Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TaskCreate, TaskUpdate, AskUserQuestion, Agent, TeamCreate, TeamDelete, SendMessage, Skill]
model: opus
effort: high
context: fork
---

# Sisyphus - 仕様駆動開発オーケストレーター

各 Phase を独立スキルとして chain 実行し、計画→実装→品質ゲートまで止まらない。

## 機能

$ARGUMENTS

## プロジェクト状態（動的注入）

### 変更統計
!`jj diff --stat 2>/dev/null || git diff --stat HEAD 2>/dev/null || echo "変更なし"`

### 最近のコミット
!`jj log -r 'ancestors(@, 5)' --no-graph 2>/dev/null || git log --oneline -5 2>/dev/null || echo "履歴なし"`

## Headless モード

`CLAUDE_NON_INTERACTIVE=1` または `-p` モードで実行されている場合、AskUserQuestion を使わない。全自動で完了まで止まらない。

---

## Step 0: 初期化

**plan/ の掃除**: 前回の sisyphus 実行で残った plan/ 内のファイル（requirements.md, design.md）を削除する。古いドキュメントが残っていると Council が混乱する。

```bash
rm -f plan/requirements.md plan/design.md
```

**[TRACKING] タスク登録**:

```
TaskCreate: "[TRACKING] Phase 1: Discovery Council（要件分析）"
TaskCreate: "[TRACKING] Phase 2: 設計"
TaskCreate: "[TRACKING] Phase 3: タスク分解"
TaskCreate: "[TRACKING] Phase 4: 実装"
TaskCreate: "[TRACKING] Phase 5: Quality Gate"
```

> [TRACKING] タスクは進捗管理用。Skill chain 開始前に登録すること。

## Step 1: Phase 1 - Discovery Council

→ `TaskUpdate: Phase 1 → in_progress`

```
Skill: discovery-council
```

**CTA**（再実行は最大1回。品質が崩れたら止まる）:
1. 自動形式チェック:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/hooks/validate-plan.sh requirements
   ```
2. **形式チェック失敗** → 1回だけ discovery-council を再実行 → 再度形式チェック
3. **形式チェック通過** → requirements.md を Read し、$ARGUMENTS と内容に重大な乖離がないか確認
4. 2回目も失敗 or 乖離あり → **Headless モードでなければ AskUserQuestion で人間に判断を委ねる**。Headless なら不足点を `## 既知の不足` として追記し先に進む

## Step 2: Phase 2 - 設計

→ `TaskUpdate: Phase 1 → completed`, `TaskUpdate: Phase 2 → in_progress`

```
Skill: design
```

**CTA**（再実行は最大1回。品質が崩れたら止まる）:
1. 自動形式チェック:
   ```bash
   bash ${CLAUDE_PLUGIN_ROOT}/hooks/validate-plan.sh design
   ```
2. **形式チェック失敗** → 1回だけ design を再実行 → 再度形式チェック
3. **形式チェック通過** → design.md を Read し、requirements.md との重大な乖離がないか確認
4. 2回目も失敗 or 乖離あり → **Headless モードでなければ AskUserQuestion で人間に判断を委ねる**。Headless なら不足点を `## 既知の不足` として追記し先に進む

## Step 3: Phase 3 - タスク分解

→ `TaskUpdate: Phase 2 → completed`, `TaskUpdate: Phase 3 → in_progress`

```
Skill: task-decomposition
```

**CTA**（再実行は最大1回。品質が崩れたら止まる）:
1. TaskList で登録されたタスクを確認
2. design.md の主要コンポーネントに対応するタスクが存在するか確認
3. 重大な欠落があれば1回だけ再実行
4. 2回目でも不完全なら、**Headless モードでなければ AskUserQuestion で人間に判断を委ねる**。Headless なら `[NOTE] 設計で言及あるが未タスク化: ...` を TaskCreate で記録し先に進む

## Step 4: 実行方式の自動選択

→ `TaskUpdate: Phase 3 → completed`, `TaskUpdate: Phase 4 → in_progress`

以下の**すべて**に該当 → **`/batch` で並列実行**：
- 独立した同種の変更が **5件以上**
- 各タスクが **他のタスクに依存しない**
- 各タスクが **同じパターンの繰り返し**

それ以外 → **通常の Sisyphus Loop で直列実行**

## Step 5: 実装 → 検証 → 修正ループ

各タスクを以下のループで消化する。**全タスクで Verifier による検証を行う。自分でテストして「通った」と言わない。**

```
┌──────────────────────────────────────────────────┐
│  タスク N                                         │
│                                                  │
│  1. 自分（Sisyphus）が実装する                      │
│                                                  │
│  2. Verifier を spawn — adversarial な検証          │
│     Agent: subagent_type=general-purpose           │
│     prompt: "以下の変更を検証してください。           │
│     テストを実行し、エッジケースを探し、              │
│     壊せるか試してください。                         │
│     証拠（コマンド出力）付きで合否を報告。            │
│     書いた人の「動くはず」は信用しないこと。           │
│     TODO/FIXME/後で実装 等の先送りがあれば fail。     │
│     繰り返し発見したパターンは memory に保存せよ。"    │
│                                                  │
│  3. Verifier が pass → 次のタスク                   │
│     Verifier が fail ↓                             │
│                                                  │
│  4. Debugger を spawn — 先入観なしの修正             │
│     Agent: subagent_type=o-m-cc:debugger           │
│     prompt: "Verifier が以下の問題を報告しました。    │
│     コードが何をしているかだけを見て                  │
│     根本原因を特定し修正してください。                │
│     修正後、テストを実行して結果を報告。"             │
│                                                  │
│  5. Debugger の修正を Verifier に再検証させる         │
│     → pass なら次のタスク                           │
│     → fail なら 4 に戻る（最大2回）                  │
│     → 2回失敗 → experiment ループに切り替え          │
│                                                  │
│  6. Experiment ループ（試行錯誤モード）               │
│     原因不明で Debugger が修正できない場合:           │
│     仮説を立てる → 1変更 → Verifier 検証             │
│     → pass なら次のタスク                           │
│     → fail なら revert して別の仮説（最大3回）        │
│     → 3回失敗 → AskUserQuestion                    │
│       （Headless なら [BLOCKED] 記録して次へ）        │
└──────────────────────────────────────────────────┘
```

**重要**: Debugger の修正結果は **Verifier に戻す**。修正者の「直した」を信用しない。

### ルール

- タスク着手時: `in_progress`、同時に `in_progress` は1つだけ
- **自分でテストを実行して「通った」と言わない**。必ず Verifier に検証させる
- テストコマンドは Verifier が プロジェクトの CLAUDE.md やファイル構成から特定する（`npm test`, `pytest`, `cargo test` 等）
- テスト成功の証拠は **Verifier の報告**（コマンド出力付き）のみ
- テストが存在しないプロジェクトでは、Verifier がビルド成功・エラーなし等を確認する

## Step 6: Quality Gate

→ `TaskUpdate: Phase 4 → completed`, `TaskUpdate: Phase 5 → in_progress`

```
Skill: quality-gate
```

→ 通過後: `TaskUpdate: Phase 5 → completed`

## Step 7: クリーンアップ

全フェーズ完了後、`TaskList` で残っている全タスク（[TRACKING] タスク + 実装タスク）を `TaskUpdate: status → deleted` で削除する。

## 整合性チェック（CoDD inspired）

上流の plan ドキュメントが変更されたら、下流も更新する。依存チェーン:

```
requirements.md → design.md → tasks → implementation
```

- validate-plan.sh が **staleness check** を行う（上流が下流より新しい場合に警告）
- 要件が変わったら design を再生成、design が変わったらタスクを再分解
- 実装中に要件変更が入った場合: 現在のタスクを完了 → 該当フェーズまで戻る

## Gotchas

- **plan/ の古いファイルが Council を混乱させる**: Step 0 で必ず `rm -f plan/requirements.md plan/design.md` を実行。前回の成果物が残っていると analyst が既存要件と新規要件を混同する
- **Agent Teams の name 未指定で SendMessage が silent loss**: spawn 時に `name` と `team_name` を必ず指定。未指定だと teammate にならず、SendMessage が `success: true` を返しつつメッセージが消える
- **Verifier を spawn せずに自分でテストを実行してしまう**: M-L タスクでは必ず別エージェントを spawn。自分でテストすると確認バイアスで問題を見落とす
- **quality-gate の proof ファイルが前セッションの残骸**: session-baseline.sh がセッション開始時にクリアするが、同一セッション内で2回 sisyphus を実行すると前回の proof が残る。Step 0 で手動クリアすべき
- **Headless モードで AskUserQuestion を呼んでハング**: `CLAUDE_NON_INTERACTIVE=1` の確認を忘れずに

---

**Step 0 のタスク登録から開始し、Step 1 で discovery-council を Skill chain で呼び出してください。各 CTA で形式チェック + 乖離確認（再実行は最大1回）。全フェーズ止まらない。完了後は Step 7 でタスクを削除。**
