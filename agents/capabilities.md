# Agent Capabilities

エージェント能力のサマリー。planner によるエージェント選択、および小タスクでのキーワードマッチに使用。

## エージェントの原則

エージェントは**コンテキストファイアウォール**。大量の情報を処理し、要約だけをメインスレッドに返す。

```
エージェントなし:
メインスレッドが10ファイル読む → コンテキスト爆発 → 一貫性喪失

エージェントあり:
エージェントが10ファイル読む → メインスレッドは要約1つ受け取る → コンテキスト維持
```

### やるべきこと
- **単一目的** — 1つのエージェントに1つの仕事
- **コンテキスト削減** — 処理した情報の10-20%だけ返す
- **Input → Processing → Output** を明確に定義

### やってはいけないこと
- ❌ エージェント同士を直接通信させる（コーディネーターを使う）
- ❌ 大量の生出力を返す（要約して返す）
- ❌ 単純なタスクにエージェントを使う（コンテキスト削減が不要なら直接やる）

---

## 使用方法

### 小タスク（plan なし）
ユーザーリクエストのキーワードでマッチ → 該当エージェントを直接呼び出し

### plan あり
得意分野・使用場面を参照 → orchestration.yml にエージェントを設定

---

## エージェント一覧

| エージェント | 得意分野 | いつ使うか | キーワード |
|-------------|---------|-----------|-----------|
| **explore** | 高速検索・構造把握 | コードベース調査、ファイル探索 | 探索, 検索, どこ, 構造, find, search |
| **analyst** | 現状分析・要件整理 | 新機能の計画前、要件定義作成 | 要件, 分析, 調査, requirements |
| **designer** | アーキテクチャ設計 | 要件定義完成後、実装の前 | 設計, アーキテクチャ, design |
| **planner** | タスク分解 | 設計書完成後、実装に入る前 | 計画, タスク, 分解, plan, tasks |
| **scout** | ギャップ・スコープ分析 | 要件定義後、漏れや曖昧点の確認 | 漏れ, 曖昧, スコープ, gaps |
| **critic** | 計画検証 | 設計書・タスク分解が完成した後 | 検証, 妥当性, リスク, validate |
| **debugger** | 体系的デバッグ | バグ・テスト失敗・予期しない動作 | バグ, エラー, デバッグ, bug, error |
| **advisor** | 戦略判断・思考フレームワーク | 行き詰まり、3回修正しても未解決、前提を疑いたいとき | 相談, 困った, 行き詰まり, stuck, なぜ |
| **researcher** | 外部調査 | ライブラリの使い方、API仕様確認 | 調べて, 使い方, ベストプラクティス |
| **learnings-researcher** | 過去の学び検索 | 実装前の知識確認、類似バグ調査 | 前回, 学び, 同じミス, 教訓 |
| **frontend** | UI実装 | React/Vue コンポーネント作成 | UI, 画面, コンポーネント, screen |
| **code-reviewer** | コード品質チェック | タスク完了後、マージ前 | レビュー, 品質, review, quality |
| **security-reviewer** | セキュリティチェック | 外部入力処理、認証実装の変更後 | セキュリティ, 脆弱性, security |
| **code-simplifier** | リファクタリング | 実装完了後、コードが複雑なとき | 簡素化, リファクタ, simplify |
| **document-writer** | ドキュメント作成 | 技術文書、API仕様、ガイド作成 | ドキュメント, 文書, docs |
| **vision** | 画像・PDF分析 | デザインモック、エラー画面解析 | 画像, スクショ, PDF, screenshot |

---

## カテゴリ別

### 分析・調査系（READ のみ）

| エージェント | Input | Processing | Output |
|-------------|-------|------------|--------|
| explore | ファイルパターン、検索キーワード | Glob/Grep で検索 | ファイル一覧、コード断片 |
| analyst | コードベース、ユーザー要求 | 構造分析、要件抽出 | requirements.md |
| researcher | 技術キーワード | Web検索、ドキュメント調査 | 調査レポート |
| scout | requirements.md | スコープ確認、ギャップ分析 | IN/OUT SCOPE + 質問リスト |
| learnings-researcher | タスク説明 | learned/ をGrep検索 | 関連する過去の知見 |
| vision | 画像/PDFファイル | 視覚分析 | 抽出情報レポート |

### 設計・計画系（READ のみ）

| エージェント | Input | Processing | Output |
|-------------|-------|------------|--------|
| designer | requirements.md | アーキテクチャ設計 | design.md |
| planner | design.md | タスク分解、依存関係整理 | tasks.md + orchestration.yml |
| critic | requirements + design + tasks | 妥当性検証 | レビューレポート |
| advisor | 問題の状況 | トレードオフ分析 | 推奨アプローチ + 根拠 |

### 実装系（WRITE 可）

| エージェント | Input | Processing | Output |
|-------------|-------|------------|--------|
| frontend | デザイン仕様 | UI実装 | コンポーネントファイル |
| code-simplifier | 対象コード | リファクタリング | 簡素化されたコード |
| debugger | バグの症状 | 根本原因調査 → 修正 | デバッグレポート + 修正コード |

### 品質系

| エージェント | Input | Processing | Output |
|-------------|-------|------------|--------|
| code-reviewer | diff、変更コード | 品質チェック | 問題レポート（Confidence付き） |
| security-reviewer | diff、変更コード | OWASP Top 10 チェック | 脆弱性レポート |
| document-writer | コード、仕様 | ドキュメント生成 | 技術文書 |

> **並列実行推奨**: `code-reviewer` + `security-reviewer` は同時チェック。

---

## フロー別のエージェント構成

### 計画フロー（/o-m-cc:plan）

```
learnings-researcher → analyst → scout → designer → planner → [critic]
```

### レビューフロー（/o-m-cc:review）

```
code-reviewer ─┐
               ├→ 統合レポート
security-reviewer ┘
```

### デバッグフロー

```
debugger → [advisor（3回失敗時）] → code-reviewer
```

### 学習フロー

```
/o-m-cc:learn → learnings-researcher（次回plan時に自動検索） → /o-m-cc:promote
```

---

## 詳細ファイル

各エージェントの詳細な振る舞いは個別ファイルを参照:
- `agents/{agent-name}.md`
