# Testing Standards

テスト戦略と規約を定義します。

## テストピラミッド

```
        /\
       /  \  E2E（少数）
      /────\
     /      \  Integration（中程度）
    /────────\
   /          \  Unit（多数）
  /────────────\
```

## ユニットテスト

- カバレッジ目標: 80%以上
- 1テスト1アサーション（理想）
- モックは最小限に

### 命名規則

```
describe('UserService', () => {
  describe('createUser', () => {
    it('should create a user with valid data', () => {});
    it('should throw error when email is invalid', () => {});
  });
});
```

## 統合テスト

- API エンドポイントのテスト
- データベース操作のテスト
- テスト用DBを使用（本番DBは使わない）

## E2Eテスト

- クリティカルパスのみ
- ログイン → 主要機能 → ログアウト
- CI/CDで自動実行

## テストデータ

- Factory パターンを使用
- シードデータは明確に管理
- テスト間の依存を避ける
