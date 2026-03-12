---
title: "Claude Code Auto Mode × Sisyphus Loop — 権限プロンプトすら止められない開発ループ"
emoji: "🏔️"
type: "tech"
topics: ["ClaudeCode", "AI", "自動化", "o-m-cc"]
published: true
---

## TL;DR

Claude Code に **Auto Mode**（`--permission-mode auto`）が登場した。これと o-m-cc の **Sisyphus Loop** を組み合わせると、「タスク完了まで本当に止まらない」自律開発が実現する。

## 権限プロンプト、何回 Yes 押しましたか？

Claude Code で長めのタスクを回していると、こんな確認が何度も出てくる。

```
Do you want to proceed?
❯ 1. Yes
  2. Yes, and don't ask again for: ...
  3. No
```

「毎回 Yes を押すのが面倒だから…」と `--dangerously-skip-permissions` を使ったことがある人、少なくないと思う。

このフラグ、名前からして怖いが、Anthropic も公式に「リスクが高い」と明言しているやつだ。それでも使ってしまうくらい、承認ダイアログが邪魔に感じる場面があるのも事実。

## Auto Mode とは

Auto Mode は、Claude がパーミッションの判断を**自律的に行う**新しいモード。`--dangerously-skip-permissions` の代替として設計されている。

```bash
# 起動方法
claude --permission-mode auto
```

> **注意**: 一部の記事で `--enable-auto-mode` と紹介されているが、実際のフラグは `--permission-mode auto`。

### `--dangerously-skip-permissions` との違い

|  | `--dangerously-skip-permissions` | Auto Mode |
|--|---|---|
| **判断者** | なし（すべてスキップ） | Claude 自身 |
| **安全性** | すべて許可 | リスクに応じて判断 |
| **プロンプトインジェクション対策** | なし | あり |

## 何を許可し、何をブロックするのか

Auto Mode は「なんでも許可」ではない。`claude auto-mode defaults` で確認できるルールセットが組み込まれている。

### Allow（自動承認）

| ルール | 説明 |
|--------|------|
| **Local Operations** | プロジェクトスコープ内のファイル操作 |
| **Read-Only Operations** | GET リクエスト、状態を変更しないAPI呼び出し |
| **Declared Dependencies** | マニフェストに宣言済みのパッケージインストール（`npm install`, `pip install -r` 等） |
| **Git Push to Working Branch** | 作業ブランチへの push（デフォルトブランチ以外） |
| **Test Artifacts** | テスト用のハードコードされたAPIキーやプレースホルダー |

### Deny（ブロック）

| ルール | 説明 |
|--------|------|
| **Git Destructive** | `git push --force`、リモートブランチ削除 |
| **Git Push to Default Branch** | main/master への直接 push |
| **Code from External** | `curl \| bash` など外部コードの実行 |
| **Production Deploy** | 本番デプロイ、本番DBマイグレーション |
| **Self-Modification** | `.claude/` 設定の自己改変 |
| **Data Exfiltration** | 機密データの外部送信 |
| **Credential Exploration** | 認証情報ストアの探索 |
| **External System Writes** | 外部ツール（Jira, GitHub issue 等）への書き込み |

特に面白いのは **Self-Modification** のルール。Claude が自分自身の設定を書き換えて権限を昇格させる、というシナリオを明示的にブロックしている。

全ルールは `claude auto-mode defaults` で確認できる。かなり長いが、一読の価値あり。

## Sisyphus Loop × Auto Mode = 止まらない開発

ここからが本題。

[o-m-cc](https://github.com/kok1eee/o-m-cc) は Claude Code 用のマルチエージェントプラグインで、**Sisyphus Loop**（タスク完了まで止まらないワークフロー）を提供する。

```
要件定義 → 設計 → タスク分解 → 実装 → /simplify → レビュー → 完了
                                    ↑                          |
                                    └──── stop-guard ──────────┘
```

### 従来の問題

Sisyphus Loop は「止まらない」ことが哲学だが、実際には **2つの理由** で止まっていた：

1. **権限プロンプト** — ファイル書き込み、シェルコマンド実行のたびに承認が必要
2. **Claude の早期終了** — Claude が「完了しました」と言って止まる

(2) は stop-guard（diff ベースの品質ゲート強制）で解決済み。残る問題は (1) だった。

### Auto Mode で (1) が解消される

```bash
# これだけで、権限プロンプトなしの Sisyphus Loop が回る
claude --permission-mode auto

# o-m-cc のセットアップ後
/o-m-cc:sisyphus ログイン画面のバグを修正して
```

Auto Mode により、Sisyphus Loop 中の以下の操作が自動承認される：

- ソースコードの読み書き（Local Operations）
- テストの実行（Local Operations）
- `jj` / `git` での差分確認（Read-Only Operations）
- 作業ブランチへの push（Git Push to Working Branch）

一方、危険な操作はブロックされる：

- main への直接 push → PR 経由を強制
- 外部パッケージの勝手なインストール → マニフェスト宣言済みのみ許可
- `.claude/` 設定の改変 → Self-Modification ブロック

つまり、**Sisyphus の「止まらない」哲学と、Auto Mode の「安全に自律判断」が噛み合う**。

### 実際のフロー

```
ユーザー: /o-m-cc:sisyphus APIのエラーハンドリングを追加して

  [Discovery Council]
    researcher → コードベース調査 ← 自動承認（Read-Only）
    analyst → 要件整理 ← 自動承認（Read-Only）
    scout → ギャップ分析 ← 自動承認（Read-Only）

  [Design & Planning]
    designer → 設計書作成 ← 自動承認（Local Operations）
    planner → タスク分解 ← 自動承認（Local Operations）

  [Implementation]
    ソースコード編集 ← 自動承認（Local Operations）
    テスト実行 ← 自動承認（Local Operations）
    /simplify ← 自動承認（Local Operations）

  [Quality Gate]
    stop-guard → diff 検知 → /quality-gate 強制
    code-reviewer → レビュー ← 自動承認（Read-Only）
    security-reviewer → セキュリティチェック ← 自動承認（Read-Only）

  [完了]
    作業ブランチに push ← 自動承認（Git Push to Working Branch）

→ 一度も権限プロンプトが出ない
```

## 設定の確認方法

Auto Mode のルールは CLI から確認できる。

```bash
# 現在の effective な設定（ユーザーカスタマイズ含む）
claude auto-mode config

# デフォルトのルールセット
claude auto-mode defaults
```

出力は `allow`, `deny`, `environment` の3セクション。全ルールが自然言語で記述されており、読めば何が許可/ブロックされるか分かる。かなり長いが一読の価値あり。

### カスタマイズはできるのか？（バイナリ解析してみた）

公式ドキュメントにカスタマイズ方法はまだ掲載されていない（2026-03-12 時点）。

気になったのでバイナリを `strings` で覗いてみた。classifier のシステムプロンプト内に以下のテンプレートが埋め込まれている：

```
<user_allow_rules_to_replace>
  - Test Artifacts: ...
  - Local Operations: ...
  ...
</user_allow_rules_to_replace>

<user_deny_rules_to_replace>
  - Git Destructive: ...
  ...
</user_deny_rules_to_replace>

<user_environment_to_replace>
  - **Trusted repo**: ...
  - **Source control**: ...
  - **Trusted internal domains**: None configured
  - **Trusted cloud buckets**: None configured
  - **Key internal services**: None configured
</user_environment_to_replace>
```

ユーザー設定の読み込み部分は Zod で `{allow: string[], deny: string[], environment: string[]}` のスキーマが定義されており、**カスタマイズ可能な構造にはなっている**。ただし settings.json のどのキーに書くかは難読化されていて特定できなかった。`claude auto-mode config` と `claude auto-mode defaults` の出力が同一だったので、現時点ではカスタマイズ UI がまだ公開されていない可能性が高い。

リサーチプレビューなので、今後 settings.json に書ける形で公開されるはず。

## 実際に引っかかるポイント

デフォルトルールをそのまま使うと、一部のワークフローで想定外のブロックが起きる。自分の環境で引っかかりそうなポイントを整理した。

### main への直接 push がブロックされる

Deny ルールに「**Git Push to Default Branch**: Pushing directly to main, master, or the repository's default branch」がある。

個人開発で main に直接 push するワークフロー（`jj bookmark set main && jj git push` 等）は、Auto Mode ではブロック対象になる。feature ブランチ経由に変更するか、カスタマイズが公開されたらこのルールを外す必要がある。

### 外部システムへの書き込みが制限される

「**External System Writes**: Deleting, resolving, closing, or mass-modifying items in external collaboration tools (Jira, Asana, Linear, PagerDuty, Datadog, GitHub issues/PRs, etc.) that the agent did not create in this session」

つまり、**セッション中に自分が作った issue やPR 以外への書き込みはブロックされる**。既存の PR にコメントする、既存の issue をクローズするといった操作は引っかかる可能性がある。

### `.claude/` 設定の自己改変がブロックされる

「**Self-Modification**: Modifying the agent's own configuration, settings, or permission files (e.g. settings.json, CLAUDE.md permission overrides, .claude/ config)」

これは o-m-cc の `/o-m-cc:init` スキル（`.claude/settings.json` にパーミッションを書き込む）に影響する。init は Auto Mode を有効にする前に実行するか、一時的に default モードに戻して実行する必要がある。

## 注意点

### リサーチプレビュー段階

Auto Mode はまだリサーチプレビュー。Anthropic の公式アナウンスにもこう書かれている：

> Auto mode isn't perfect and it won't catch every action that could be considered risky, so we recommend using it only in isolated environments.

### コスト増

Auto Mode は各アクションでリスク評価を行うため、トークン使用量がわずかに増加する。Sisyphus Loop は元々トークン消費が大きい（大規模タスクで 1M-3M tokens）ので、Auto Mode の追加コストは相対的には小さいが、意識はしておくべき。

## まとめ

| 組み合わせ | 止まる理由 |
|-----------|-----------|
| Claude Code 素 | 権限プロンプト + 早期終了 |
| + `--dangerously-skip-permissions` | 早期終了（でも全部許可は怖い） |
| + o-m-cc (Sisyphus Loop) | 権限プロンプト（stop-guard で早期終了は解決） |
| **+ o-m-cc + Auto Mode** | **止まらない（安全に）** |

Auto Mode と Sisyphus Loop は、それぞれ別の「止まる理由」を解決する。組み合わせることで、初めて「安全に止まらない」自律開発が実現する。

```bash
# セットアップ
claude plugin marketplace add kok1eee/o-m-cc
claude plugin install o-m-cc@kok1eee
/o-m-cc:init

# 起動
claude --permission-mode auto

# あとは依頼するだけ
/o-m-cc:sisyphus ログイン画面のバグを修正して
```

リサーチプレビューが GA になったら、これがデフォルトの開発スタイルになるかもしれない。

---

*2026-03-12 リサーチプレビュー公開日に執筆。カスタマイズ方法や実際の挙動は今後のアップデートで変わる可能性があります。*
