# Learned Standards

プロジェクト固有の発見事項・パターン・規約を累積記録するディレクトリ。

## 目的

- **静的な Standards** = 事前に定義した規約（`global/`, `frontend/`, etc.）
- **Learned Standards** = プロジェクトで発見したパターン（動的）

## 記録タイミング

- コードレビュー時に発見したパターン
- 実装中に気づいた暗黙の規約
- バグ修正時に学んだアンチパターン

## ファイル構成

```
learned/
├── README.md           # このファイル
├── patterns.md         # 発見したパターン
├── decisions.md        # 技術的決定の記録
└── antipatterns.md     # 避けるべきパターン
```

## 記録フォーマット

### patterns.md

```markdown
## [YYYY-MM-DD] パターン名

**発見場所**: `src/services/UserService.ts`
**内容**: Service クラスは必ず interface を先に定義する
**理由**: テスト時のモック作成が容易になる
```

### decisions.md

```markdown
## [YYYY-MM-DD] 決定事項

**決定**: 認証は JWT ではなく session-based を採用
**理由**: 既存インフラとの互換性
**影響範囲**: AuthService, SessionMiddleware
**参考**: spec/plan/design.md#authentication
```

### antipatterns.md

```markdown
## [YYYY-MM-DD] アンチパターン

**パターン**: Repository で直接 console.log を使用
**問題**: 本番環境でログが混在する
**代替案**: Logger クラスを使用する
**発見場所**: `src/repositories/UserRepository.ts:45`
```

## エージェントによる自動記録

`code-reviewer` エージェントは、レビュー中に発見したパターンを自動的にこのディレクトリに記録します。
