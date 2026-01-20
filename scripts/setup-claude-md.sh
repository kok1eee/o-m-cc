#!/bin/bash
# o-m-cc: Setup CLAUDE.md with Sisyphus Mode section
# Usage: ./setup-claude-md.sh [path/to/CLAUDE.md]

set -euo pipefail

TARGET_FILE="${1:-CLAUDE.md}"
START_MARKER="<!-- o-m-cc:sisyphus:start -->"
END_MARKER="<!-- o-m-cc:sisyphus:end -->"

# Create Sisyphus content in a temp file
CONTENT_FILE=$(mktemp)
cat > "$CONTENT_FILE" << 'SISYPHUS_EOF'
<!-- o-m-cc:sisyphus:start -->
## Sisyphus Mode

**タスク完了まで決して止まらない。**

### 原則

1. **TODO First** - 作業開始時に TodoWrite でタスクリストを作成
2. **One at a Time** - 同時に in_progress は1つだけ
3. **Complete Honestly** - 本当に完了したタスクのみ completed に
4. **Never Abandon** - 途中で止まらない
5. **Review Before Done** - 完了前に code-reviewer subagent でレビュー

### 完了条件

全てのTODOが完了し、レビューで Critical がない場合のみ：

```
<promise>DONE</promise>
```

### 禁止事項

- 途中放棄禁止 - TODOが残っている状態で「完了」と言わない
- 嘘の完了禁止 - `<promise>DONE</promise>` は本当に完了した時だけ
- レビュースキップ禁止 - 完了前に必ずレビュー

### Bash 使用制限

以下のコマンドは **禁止**（専用ツールを使用）:

| 禁止コマンド | 代替ツール |
|-------------|-----------|
| `find` | Glob ツール |
| `grep` / `rg` | Grep ツール |
| `cat` / `head` / `tail` | Read ツール |
| `ls | grep` | Glob ツール |

**許可される Bash**:
- `jj` / `git` - バージョン管理
- `npm` / `uv` / `pip` - パッケージ管理
- ビルド/テストコマンド

### コード品質基準

実装時は以下の基準を守る：

| 項目 | 基準 | 理由 |
|------|------|------|
| ファイルサイズ | 200-400行推奨、800行上限 | 可読性と保守性 |
| 関数サイズ | 50行以下 | 単一責任の原則 |
| ネスト深度 | 4段以下 | 複雑性の制御 |
| 引数の数 | 3個以下（多い場合はオブジェクト化） | 理解しやすさ |

**イミュータビリティ優先**:
- 既存オブジェクトを変更しない
- 常に新しいオブジェクトを作成して返す
- 副作用を最小限に

**命名規則**:
- 変数名は意図を表す（`d` → `currentDate`）
- 関数名は動詞で始める（`getUser`, `validateInput`）
- 略語を避ける（`btn` → `button`）
<!-- o-m-cc:sisyphus:end -->
SISYPHUS_EOF

echo "=== o-m-cc CLAUDE.md Setup ==="

if [[ -f "$TARGET_FILE" ]]; then
  echo "Found existing $TARGET_FILE"

  if grep -q "$START_MARKER" "$TARGET_FILE" && grep -q "$END_MARKER" "$TARGET_FILE"; then
    echo "Updating existing Sisyphus section..."

    # Create output file
    TEMP_FILE=$(mktemp)

    # Process: keep content before marker, add new content, keep content after marker
    awk -v start="$START_MARKER" -v end="$END_MARKER" '
      $0 ~ start { skip = 1; next }
      $0 ~ end { skip = 0; next }
      !skip { print }
    ' "$TARGET_FILE" > "$TEMP_FILE"

    # Find where to insert (before the line that was after end marker, or at end)
    # For simplicity, append at end and user can move if needed
    cat "$CONTENT_FILE" >> "$TEMP_FILE"

    mv "$TEMP_FILE" "$TARGET_FILE"
    echo "✅ Sisyphus section updated"
  else
    echo "Adding Sisyphus section..."
    echo "" >> "$TARGET_FILE"
    cat "$CONTENT_FILE" >> "$TARGET_FILE"
    echo "✅ Sisyphus section added"
  fi
else
  echo "Creating new $TARGET_FILE..."
  echo "# Project Guidelines" > "$TARGET_FILE"
  echo "" >> "$TARGET_FILE"
  cat "$CONTENT_FILE" >> "$TARGET_FILE"
  echo "✅ $TARGET_FILE created with Sisyphus section"
fi

rm -f "$CONTENT_FILE"
echo "=== Setup complete ==="
