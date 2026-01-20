# Coding Style

このファイルはプロジェクトのコーディングスタイルを定義します。
エージェントは実装時にこのスタイルに従います。

## インデント

- スペース: 2（または 4）
- タブは使用しない

## 命名規則

| 対象 | スタイル | 例 |
|------|---------|-----|
| 変数 | camelCase | `userName` |
| 関数 | camelCase | `getUserName()` |
| クラス | PascalCase | `UserService` |
| 定数 | UPPER_SNAKE | `MAX_RETRY_COUNT` |
| ファイル | kebab-case | `user-service.ts` |

## コメント

- 「なぜ」を説明するコメントを書く
- 「何」はコード自体で表現する
- TODO は `TODO(author):` 形式

## その他

- 1行80-120文字以内
- 関数は50行以内を目安
- ネストは3レベルまで
