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

## Step 5: 実装 → テスト → 修正ループ

各タスクを以下のループで消化する。**テストが通るまで次のタスクに進まない。**

タスク規模に応じて実行方式を選択：

| 規模 | 判断基準 | 方式 |
|------|---------|------|
| **S** | 1-2ファイルの修正、設定変更、軽微な追加 | **直接方式**: 自分で実装 → テスト → 修正 |
| **M-L** | 新機能、3ファイル以上、新コンポーネント作成 | **3エージェント方式**: Implementer → Verifier → Debugger |

### S: 直接方式

```
実装 → テスト → 失敗なら修正 → テスト → 成功 → 次のタスク
```

### M-L: 3エージェント方式

確認バイアスを排除するため、役割を分離する。

```
1. 自分（Sisyphus）が実装する

2. Verifier（検証者）を spawn — adversarial な検証
   Agent: subagent_type=general-purpose
   prompt: "以下の変更を検証してください。テストを実行し、
   エッジケースを探し、壊せるか試してください。
   証拠（コマンド出力）付きで合否を報告。
   書いた人の「動くはず」は信用しないこと。"

3. Verifier が pass → 次のタスク
   Verifier が fail →

4. Debugger を spawn — 先入観なしの修正
   Agent: subagent_type=o-m-cc:debugger
   prompt: "Verifier が以下の問題を報告しました。
   コードが何をしているかだけを見て根本原因を特定し修正してください。
   修正後、テストを実行して結果を報告。"

5. Debugger の修正を Verifier に再検証させる（Implementer ではない）
   → pass なら次のタスク、fail なら 4 に戻る（最大2回）
```

**重要**: Debugger の修正結果は **Verifier に戻す**。修正者の「直した」を信用しない。

### 共通ルール

- タスク着手時: `in_progress`、同時に `in_progress` は1つだけ
- **実装後は必ずテストを実行する**。テストコマンドはプロジェクトの CLAUDE.md やファイル構成から特定する（`npm test`, `pytest`, `cargo test` 等）
- 3エージェント方式で Verifier → Debugger を2回繰り返しても通らない場合は、AskUserQuestion でユーザーに相談（Headless なら `[BLOCKED]` としてタスクに記録し次に進む）
- テスト成功時、実行結果（コマンド + 出力）をタスクの完了証拠とする
- テストが存在しないプロジェクトでは、実装後に動作確認（ビルド成功、エラーなし等）で代替する

## Step 6: Quality Gate

→ `TaskUpdate: Phase 4 → completed`, `TaskUpdate: Phase 5 → in_progress`

```
Skill: quality-gate
```

→ 通過後: `TaskUpdate: Phase 5 → completed`

## Step 7: クリーンアップ

全フェーズ完了後、`TaskList` で残っている全タスク（[TRACKING] タスク + 実装タスク）を `TaskUpdate: status → deleted` で削除する。

---

**Step 0 のタスク登録から開始し、Step 1 で discovery-council を Skill chain で呼び出してください。各 CTA で形式チェック + 乖離確認（再実行は最大1回）。全フェーズ止まらない。完了後は Step 7 でタスクを削除。**
