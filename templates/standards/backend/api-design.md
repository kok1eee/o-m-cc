# Backend API Design Standards

バックエンドAPI設計の規約を定義します。

## RESTful API

### エンドポイント命名

| 操作 | メソッド | パス | 例 |
|------|---------|------|-----|
| 一覧取得 | GET | /resources | GET /users |
| 詳細取得 | GET | /resources/:id | GET /users/123 |
| 作成 | POST | /resources | POST /users |
| 更新 | PUT/PATCH | /resources/:id | PUT /users/123 |
| 削除 | DELETE | /resources/:id | DELETE /users/123 |

### レスポンス形式

```json
{
  "data": { ... },
  "meta": {
    "page": 1,
    "total": 100
  }
}
```

### エラーレスポンス

```json
{
  "error": {
    "code": "VALIDATION_ERROR",
    "message": "入力値が不正です",
    "details": [...]
  }
}
```

## ステータスコード

| コード | 用途 |
|-------|------|
| 200 | 成功 |
| 201 | 作成成功 |
| 400 | バリデーションエラー |
| 401 | 認証エラー |
| 403 | 権限エラー |
| 404 | リソース未発見 |
| 500 | サーバーエラー |

## 認証・認可

- JWT / セッションベース
- APIキーは環境変数で管理
- CORS設定を適切に
