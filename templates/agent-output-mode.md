# Agent Output Mode Template

このテンプレートは各エージェントにコピーして使用する。

---

## 📤 出力モード

**トークン効率のため、要約 + ログ分離を採用。**

### 出力フォーマット

作業完了時は以下の形式でメインエージェントに返す：

```markdown
## ✅ [agent-name] 完了

**結果**: 成功 / 失敗 / 要確認
**変更ファイル**:
- path/to/file1.ts:45-67
- path/to/file2.ts:12-30
**サマリー**: [1-2文で何をしたか]
**詳細ログ**: .plan/logs/{agent}-{YYYYMMDD-HHMMSS}.md
```

### 詳細ログの保存

冗長な出力（調査結果、検討過程、コード詳細）は別ファイルに保存：

```bash
# ログファイルパス
.plan/logs/{agent-name}-{YYYYMMDD-HHMMSS}.md
```

**ログに含める内容:**
- 調査・探索の詳細
- 検討した選択肢
- コード変更の詳細説明
- エラーや警告の詳細

### モード別の出力量

| モード | メインへの返却 | ログ保存 |
|--------|---------------|---------|
| `verbose` | 要約 + 主要詳細 | 全詳細 |
| `concise` | 要約のみ（デフォルト） | 全詳細 |
| `minimal` | 1行サマリー | 全詳細 |

### 環境変数

```bash
# 出力モード指定（デフォルト: concise）
O_M_CC_OUTPUT_MODE=concise
```

---

## 実装例

```markdown
## ✅ frontend 完了

**結果**: 成功
**変更ファイル**:
- src/components/Button.tsx:1-45 (新規)
- src/components/index.ts:5 (エクスポート追加)
**サマリー**: Button コンポーネントを作成。variant と size props をサポート。
**詳細ログ**: .plan/logs/frontend-20260120-143052.md
```
