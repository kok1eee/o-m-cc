# Frontend Component Standards

フロントエンドコンポーネントの設計規約を定義します。

## コンポーネント設計

### ディレクトリ構造

```
components/
├── ui/           # 汎用UIコンポーネント（Button, Input, Modal）
├── features/     # 機能別コンポーネント
└── layouts/      # レイアウトコンポーネント
```

### ファイル構成

```
Button/
├── Button.tsx        # コンポーネント本体
├── Button.test.tsx   # テスト
├── Button.stories.tsx # Storybook（オプション）
└── index.ts          # エクスポート
```

## Props 設計

- 必須 props は明示的に型定義
- オプション props にはデフォルト値を設定
- children を受け取る場合は `React.ReactNode` を使用

## スタイリング

- Tailwind CSS / CSS Modules / styled-components など
- レスポンシブ: モバイルファースト
- カラーはテーマ変数を使用

## アクセシビリティ

- セマンティックなHTML要素を使用
- aria属性を適切に設定
- キーボードナビゲーション対応
