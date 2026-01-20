# Agent Capabilities

エージェント能力のサマリー。planner によるエージェント選択、および小タスクでのキーワードマッチに使用。

## 使用方法

### 小タスク（plan なし）
ユーザーリクエストのキーワードでマッチ → 該当エージェントを直接呼び出し

### plan あり
得意分野・使用場面を参照 → orchestration.yml にエージェントを設定

---

## エージェント一覧

| エージェント | 得意分野 | 使用場面 | キーワード |
|-------------|---------|---------|-----------|
| **explore** | 高速検索・構造把握 | コードベース調査、ファイル探索 | 探索, 検索, どこ, 構造, find, search, where |
| **analyst** | 現状分析・要件整理 | 要件定義、技術スタック調査 | 要件, 分析, 調査, 整理, requirements, analyze |
| **designer** | アーキテクチャ設計 | 設計書作成、API設計 | 設計, アーキテクチャ, design, architecture |
| **planner** | タスク分解 | 実装計画、依存関係整理 | 計画, タスク, 分解, plan, tasks |
| **frontend** | UI実装 | React/Vue コンポーネント作成 | UI, 画面, コンポーネント, フロント, component, screen |
| **code-reviewer** | コード品質チェック | バグ・複雑性・保守性レビュー | レビュー, 品質, チェック, review, quality |
| **security-reviewer** | セキュリティチェック | OWASP Top 10、脆弱性検出 | セキュリティ, 脆弱性, security, vulnerability |
| **code-simplifier** | リファクタリング | コード簡素化、保守性向上 | 簡素化, リファクタ, シンプル, simplify, refactor |
| **researcher** | 外部調査（深度対応） | ドキュメント調査、ベストプラクティス | 調べて, 使い方, 実装例, 詳しく, 比較, research |
| **advisor** | 戦略判断 | 行き詰まり解消、技術的意思決定 | 相談, アドバイス, 困った, advice, stuck |
| **scout** | ギャップ分析 | 計画前の曖昧点発見 | 漏れ, 曖昧, 不明点, gaps, unclear |
| **critic** | 計画検証 | スコープ・リスク・実現可能性チェック | 検証, 妥当性, リスク, validate, risk |
| **document-writer** | ドキュメント作成 | 技術文書、API仕様、ガイド | ドキュメント, 文書, 仕様書, docs, documentation |
| **vision** | 画像・PDF分析 | デザインモック、エラー画面解析 | 画像, スクショ, PDF, image, screenshot |

---

## カテゴリ別

### 分析・調査系（READ のみ）
- explore, analyst, researcher, scout, vision

### 設計・計画系（READ のみ）
- designer, planner, critic, advisor

### 実装系（WRITE 可）
- frontend, code-simplifier

### 品質系
- code-reviewer, security-reviewer, document-writer

> **Note**: `code-reviewer` と `security-reviewer` は**並列実行推奨**。品質とセキュリティを同時チェック。

---

## 詳細ファイル

各エージェントの詳細な振る舞いは個別ファイルを参照:
- `agents/{agent-name}.md`
