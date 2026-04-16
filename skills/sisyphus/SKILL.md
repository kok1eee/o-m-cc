---
name: sisyphus
description: "計画→実装→品質ゲートまで止まらない Sisyphus ワークフロー。Agent Teams で要件→設計→タスク分解→実装→quality-gate を一括実行。新機能開発や設計判断が必要な変更に使う。「計画して」「この機能を実装したい」「新機能を作りたい」「要件から実装まで」で発動。"
argument-hint: "<feature description>"
allowed-tools: [Read, Write, Edit, Glob, Grep, WebSearch, WebFetch, TaskCreate, TaskUpdate, Monitor, AskUserQuestion, Agent, TeamCreate, TeamDelete, SendMessage, Skill, PushNotification]
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
   validate-plan requirements
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
   validate-plan design
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

各タスクを以下のループで消化する。**実装者の「通ったはず」は信用しない。verification（自己エビデンス収集）+ Verifier（独立視点）の二段階で検証する。**

1. 実装
2. `Skill: verification` — 実装者自身がエビデンスを収集（Iron Law: 検証コマンドを実行し出力を確認するまで完了宣言しない）
3. verification 通過 → Verifier spawn（独立視点で adversarial 検証）
4. Verifier 通過 → 次のタスク
5. verification or Verifier fail → Debugger spawn → 修正 → 再検証（最大2回）
6. Debugger 2回失敗 → Experiment ループ（仮説→1変更→検証、最大3回）
7. 3回失敗 → AskUserQuestion（Headless なら [BLOCKED] 記録して次へ）

**verification と Verifier の役割分担**:
- **verification** (skill): 実装者自身の自己検証。構造化されたチェックリスト（IDENTIFY → RUN → READ → VERIFY → DECLARE）で証拠を収集。`Skill: verification` で呼び出すと自動実行される
- **Verifier** (agent): 独立したサブエージェントによる adversarial 検証。実装者のバイアスを排除

### Monitor 活用: テスト実行の非同期監視

Verifier がテストを実行する際、テストスイートが長時間（>10秒）かかる場合は **Monitor でテスト出力をストリーミング** する。テスト実行中にメインエージェントは次のタスクの準備（コード読み込み、実装方針の検討）を並行できる。

```
Monitor:
  description: "sisyphus verifier: test execution"
  timeout_ms: 300000
  persistent: false
  command: "<テストコマンド> 2>&1 | grep --line-buffered 'PASS\|FAIL\|ERROR\|test'"
```

**判断基準**: Verifier を Agent spawn で実行するのが基本。テストコマンドが既知で長時間の場合のみ、Verifier の代わりに Monitor でテスト結果を直接取得し、メインエージェントが判定する。

→ **詳細フロー（Agent prompt テンプレート含む）は reference.md を Read**

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

## Step 7: 学習 + クリーンアップ + 完了通知

全フェーズ完了後:

1. `/evolve` でスキルの Gotchas を更新（今回の実行で得た学びを反映）
2. `TaskList` で残っている全タスク（[TRACKING] タスク + 実装タスク）を `TaskUpdate: status → deleted` で削除
3. **長時間実行（目安: Phase 1 開始から 10 分以上経過、or EC2 バックグラウンド実行が想定される）**だった場合は、`PushNotification` で完了通知を送る。メッセージは行動可能な情報でリード（例: `sisyphus 完了: 12 ファイル変更、quality-gate 通過。jj git push 待ち`）。セッション開始から数分で完了した場合や `CLAUDE_NON_INTERACTIVE=1` でない場合（ユーザーが画面を見ている可能性大）は送らない。

> **PushNotification のポリシー**: `message <200 文字, status: "proactive"`。送信コスト（ユーザーの注意を奪う）があるので、err toward not sending。quality-gate **失敗** で止まった場合も「ユーザー判断が必要」として通知候補。

## 整合性チェック（CoDD inspired）

上流の plan ドキュメントが変更されたら、下流も更新する。依存チェーン:

```
requirements.md → design.md → tasks → implementation
```

- `validate-plan` が **staleness check** を行う（上流が下流より新しい場合に警告）
- 要件が変わったら design を再生成、design が変わったらタスクを再分解
- 実装中に要件変更が入った場合: 現在のタスクを完了 → 該当フェーズまで戻る

## Gotchas

- **plan/ の古いファイルが Council を混乱させる**: Step 0 で必ず `rm -f plan/requirements.md plan/design.md` を実行。前回の成果物が残っていると analyst が既存要件と新規要件を混同する
- **Agent Teams の name 未指定で SendMessage が silent loss**: spawn 時に `name` と `team_name` を必ず指定。未指定だと teammate にならず、SendMessage が `success: true` を返しつつメッセージが消える
- **Verifier を spawn せずに自分でテストを実行してしまう**: M-L タスクでは必ず別エージェントを spawn。自分でテストすると確認バイアスで問題を見落とす
- **Headless モードで AskUserQuestion を呼んでハング**: `CLAUDE_NON_INTERACTIVE=1` の確認を忘れずに

<!-- AUTO-GOTCHAS -->

---

**Step 0 のタスク登録から開始し、Step 1 で discovery-council を Skill chain で呼び出してください。各 CTA で形式チェック + 乖離確認（再実行は最大1回）。全フェーズ止まらない。完了後は Step 7 でタスクを削除。**
