---
name: feature-flow
description: "web アプリの機能を構造化して書き下すワークフロー。新規（最初から）と既存（途中から）の 2 モード対応。ユーザーストーリー → 先行事例調査（並列3エージェント） → データと操作 → 成功条件 → Spec + Reader Test の 5 フェーズ。「機能を考えたい」「機能定義したい」「web アプリ作りたい」「機能から設計したい」「新しい機能」で発動。※ 曖昧な状態の掘り下げは deep-interview、要件統合は discovery-council、設計は design を使う。"
argument-hint: "<feature description> [--new | --existing | --light]"
allowed-tools: [Agent, TeamCreate, TeamDelete, SendMessage, Read, Glob, Grep, Write, Edit, AskUserQuestion, WebSearch, WebFetch, Bash]
model: opus
effort: high
---

# Feature Flow - web アプリ機能定義ワークフロー

web アプリの機能を「型に沿って書き下す」ためのワークフロー。
Sisyphus フローの **入口**（discovery-council や design の前段）。

## 入力

`$ARGUMENTS` — 機能の概要 + オプションフラグ
- `--new`: 強制的に Mode 1（最初から）で実行
- `--existing`: 強制的に Mode 2（途中から）で実行
- `--light`: 並列エージェント調査と Reader Test を省略（軽量モード）

## 基本姿勢（Never agree easily）

ユーザーが「○○機能を作りたい」と言っても、すぐに乗らない。

- 本当にその機能が必要か？
- 既に世に存在するもので解決できないか？
- 既存の自プロジェクトで解決できないか？
- 「作らない」「買う」「OSS を使う」も正解の選択肢として常に残す

**1 つの機能を作るより、作らない判断ができる方が価値が高い場面がある。**

## Headless モード

`CLAUDE_NON_INTERACTIVE=1` または `-p` モードで実行されている場合、AskUserQuestion を使えない。
「機能定義は対話的な確認が必要です。対話モードで /feature-flow を実行してください」と案内して終了する。

---

## Phase 0: モード判定

カレントディレクトリに既存 web アプリのコードがあるかで Mode 1 / Mode 2 を判定する。

```bash
# 自動判定: 以下のどれかがあれば Mode 2 候補
ls package.json pyproject.toml Cargo.toml go.mod composer.json Gemfile 2>/dev/null
ls -d src app pages components 2>/dev/null
```

判定ロジック:
1. `--new` フラグ → Mode 1 確定
2. `--existing` フラグ → Mode 2 確定
3. 上記コマンドで何かヒット → Mode 2 をサジェスト
4. 何もなければ Mode 1 をサジェスト

最終決定は AskUserQuestion でユーザーに確認:

```yaml
AskUserQuestion:
  question: "どちらのモードで進めますか？"
  options:
    - "Mode 1: 最初から（新規 web アプリ）"
    - "Mode 2: 途中から（既存アプリに機能追加）"
```

---

## Phase A: ユーザーストーリー（共通）

3 問。1 問ずつ AskUserQuestion で確認する。

### A1. WHO — 誰が使う？

```yaml
AskUserQuestion:
  question: "この機能を使うのは主に誰ですか？役割・習熟度・人数感を教えてください。"
  options:
    - "個人ユーザー（不特定多数、習熟度バラバラ）"
    - "社内スタッフ（特定の役割、ある程度習熟）"
    - "管理者・運用担当（少人数、深い習熟）"
    - "外部 API クライアント（人ではなくプログラム）"
    - "自由記述"
```

### A2. WHEN — どんな場面で？

```yaml
AskUserQuestion:
  question: "どんな場面・トリガー・頻度で使われますか？"
  options:
    - "毎日のルーチン（朝・夕など定時）"
    - "特定イベント発生時（注文、申請、エラーなど）"
    - "気になった時にいつでも（不定期）"
    - "バッチ処理（自動・定期）"
    - "自由記述"
```

### A3. GOAL — 何を達成したい？

ここは選択式にしない。**手段ではなく結果**を聞く。

```yaml
AskUserQuestion:
  question: |
    この機能で「結果として何が達成できれば成功」ですか？
    手段（○○画面を作る等）ではなく、ユーザーが得る結果を答えてください。
  options:
    - "自由記述（必須）"
```

### A の挑発（Never agree easily）

3 問終わったら、必ず一度問い直す:

```yaml
AskUserQuestion:
  question: |
    確認したいことがあります。

    今のユーザーストーリーを踏まえると、この機能を作らずに以下で代用できる可能性はありませんか？
    - 既存のサービス・ツール
    - スプレッドシートや手動運用
    - 自分が既に持っているアプリの拡張

    本当に新しい機能を作る必要がありますか？
  options:
    - "作る必要がある（理由を一言で）"
    - "考え直したい（一旦中断）"
    - "Phase B (先行事例調査) の結果を見てから判断したい"
```

「考え直したい」を選択した場合はワークフローを中断、メモを残して終了。

---

## Phase B: 先行事例調査（モード分岐 + 並列3エージェント）

`--light` フラグ時はこのフェーズを省略可能（その場合はユーザーに事前確認）。

### Mode 1: 最初から（外向き並列3エージェント）

> **リファレンス**: `reference.md` の "Mode 1 Agent Prompts" を Read して使用

3 エージェント同時 spawn:
- **market-researcher**: 商用 SaaS / 既製アプリの調査
- **oss-scout**: OSS / GitHub での類似実装
- **pattern-observer**: UI/UX パターンの観察

```
TeamCreate:
  team_name: "feature-flow-prior-art"
  description: "Phase B: 先行事例調査（外向き）"
```

3 エージェントを並列 spawn（reference.md のテンプレート参照）。
全エージェントの完了を待ってから統合レポートを作成する。

### Mode 2: 途中から（内向き並列3エージェント）

> **リファレンス**: `reference.md` の "Mode 2 Agent Prompts" を Read して使用

3 エージェント同時 spawn:
- **code-explorer**: 類似機能のエントリポイントから実装をトレース
- **architecture-mapper**: 既存抽象境界・データモデルの把握
- **convention-scout**: 命名規則・配置・テストパターンの抽出

```
TeamCreate:
  team_name: "feature-flow-prior-art"
  description: "Phase B: 既存コード探索（内向き）"
```

### B1: 統合レポート提示

各エージェントの報告をメインエージェントが統合し、ユーザーに提示する。

```markdown
## 先行事例調査 結果（統合）

### Market Research（Mode 1 のみ）
...

### OSS Scout（Mode 1 のみ）
...

### Pattern Observer（Mode 1 のみ）
...

### Code Explorer（Mode 2 のみ）
...

### Architecture Mapper（Mode 2 のみ）
...

### Convention Scout（Mode 2 のみ）
...

### 統合所見
- 採用すべきパターン
- 避けるべきパターン
- 「作る vs 既存活用」の暫定判断
```

### B2: 補足と方針決定

```yaml
AskUserQuestion:
  question: "知っている類似品・参考実装が他にあれば教えてください（無ければ "なし"）"
  options:
    - "なし"
    - "自由記述"
```

```yaml
AskUserQuestion:
  question: |
    調査結果を踏まえて、どの方針で進めますか？

    Mode 1 の場合:
    - a) 差別化ポイントを定めて自作する
    - b) 差別化不要、既存パターンを参考に車輪再発明する
    - c) 既存サービス / OSS を採用して撤退する

    Mode 2 の場合:
    - a) 既存の類似機能のパターンに沿って自作
    - b) 既存ライブラリ / 内部モジュールの拡張で済ませる
    - c) 既に同等機能が存在、撤退する
  options:
    - "a (自作 / 拡張)"
    - "b (既存に乗る / 既存モジュール活用)"
    - "c (撤退する)"
    - "自由記述"
```

「c (撤退)」の場合はワークフローを中断、撤退理由をメモして終了。

---

## Phase C: データと操作（共通）

3 問。

### C1. INPUT — 何を入力する？

```yaml
AskUserQuestion:
  question: "ユーザーがこの機能に何を入力しますか？データ種別・取得元を教えてください。"
  options:
    - "フォーム入力（テキスト・数値・選択）"
    - "ファイルアップロード（画像・CSV・PDF など）"
    - "外部 API・連携サービスから取得"
    - "別画面・別機能の出力をそのまま渡す"
    - "ユーザー入力なし（自動生成 / バッチ）"
    - "自由記述"
```

### C2. OUTPUT — 何を返す / 表示する？

```yaml
AskUserQuestion:
  question: "この機能の結果として、ユーザーに何が返りますか / 何が表示されますか？"
  options:
    - "一覧表示（テーブル・カード・カンバン）"
    - "詳細表示（単一エンティティ）"
    - "ファイル生成・ダウンロード"
    - "別システムへ通知・送信（実体は裏側）"
    - "状態変更のみ（UI 上は完了通知）"
    - "自由記述"
```

### C3. STATE — 何を保存する？

```yaml
AskUserQuestion:
  question: |
    保存対象を整理します。以下の観点で答えてください。
    - 永続化すべきデータは何か（DB に残す）
    - 揮発で OK のデータは何か（セッション・キャッシュ）
    - 保存しないもの（明示的に消す）
  options:
    - "自由記述（必須）"
```

Mode 2 の場合、architecture-mapper の出力を踏まえて「既存モデルとの整合性」を 1 文で言及する。

---

## Phase D: 成功条件（共通）

2 問。

### D1. DONE — どうなったら「できた」と言える？

```yaml
AskUserQuestion:
  question: |
    この機能の Definition of Done を、観測可能な条件で答えてください。
    （「ユーザーが X を入力して Y が返れば OK」のような形）
  options:
    - "自由記述（必須）"
```

### D2. NON-GOALS — 今回やらないことは？

```yaml
AskUserQuestion:
  question: |
    今回スコープ外にすることを明示してください。
    （「○○は将来の拡張、○○は別機能で扱う」のような形）
  options:
    - "なし（全部やる）"
    - "自由記述"
```

---

## Phase E: Spec 書き出し + Reader Test

### E1: spec ファイル作成

`plan/YYYY-MM-DD-feature-<slug>.md` に書き出す（slug は機能名から自動生成）。

スキーマ:

```markdown
# Feature: <name>

- Mode: <1: 最初から / 2: 途中から>
- 作成日: YYYY-MM-DD

## A. ユーザーストーリー
- WHO: ...
- WHEN: ...
- GOAL: ...

## B. 先行事例調査
### 調査結果サマリー
- Mode 1: market / oss / pattern observer の要約
- Mode 2: code-explorer / architecture-mapper / convention-scout の要約

### 方針
- 採用する方針: a / b / c
- 採用理由: ...
- 採用すべきパターン: ...
- 避けるべきパターン: ...

## C. データと操作
- INPUT: ...
- OUTPUT: ...
- STATE: ...
- （Mode 2）既存モデルとの整合性: ...

## D. 成功条件
- DONE: ...
- NON-GOALS: ...

## E. ハンドオフ候補
- 次フェーズ: discovery-council / design / 直接実装
- 関連 reference:
  - Mode 2 の場合は code-explorer が示した重要ファイル一覧
```

### E2: Reader Test

`--light` フラグ時は省略可能。

フレッシュな agent に spec を読ませて、解釈一致を確認する。

```
Agent:
  subagent_type: "general-purpose"
  name: "spec-reader"
  description: "Reader Test: spec の解釈一致確認"
  prompt: |
    あなたは初見のレビュアーです。

    ## タスク
    plan/YYYY-MM-DD-feature-<slug>.md を読んで、以下の 4 点を答えてください:
    1. この機能で「誰が」「何のために」「何を達成」するのか
    2. 入力・出力・保存対象は何か
    3. どうなったら「できた」と言えるか
    4. 読んでも不明確だった点・解釈に迷った点（あれば）

    ## 出力
    上記 4 点を簡潔に。3 と 4 が特に重要。
```

メインエージェントが Reader の応答を受けて:
- 解釈が spec と一致 → Phase E3 へ
- 解釈にズレあり / 不明確箇所あり → 該当 Phase に戻って修正、再 Reader Test

### E3: ハンドオフ提示

```yaml
AskUserQuestion:
  question: |
    Spec が完成しました（plan/YYYY-MM-DD-feature-<slug>.md）。
    次に何を進めますか？
  options:
    - "discovery-council で要件統合（複数機能を束ねたい）"
    - "design でアーキテクチャ設計に進む"
    - "直接実装に進む（軽い機能のため）"
    - "一旦ここで止める（後で再開）"
    - "自由記述"
```

選択結果に応じて該当スキルを Skill ツールで起動するか、案内のみで終了する。

---

## Gotchas

- **Phase A の挑発を省かない**: ユーザーが既に乗り気でも、必ず一度は「作らない選択肢」を提示する。これがコスト最小で質を上げる
- **Phase B のエージェント並列を foreground で待つ**: background のまま次フェーズに進むと統合レポートが空になる
- **Mode 判定で誤検出**: `node_modules` だけある（package.json は無い）状態などで Mode 2 と誤判定しがち。明示確認を必ず取る
- **Reader Test の解釈ズレを放置しない**: spec の質は将来のナレッジ価値に直結。ズレがあれば必ず該当 Phase に戻る
- **`--light` の使い時**: 30 分以内で実装できる軽い機能 / プロトタイプ用途に限る。本番機能では並列調査と Reader Test を省略しない

<!-- AUTO-GOTCHAS -->

## 出力

- `plan/YYYY-MM-DD-feature-<slug>.md`
