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
| **S** | ファイル特定、grep 1回、単純な事実確認 | Lead が直接実行 | 「このクラスどこにある？」 |
| **M** | 調査+判断、レビュー、デバッグ、設計相談 | Agent Teams (2-3) | 「このバグの原因を調べて」「レビューして」 |
| **L** | 複数フェーズ、並列実装、計画全体 | Agent Teams (5+) | 「認証機能を実装して」「並列で作って」 |

### 方式の詳細

**【S】直接実行** — エージェントを使わない
```
Lead が Glob/Grep/Read で直接回答
```

**【M】Agent Teams** — 議論で質を上げる
```
TeammateTool: spawnTeam
  → 2-3 teammates spawn
  → 互いの発見を共有・議論
  → Lead が統合
```

例: デバッグなら competing hypotheses パターン
```
debugger-1: 「認証トークンの期限切れが原因」
debugger-2: 「いや、CORS 設定の問題。トークンは正常」
→ 議論して真因を特定
```

**【L】Agent Teams + タスクリスト** — 大規模並列
```
TeammateTool: spawnTeam
  → 5+ teammates spawn
  → TaskCreate で全タスク登録
  → teammates が自律的にクレーム・実行
  → TeammateIdle/TaskCompleted hooks で調整
```

### 複数エージェントの相乗効果パターン

| パターン | 組み合わせ | 効果 |
|---------|-----------|------|
| **相互レビュー** | code-reviewer + security-reviewer | 品質とセキュリティを同時に、互いの発見を共有 |
| **仮説競合** | debugger × 2-3 | 異なる仮説を並列検証、偏りを排除 |
| **多角調査** | explore + researcher + analyst | コード・外部情報・要件を同時に調査 |
| **設計批評** | designer + critic | 設計しながらリアルタイムでレビュー |
| **実装+品質** | frontend + code-reviewer | 実装しながら逐次レビュー |

---

## 使用方法

### 小タスク（plan なし）
ユーザーリクエストのキーワードでマッチ → ディスパッチ戦略で規模判定 → 適切な方式で実行

### plan あり
得意分野・使用場面を参照 → orchestration.yml にエージェントを設定 → teammate として spawn

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
| **learnings-researcher** | 過去の学び検索（claude-mem セマンティック + HANDOVER.md 履歴） | 実装前の知識確認、類似バグ調査 | 前回, 学び, 同じミス, 教訓 |
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
| learnings-researcher | タスク説明 | claude-mem セマンティック検索 + HANDOVER.md VCS 履歴フォールバック | 関連する過去の知見 |
| vision | 画像/PDFファイル | 視覚分析 | 抽出情報レポート |

### 設計・計画系（READ のみ）

| エージェント | Input | Processing | Output |
|-------------|-------|------------|--------|
| designer | requirements.md | アーキテクチャ設計 | design.md |
| planner | design.md | タスク分解、依存関係整理 | tasks.md + orchestration.yml |
| critic | requirements + design + tasks | 妥当性検証 | レビューレポート |
| advisor | 問題の状況 | トレードオフ分析（claude-mem で過去の類似判断を参照） | 推奨アプローチ + 根拠 |

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

> **並列 spawn 推奨**: `code-reviewer` + `security-reviewer` は同時 spawn でチェック。

---

## フロー別のエージェント構成

### 計画フロー（/o-m-cc:plan）

```
Agent Teams:
  ┌─ learnings-researcher ─┐
  │        (並列)          │──▶ scout ──▶ designer ──▶ planner ──▶ [critic]
  └─ analyst ──────────────┘
```

### レビューフロー（/o-m-cc:review）

```
Agent Teams:
  code-reviewer ────┐
      (peer-to-peer) ├──▶ Lead が統合レポート
  security-reviewer ┘
```

### デバッグフロー

```
debugger → [advisor（3回失敗時）] → code-reviewer
```

### 学習フロー

```
操作 ──── claude-mem（自動記録） ───┐
                                    ├─▶ learnings-researcher（セマンティック + HANDOVER.md 履歴検索）
/o-m-cc:handover ── HANDOVER.md ────┘         │
                                              ▼
                                        /o-m-cc:promote（スキル昇格）
```

---

## 詳細ファイル

各エージェントの詳細な振る舞いは個別ファイルを参照:
- `agents/{agent-name}.md`
