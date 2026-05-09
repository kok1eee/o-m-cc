# Council Output Schema - 共通ポリシー

**Review Council / Discovery Council の reviewer / analyst が返す findings の共通 JSON schema。**

集約側（quality-gate Step 4 / discovery-council Step 3）が JSON でパースして、降格マトリクス（`facets/policies/confidence-scoring.md`）を機械的に適用する。reviewer ごとに出力形式がブレると集約曖昧性が生じるため、**全 reviewer は本 schema に従う**。

## Schema（v1）

各 reviewer は次の JSON オブジェクトを 1 つ返す:

```json
{
  "reviewer": "security-reviewer",
  "schema_version": "1",
  "summary": "1-2 文の総評",
  "findings": [
    {
      "id": "F001",
      "category": "security",
      "file": "src/api/users.ts",
      "line_range": "42-55",
      "issue": "問題の要約（1 文）",
      "fix": "具体的な修正案",
      "confidence": 85,
      "severity": "high",
      "quotes": ["evidence quote from the code or document"]
    }
  ],
  "good_points": ["良い実装の指摘（任意）"],
  "memo": "free-form notes（任意、降格対象外）"
}
```

### フィールド定義

| フィールド | 型 | 必須 | 説明 |
|---|---|---|---|
| `reviewer` | string | ✅ | reviewer の identifier（`security-reviewer` / `critic` / `analyst` / `scout` / `researcher` / `anti-ai-slop` / `fact-checker` / `narrative-critic` / `reader-advocate`） |
| `schema_version` | string | ✅ | 本 schema のバージョン。現行は `"1"` |
| `summary` | string | ✅ | 1-2 文の総評。集約サマリで使う |
| `findings` | array | ✅ | 検出 issue の配列。0 件の場合は `[]` |
| `findings[].id` | string | ✅ | reviewer ローカルでユニーク（例: `F001`） |
| `findings[].category` | string | ✅ | 観点（`code-quality` / `security` / `plan-alignment` / `requirements-gap` / `narrative` / `reader-fit` / `ai-slop` / `fact` 等） |
| `findings[].file` | string | △ | 対象ファイル（コードレビュー系で必須、それ以外は任意） |
| `findings[].line_range` | string | △ | 行範囲（例: `"42"` / `"42-55"`）。コードレビュー系で必須 |
| `findings[].issue` | string | ✅ | 問題の要約（1 文） |
| `findings[].fix` | string | ✅ | 具体的な修正案（建設的に） |
| `findings[].confidence` | int 0-100 | ✅ | 確信度。詳細は `facets/policies/confidence-scoring.md` |
| `findings[].severity` | enum | ✅ | `critical` / `high` / `medium` / `low`（impact ベース） |
| `findings[].quotes` | array of string | △ | 判断根拠の引用。長文 input を Read する reviewer（critic / fact-checker 等）は **必ず**付ける（quote-first） |
| `good_points` | array of string |  | 良い点の指摘（任意、降格対象外） |
| `memo` | string |  | 集約側に伝えたい補足（任意、降格対象外） |

## Coverage-first（再掲）

**reviewer 側で findings をフィルタリングしない。** 検出した issue は全件 confidence + severity 付与で返す。閾値カット・ランキング・降格は集約側のみが行う（`facets/policies/confidence-scoring.md` 参照）。

## 集約側の処理（reference）

```python
# 擬似コード
for finding in findings:
    c = finding["confidence"]
    s = finding["severity"]
    if c >= 90 and s in ("critical", "high"):
        bucket = "critical"
    elif 80 <= c <= 89 and s in ("high", "medium"):
        bucket = "warning"
    elif 60 <= c <= 79 and s in ("medium", "low"):
        bucket = "note"
    else:
        bucket = "archive"
```

降格表は `facets/policies/confidence-scoring.md` の「集約側の降格ルール」マトリクスに従う。

## 出力配置

reviewer は SendMessage でこの JSON 文字列を返すか、`.editorial/round-N/<reviewer>.json` 等の指定パスに書き出す。前置き・後書き・コードフェンス記号は付けない（純粋な JSON）。

## バージョニング

schema を破壊変更する場合は `schema_version` を `"2"` に上げ、集約側も両 version を扱えるようにしてから移行する。後方互換 fields（`good_points` / `memo` 追加など）は version を上げない。

## 参照

このポリシーは以下から参照される:

- `agents/security-reviewer.md` / `critic.md` / `analyst.md` / `scout.md` / `researcher.md`
- `skills/quality-gate/SKILL.md` / `skills/quality-gate/reference.md`
- `skills/discovery-council/SKILL.md` / `skills/discovery-council/reference.md`
- `skills/editorial-swarm/SKILL.md`（4 reviewer の出力もこの schema に準拠する）
