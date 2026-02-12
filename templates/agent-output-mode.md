# Agent Output Mode Template

このテンプレートは各エージェントにコピーして使用する。

---

## 📤 出力モード

**トークン効率のため、要約形式を採用。**

### 出力フォーマット

作業完了時は以下の形式でメインエージェントに返す：

```markdown
## ✅ [agent-name] 完了

**結果**: 成功 / 失敗 / 要確認
**変更ファイル**:
- path/to/file1.ts:45-67
- path/to/file2.ts:12-30
**サマリー**: [1-2文で何をしたか]
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
```
