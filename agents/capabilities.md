# Agent Capabilities

エージェント能力のサマリー。planner によるエージェント選択、および小タスクでのキーワードマッチに使用。

## エージェントの原則

エージェントは**コンテキストファイアウォール**。大量の情報を処理し、要約だけをメインスレッドに返す。

### やるべきこと
- **単一目的** — 1つのエージェントに1つの仕事
- **コンテキスト削減** — 処理した情報の10-20%だけ返す
- **Input → Processing → Output** を明確に定義
- **peer-to-peer 連携** — 関連する teammate 同士でメッセージ交換

### やってはいけないこと
- ❌ 大量の生出力を返す（要約して返す）

---

## ディスパッチ戦略

タスク規模に応じて実行方式を自動選択する。**判断に迷ったら Agent Teams を選ぶ。**

### 判断フロー

```
タスクを受け取る
  │
  ├─ Glob/Grep 1回で答えが出る？ ──── YES ──→ 【S】直接実行
  │
  ├─ 判断・分析が必要？ ──────────── YES ──→ 【M】Agent Teams (2-3 teammates)
  │
  └─ 複数工程・並列作業？ ─────────── YES ──→ 【L】Agent Teams (5+ teammates)
```

### 規模別ガイド

| 規模 | 判断基準 | 方式 | 例 |
|------|---------|------|-----|
| **S** | ファイル特定、grep 1回、単純な事実確認 | 直接実行 | 「このクラスどこにある？」 |
| **M** | 調査+判断、レビュー、デバッグ、設計相談 | Agent Teams (2-3) | 「このバグの原因を調べて」「レビューして」 |
| **L** | 複数フェーズ、並列実装、計画全体 | Agent Teams (5+) | 「認証機能を実装して」「並列で作って」 |

### 方式の詳細

**【S】直接実行** — エージェントを使わない
```
Glob/Grep/Read で直接回答
```

**【M】Agent Teams** — 議論で質を上げる
```
TeamCreate → team_name で作成
  → Agent ツールで 2-3 teammates spawn
  → SendMessage で互いの発見を共有・議論
  → 結果を統合
  → TeamDelete で解散
```

例: デバッグなら competing hypotheses パターン
```
debugger-1: 「認証トークンの期限切れが原因」
debugger-2: 「いや、CORS 設定の問題。トークンは正常」
→ 議論して真因を特定
```

**【L】Agent Teams + タスクリスト** — 大規模並列
```
TeamCreate → team_name で作成
  → Agent ツールで 5+ teammates spawn
  → TaskCreate で全タスク登録
  → teammates が自律的にクレーム・実行
  → SendMessage で peer-to-peer 調整
  → TeammateIdle/TaskCompleted hooks で自律制御
  → TeamDelete で解散
```

### 複数エージェントの相乗効果パターン

| パターン | 組み合わせ | 効果 |
|---------|-----------|------|
| **相互レビュー** | code-reviewer + security-reviewer | 品質とセキュリティを同時に、互いの発見を共有 |
| **仮説競合** | debugger × 2-3 | 異なる仮説を並列検証、偏りを排除 |
| **多角調査** | researcher + analyst + scout | コード・外部情報・要件を同時に調査 |
| **設計批評** | designer + critic | 設計しながらリアルタイムでレビュー |
| **実装+品質** | frontend + code-reviewer | 実装しながら逐次レビュー |

---

## 使用方法

### 小タスク（plan なし）
ユーザーリクエストのキーワードでマッチ → ディスパッチ戦略で規模判定 → 適切な方式で実行

### plan あり
得意分野・使用場面を参照 → タスクに適したエージェントを teammate として spawn

---

## エージェント一覧

| エージェント | 得意分野 | いつ使うか | 呼び出し方 | キーワード |
|-------------|---------|-----------|-----------|-----------|
| **analyst** | 現状分析・要件整理 | 新機能の計画前、要件定義作成 | `/sisyphus` Discovery Council | 要件, 分析, 調査, requirements |
| **designer** | アーキテクチャ設計 | 要件定義完成後、実装の前 | `/sisyphus` Phase 2 | 設計, アーキテクチャ, design |
| **planner** | タスク分解 | 設計書完成後、実装に入る前 | `/sisyphus` Phase 3 | 計画, タスク, 分解, plan, tasks |
| **scout** | ギャップ・スコープ分析 | 要件定義後、漏れや曖昧点の確認 | `/sisyphus` Discovery Council | 漏れ, 曖昧, スコープ, gaps |
| **critic** | 計画整合性チェック | 実装後、計画・設計との乖離確認 | `/review` / ユーザー直接 | 検証, 妥当性, リスク, validate, 整合性 |
| **debugger** | 体系的デバッグ | バグ・テスト失敗・予期しない動作 | ユーザー直接 | バグ, エラー, デバッグ, bug, error |
| **advisor** | 戦略判断・思考フレームワーク | 行き詰まり、3回修正しても未解決 | ユーザー直接 | 相談, 困った, 行き詰まり, stuck |
| **researcher** | コードベース探索・外部調査 | ファイル探索、構造把握、API仕様確認 | `/sisyphus` Discovery Council / ユーザー直接 | 探索, どこ, 構造, 調べて, 使い方, ベストプラクティス |
| **frontend** | UI実装 | React/Vue コンポーネント作成 | ユーザー直接 | UI, 画面, コンポーネント, screen |
| **code-reviewer** | コード品質チェック | タスク完了後、マージ前 | `/review` | レビュー, 品質, review, quality |
| **security-reviewer** | セキュリティチェック | 外部入力処理、認証実装の変更後 | `/review` | セキュリティ, 脆弱性, security |
| **vision** | 画像・PDF分析 | デザインモック、エラー画面解析 | ユーザー直接 | 画像, スクショ, PDF, screenshot |

---

## カテゴリ別

### 分析・調査系（READ のみ）

| エージェント | Input | Processing | Output | Memory 蓄積 |
|-------------|-------|------------|--------|------------|
| analyst | コードベース、ユーザー要求 | 構造分析、要件抽出 | requirements.md | 制約・前提条件、要件パターン |
| researcher | ファイルパターン、技術キーワード | Glob/Grep + Web検索 | 探索結果、調査レポート | 構造マップ、技術選定の根拠、API の注意点 |
| scout | requirements.md | スコープ確認、ギャップ分析 | IN/OUT SCOPE + 質問リスト | 曖昧性パターン、エッジケース、critic クロスリード |
| vision | 画像/PDFファイル | 視覚分析 | 抽出情報レポート | ビジュアル慣習、UI パターン |

### 設計・計画系（READ のみ）

| エージェント | Input | Processing | Output | Memory 蓄積 |
|-------------|-------|------------|--------|------------|
| designer | requirements.md | アーキテクチャ設計 | design.md | ADR の要約、設計パターン適用実績、code-reviewer/advisor クロスリード |
| planner | design.md | タスク分解、依存関係整理 | TaskCreate（ネイティブタスク） | タスク粒度基準、依存関係パターン、debugger/code-reviewer クロスリード |
| critic | requirements + design + tasks | 妥当性検証 | レビューレポート | レビューの落とし穴、リスク評価精度、Calibration Loop |
| advisor | 問題の状況 | トレードオフ分析 | 推奨アプローチ + 根拠 | 意思決定の先例、解消パターン |

### 実装系（WRITE 可）

| エージェント | Input | Processing | Output | Memory 蓄積 |
|-------------|-------|------------|--------|------------|
| frontend | デザイン仕様 | UI実装 | コンポーネントファイル | デザイン言語、コンポーネント規則 |
| debugger | バグの症状 | 根本原因調査 → 修正 | デバッグレポート + 修正コード | バグパターン、修正の副作用 |

### 品質系

| エージェント | Input | Processing | Output | Memory 蓄積 |
|-------------|-------|------------|--------|------------|
| code-reviewer | diff、変更コード | 品質チェック | 問題レポート（Confidence付き） | 頻出指摘パターン、OK/NG 基準、Calibration Loop、security-reviewer クロスリード |
| security-reviewer | diff、変更コード | OWASP Top 10 チェック | 脆弱性レポート | 脅威モデル、セキュリティ要件、Calibration Loop、code-reviewer クロスリード |

> **並列 spawn 推奨**: `code-reviewer` + `security-reviewer` + `critic` は同時 spawn でチェック。

---

## フロー別のエージェント構成

### 計画フロー（/o-m-cc:sisyphus）

```
Phase 1: Discovery Council（同時 spawn + peer-to-peer）
  researcher ◄──► analyst ◄──► scout

Phase 2-3: Pipeline（順次実行）
  designer ──▶ planner
```

### レビューフロー（/o-m-cc:review）

```
Review Council（同時 spawn + peer-to-peer）
  code-reviewer ◄──► security-reviewer ◄──► critic
```

### ユーザー直接呼び出し

```
researcher — コードベース探索 + 外部ドキュメント調査
debugger   — バグの根本原因調査 → 修正
frontend   — UI コンポーネント実装
vision     — 画像/PDF 分析
advisor    — 行き詰まり時の戦略相談
```

---

## 詳細ファイル

各エージェントの詳細な振る舞いは個別ファイルを参照:
- `agents/{agent-name}.md`
