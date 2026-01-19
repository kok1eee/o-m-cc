#!/bin/bash
# o-m-cc: Setup CLAUDE.md with Sisyphus Mode section
# Usage: ./setup-claude-md.sh [path/to/CLAUDE.md]

set -euo pipefail

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Target file (default: CLAUDE.md in current directory)
TARGET_FILE="${1:-CLAUDE.md}"

# Markers
START_MARKER="<!-- o-m-cc:sisyphus:start -->"
END_MARKER="<!-- o-m-cc:sisyphus:end -->"

# Sisyphus section content
SISYPHUS_CONTENT="$START_MARKER
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

\`\`\`
<promise>DONE</promise>
\`\`\`

### 禁止事項

- 途中放棄禁止 - TODOが残っている状態で「完了」と言わない
- 嘘の完了禁止 - \`<promise>DONE</promise>\` は本当に完了した時だけ
- レビュースキップ禁止 - 完了前に必ずレビュー

### Bash 使用制限

以下のコマンドは **禁止**（専用ツールを使用）:

| 禁止コマンド | 代替ツール |
|-------------|-----------|
| \`find\` | Glob ツール |
| \`grep\` / \`rg\` | Grep ツール |
| \`cat\` / \`head\` / \`tail\` | Read ツール |
| \`ls \| grep\` | Glob ツール |

**許可される Bash**:
- \`jj\` / \`git\` - バージョン管理
- \`npm\` / \`uv\` / \`pip\` - パッケージ管理
- ビルド/テストコマンド
$END_MARKER"

echo -e "${GREEN}=== o-m-cc CLAUDE.md Setup ===${NC}"

# Check if file exists
if [[ -f "$TARGET_FILE" ]]; then
  echo -e "${BLUE}Found existing $TARGET_FILE${NC}"

  # Check if markers exist
  if grep -q "$START_MARKER" "$TARGET_FILE" && grep -q "$END_MARKER" "$TARGET_FILE"; then
    echo -e "${YELLOW}Updating existing Sisyphus section...${NC}"

    # Create temp file
    TEMP_FILE=$(mktemp)

    # Remove old section and add new one
    awk -v start="$START_MARKER" -v end="$END_MARKER" -v content="$SISYPHUS_CONTENT" '
      BEGIN { printing = 1; added = 0 }
      $0 ~ start { printing = 0; if (!added) { print content; added = 1 } next }
      $0 ~ end { printing = 1; next }
      printing { print }
    ' "$TARGET_FILE" > "$TEMP_FILE"

    mv "$TEMP_FILE" "$TARGET_FILE"
    echo -e "${GREEN}✅ Sisyphus section updated${NC}"
  else
    echo -e "${YELLOW}Adding Sisyphus section...${NC}"
    echo "" >> "$TARGET_FILE"
    echo "$SISYPHUS_CONTENT" >> "$TARGET_FILE"
    echo -e "${GREEN}✅ Sisyphus section added${NC}"
  fi
else
  echo -e "${YELLOW}Creating new $TARGET_FILE...${NC}"
  echo "# Project Guidelines" > "$TARGET_FILE"
  echo "" >> "$TARGET_FILE"
  echo "$SISYPHUS_CONTENT" >> "$TARGET_FILE"
  echo -e "${GREEN}✅ $TARGET_FILE created with Sisyphus section${NC}"
fi

echo -e "${GREEN}=== Setup complete ===${NC}"
