---
name: capabilities
description: エージェント能力サマリーのリファレンスドキュメント。planner 等の他エージェントから Read で参照される。自動起動せず、選択材料としてのみ使用する。
---

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
  → Agent ツールで 2-3 teammates spawn（name + team_name 必須）
  → SendMessage で互いの発見を共有・議論（recipient = name）
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
  → Agent ツールで 5+ teammates spawn（name + team_name 必須）
  → TaskCreate で全タスク登録
  → teammates が自律的にクレーム・実行
  → SendMessage で peer-to-peer 調整（recipient = name）
  → TaskCompleted hook で完了通知
  → TeamDelete で解散
```

### 複数エージェントの相乗効果パターン

| パターン | 組み合わせ | 効果 |
|---------|-----------|------|
| **セキュリティ + 整合性** | security-reviewer + critic | セキュリティと計画整合性を同時にチェック |
| **仮説競合** | debugger × 2-3 | 異なる仮説を並列検証、偏りを排除 |
| **多角調査** | researcher + analyst + scout | コード・外部情報・要件を同時に調査 |
| **設計批評** | designer + critic | 設計しながらリアルタイムでレビュー |
| **コードレビュー (correctness bug)** | `Skill: code-review` (built-in) | bug を effort 別で検出・報告（`--comment` で GitHub PR コメント可）。findings は main agent が修正。v2.1.147 で cleanup 動作は削除（旧 simplify から名称・挙動とも変更） |

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
| **analyst** | 現状分析・要件整理 | 新機能の計画前、要件定義作成 | `/discovery-council` | 要件, 分析, 調査, requirements |
| **designer** | アーキテクチャ設計 | 要件定義完成後、実装の前 | `/design` | 設計, アーキテクチャ, design |
| **planner** | タスク分解 | 設計書完成後、実装に入る前 | `/task-decomposition` | 計画, タスク, 分解, plan, tasks |
| **scout** | ギャップ・スコープ分析 | 要件定義後、漏れや曖昧点の確認 | `/discovery-council` | 漏れ, 曖昧, スコープ, gaps |
| **critic** | 計画整合性チェック | 実装後、計画・設計との乖離確認 | `/quality-gate` / ユーザー直接 | 検証, 妥当性, リスク, validate, 整合性 |
| **debugger** | 体系的デバッグ | バグ・テスト失敗・予期しない動作、sisyphus の3エージェント方式 | ユーザー直接 / sisyphus | バグ, エラー, デバッグ, bug, error |
| **researcher** | コードベース探索・外部調査 | ファイル探索、構造把握、API仕様確認 | `/discovery-council` / ユーザー直接 | 探索, どこ, 構造, 調べて, 使い方, ベストプラクティス |
| **security-reviewer** | セキュリティチェック | 外部入力処理、認証実装の変更後 | `/quality-gate` | セキュリティ, 脆弱性, security |

> **コードレビュー (correctness bug 検出)** は Claude Code の built-in `Skill: code-review` に一任（effort level 指定可）。旧 `code-reviewer` agent は v0.58.0 で削除。v2.1.147 で built-in skill から cleanup-and-fix 動作が削除されたため、自動 cleanup 機能は失われた（findings は main agent が手動反映、format / style は lint で補完）。

---

## カテゴリ別

### 分析・調査系（READ のみ）

| エージェント | Input | Processing | Output | Memory 蓄積 |
|-------------|-------|------------|--------|------------|
| analyst | コードベース、ユーザー要求 | 構造分析、要件抽出 | requirements.md | 制約・前提条件、要件パターン |
| researcher | ファイルパターン、技術キーワード | Glob/Grep + Web検索 | 探索結果、調査レポート | 構造マップ、技術選定の根拠、API の注意点 |
| scout | requirements.md | スコープ確認、ギャップ分析 | IN/OUT SCOPE + 質問リスト | 曖昧性パターン、エッジケース、critic クロスリード |

### 設計・計画系（READ のみ）

| エージェント | Input | Processing | Output | Memory 蓄積 |
|-------------|-------|------------|--------|------------|
| designer | requirements.md | アーキテクチャ設計 | design.md | ADR の要約、設計パターン適用実績 |
| planner | design.md | タスク分解、依存関係整理 | TaskCreate（ネイティブタスク） | タスク粒度基準、依存関係パターン |
| critic | requirements + design + tasks | 妥当性検証 | レビューレポート | レビューの落とし穴、リスク評価精度、Calibration Loop |

### 実装・デバッグ系（WRITE 可）

| エージェント | Input | Processing | Output | Memory 蓄積 |
|-------------|-------|------------|--------|------------|
| debugger | バグの症状 / Verifier の報告 | 先入観なしの根本原因調査 → 修正 | デバッグレポート + 修正コード | バグパターン、修正の副作用 |

### 品質系

| エージェント | Input | Processing | Output | Memory 蓄積 |
|-------------|-------|------------|--------|------------|
| security-reviewer | diff、変更コード | OWASP Top 10 チェック | 脆弱性レポート | 脅威モデル、セキュリティ要件、Calibration Loop |

> **コードレビュー一般** (correctness bug 検出) は built-in `Skill: code-review` を使う（quality-gate skill が自動で呼び出し、findings は main agent が修正）。`security-reviewer` + `critic` は条件付き spawn（security 関連変更あり / requirements.md ありの時のみ）。

---

## フロー別のエージェント構成

### 計画フロー（/o-m-cc:sisyphus）

```
Phase 1: Discovery Council（同時 spawn + peer-to-peer）
  researcher ◄──► analyst ◄──► scout

Phase 2-3: Pipeline（順次実行）
  designer ──▶ planner
```

### レビューフロー（/o-m-cc:quality-gate）

```
1. Skill: code-review (built-in) — correctness bug 検出 → main agent が finding を修正（cleanup-and-fix は v2.1.147 で削除）
2. lint + ty (静的解析、Monitor で並列)
3. 条件付き Council:
     security 関連変更あり → security-reviewer
     plan/requirements.md あり → critic + 範囲整合性検証
     両方なし → スキップ
```

### ユーザー直接呼び出し

```
researcher — コードベース探索 + 外部ドキュメント調査
debugger   — バグの根本原因調査 → 修正
```

---

## 詳細ファイル

各エージェントの詳細な振る舞いは個別ファイルを参照:
- `agents/{agent-name}.md`
