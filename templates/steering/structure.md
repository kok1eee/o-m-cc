# Project Structure

プロジェクトのディレクトリ構造と各フォルダの役割を定義します。

## ディレクトリ構造

```
project-root/
├── src/                    # ソースコード
│   ├── components/         # UIコンポーネント
│   ├── pages/              # ページコンポーネント
│   ├── services/           # ビジネスロジック
│   ├── utils/              # ユーティリティ関数
│   └── types/              # 型定義
├── tests/                  # テストコード
│   ├── unit/               # ユニットテスト
│   ├── integration/        # 統合テスト
│   └── e2e/                # E2Eテスト
├── docs/                   # ドキュメント
├── scripts/                # ビルド・デプロイスクリプト
├── spec/                # Claude Code 設定
│   ├── standards/          # 技術規約
│   └── steering/           # プロジェクト文脈
└── config/                 # 設定ファイル
```

## 主要ファイル

| ファイル | 説明 |
|---------|------|
| `src/index.ts` | エントリーポイント |
| `package.json` | 依存関係管理 |
| `.env.example` | 環境変数テンプレート |

## 命名規則

| 対象 | 規則 | 例 |
|------|------|-----|
| コンポーネント | PascalCase | `UserProfile.tsx` |
| ユーティリティ | camelCase | `formatDate.ts` |
| テスト | `*.test.ts` | `user.test.ts` |
| 型定義 | `*.types.ts` | `user.types.ts` |

## モジュール境界

- `components/` は `services/` を直接呼ばない
- `services/` は `components/` を知らない
- 依存は常に上から下へ（逆依存禁止）

## 新規ファイル追加時

1. 適切なディレクトリに配置
2. 対応するテストファイルを作成
3. 必要に応じて index.ts でエクスポート
